import 'dart:async';
import 'dart:convert';
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'package:qrscan/qrscan.dart' as scanner;
import 'package:permission_handler/permission_handler.dart';
// XXX: move to biometric storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:slider_button/slider_button.dart';

import 'sjm.dart';
import 'api.dart';

void main() {
    runApp(OpenerApp());
}

class OpenerApp extends StatelessWidget {
    // This widget is the root of your application.
    @override
    Widget build(BuildContext context) {
	return MaterialApp(
	    title: 'Opener',
	    home: OpenerHomePage(title: 'μ Opener'),
	);
    }
}

class OpenerHomePage extends StatefulWidget {
    OpenerHomePage({Key key, this.title}) : super(key: key);
    final String title;
    
    @override
    OpenerHomePageState createState() => OpenerHomePageState();
}

class OpenerHomePageState extends State<OpenerHomePage> {
    bool _openerCall = false;
    String _statusText = "Ready";

    // read from the security store
    // XXX: make it a list to support multiple doors
    var cfg = Map<String, dynamic>();

    // will be mocked in tests
    OpenerApi opener;
    FlutterSecureStorage storage;

    void initState() {
	this.storage = new FlutterSecureStorage();
	this.opener = new OpenerApi();
    }

    
    Future<String> callOpenerApi() async {
	// XXX: read early and show indication that a key is known
    	var json_cfg = await storage.read(key: "cfg");
	if (json_cfg == null) {
	    return "no configuration yet";
	};
	
	cfg = json.decode(json_cfg);
	var hmac_key = cfg["hmac-key"];
	var host = cfg["hostname"];
	final port = 8877;
	opener.init(host, port, hmac_key);
	
	// XXX: use exceptions?
	var returnStatus = opener.open();
	return returnStatus;
    }

    void doCallOpenerApi() async {
	setState(() {
	    _statusText = "Opening...";
	});

	var newStatusText = await callOpenerApi();
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
	    return SliderButton(
		label: Text("Slide to open"),
		icon: Icon(Icons.lock_open),
		// XXX: workaround for
		// https://github.com/anirudhsharma392/Slider-Button/issues/21
		boxShadow: BoxShadow(
		    color: Theme.of(context).primaryColor,
		    blurRadius: 2.0,
		    spreadRadius: 2.0,
		    offset: Offset.zero
		),
		action: () {
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
			Text(_statusText, key: Key("label_status")),
			Expanded(child: Container(),),
			Center(child: getOpenOrSpinnerWidget()),
			Expanded(child: Container(),),
		    ],
		),
	    ),
	);
    }
}
