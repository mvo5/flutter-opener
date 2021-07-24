import 'dart:async';
import 'dart:convert';
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'package:qrscan/qrscan.dart' as scanner;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
    runApp(OpenerApp());
}

class SignedJsonMessage {
    String key;
    String _nonce;
    Map<String, String> _header;
    Map<String, dynamic> _payload;

    SignedJsonMessage(this.key, this._nonce) {
	this._header =  {
            "ver": "1",
            "alg": "HS512",
	    "nonce": this._nonce,
	};
	this._payload = {};
    }

    String get nonce => _header["nonce"];
    Map<String, dynamic> get payload => _payload;
    
    void set_payload(Map<String, dynamic> payload) {
	this._payload = payload;
    }

    String toString() {
	String hp = base64.encode(utf8.encode(jsonEncode(this._header))) +
	    "." +
	    base64.encode(utf8.encode(jsonEncode(this._payload)));
	var hmac = new Hmac(sha512, utf8.encode(this.key));
	var digest = hmac.convert(utf8.encode(hp));
	return hp + "." + base64.encode(digest.bytes);
    }

    factory SignedJsonMessage.fromString(String s, String key, String expected_nonce) {
	// equivalent to s.rsplit(".", 1)
	int idx = s.lastIndexOf(".");
	var encoded_header_payload = s.substring(0,idx).trim();
	var encoded_signature = s.substring(idx+1).trim();
	var recv_sig = base64.decode(encoded_signature);
	var hmac = new Hmac(sha512, utf8.encode(key));
	var calculated_sig = hmac.convert(utf8.encode(encoded_header_payload));
	if (calculated_sig.bytes.toString() != recv_sig.toString()) {
	    throw("incorrect signature");
	}
	idx = encoded_header_payload.indexOf(".");
	var encoded_header = encoded_header_payload.substring(0, idx).trim();
	var encoded_payload = encoded_header_payload.substring(idx+1).trim();
	var header = jsonDecode(utf8.decode(base64.decode(encoded_header)));
	var payload = jsonDecode(utf8.decode(base64.decode(encoded_payload)));
	if (expected_nonce != "") {
	    if (header["nonce"] != expected_nonce) {
		throw("incorrect nonce");
	    }
	}
	var nonce = header["nonce"];
	var sjm = SignedJsonMessage(key, nonce);
	sjm.set_payload(payload);
	return sjm;
    }
}


class OpenerApp extends StatelessWidget {
    // This widget is the root of your application.
    @override
    Widget build(BuildContext context) {
	return MaterialApp(
	    title: 'Opener',
	    // XXX: do I need this
	    theme: ThemeData(
		primarySwatch: Colors.blue,
		visualDensity: VisualDensity.adaptivePlatformDensity,
	    ),
	    home: OpenerHomePage(title: 'μ Opener'),
	);
    }
}

class OpenerHomePage extends StatefulWidget {
    OpenerHomePage({Key key, this.title}) : super(key: key);
    final String title;
    
    @override
    _OpenerHomePageState createState() => _OpenerHomePageState();
}

class _OpenerHomePageState extends State<OpenerHomePage> {
    bool _openerCall = false;
    String _statusText = "Ready";

    // read from the security store
    // XXX: make it a list to support multiple doors
    var cfg = Map<String, dynamic>();

    final storage = new FlutterSecureStorage();
    
    Future<String> callOpenerApi() async {
	// XXX: read early and show indication that a key is known
	var json_cfg = await storage.read(key: "cfg");
	if (json_cfg == null) {
	    return "no configuration yet";
	};
	
	print("got from secure store: $json_cfg");
	cfg = json.decode(json_cfg);
	var hmac_key = cfg["hmac-key"];
	var host = cfg["hostname"];
	final port = 8877;

	Socket socket;
	try {
	    socket = await Socket.connect(host, port);
	} catch(error) {
	    return "cannot connect: $error";
	}
	print('Connected to: ${socket.remoteAddress.address}:${socket.remotePort}');
	var lineReader = utf8.decoder.bind(socket).transform(LineSplitter());

	String helo, hmac, result, nonce;
	String returnStatus = "unset";
	try {
	    await for (String data in lineReader) {
		print("got from stream: $data");
		if (helo == null) {
		    helo = data;
		    var sjm =  SignedJsonMessage.fromString(helo, hmac_key, "");
		    if (sjm.payload["version"] != 1) {
			throw("incorrect protocol version");
		    }
		    nonce = sjm.nonce;
		    print("got nonce $nonce");
		    
		    Map<String, String> json_cmd = new Map<String, String>();
		    json_cmd["cmd"] = "open";
		    json_cmd["nonce"] = nonce;
		    var sjm2 = SignedJsonMessage(hmac_key, nonce);
		    sjm2.set_payload(json_cmd);
		    
		    await socket.write(sjm2.toString()+"\n");
		    print("after sent");
		} else if (result == null) {
		    print("result");
		    result = data;
		    print("result $result");
		    var sjm = SignedJsonMessage.fromString(result, hmac_key, nonce);
		    helo = hmac = result = nonce = "";
		    socket.destroy();
		}
		returnStatus = "Done";
	    }
	} catch(error) {
	    returnStatus = "error: $error";
	}
	socket.close();
	socket.destroy();
	
	return returnStatus;
    }

    void doCallOpenerApi() async {
	var newStatusText = await callOpenerApi();
	print("new status text: $newStatusText");
	setState(() {
	    _openerCall = false;
	    _statusText = newStatusText;
	});
    }

    Widget getOpenOrSpinnerWidget(){
	if(_openerCall) {
	    return new Container(
		child: CircularProgressIndicator(),
		padding: EdgeInsets.all(64),
	    );
	} else {
	    return ElevatedButton.icon(
		label: Text("Open"),
		icon: Icon(Icons.lock_open),
		style: ElevatedButton.styleFrom(
		    shape: CircleBorder(),
		    padding: EdgeInsets.all(64),
		),
		onPressed: () {
		    setState(() {
			_openerCall = true;
		    });
		    doCallOpenerApi();
		});
	};
    }

    Future scanSecret() async {
	await Permission.camera.request();
	String cameraScanResult = await scanner.scan();
	if (cameraScanResult == null || cameraScanResult == "") {
	    return;
	}
	var json_cfg = cameraScanResult;
	print("scan result: $cameraScanResult");
	// XXX: do basic validation?
	await storage.write(key: "cfg", value: json_cfg);
    }

    void onSelectedClick(String value) {
	switch (value) {
	case 'Scan settings':
	    scanSecret();
	}
    }
    
    @override
    Widget build(BuildContext context) {
	return Scaffold(
	    appBar: AppBar(
		title: Text(widget.title),
		actions: <Widget>[
		    PopupMenuButton<String>(
			onSelected: onSelectedClick,
			itemBuilder: (BuildContext context) {
			    return {'Scan settings'}.map((String choice) {
				return PopupMenuItem<String>(
				    value: choice,
				    child: Text(choice),
				);
			    }).toList();
			}),
		]),
	    body: Center(
		child: Column(
		    crossAxisAlignment: CrossAxisAlignment.center,
		    children: <Widget>[
			Text(_statusText),
			Expanded(child: Container(),),
			Expanded(child: getOpenOrSpinnerWidget(),),
			Expanded(child: Container(),),
		    ],
		),
	    ),
	);
    }
}
