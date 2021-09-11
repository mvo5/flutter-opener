import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sjm.dart';

class OpenerApi {
    String host, hmac_key;
    int port;
    
    void init(host, port, hmac_key) {
	this.host = host;
	this.port = port;
	this.hmac_key = hmac_key;
    }
    
    Future<String> open() async {
	Socket socket;
	try {
	    socket = await Socket.connect(this.host, this.port);
	} catch(error) {
	    return "cannot connect: $error";
	}
	var lineReader = utf8.decoder.bind(socket).transform(LineSplitter());
	
	String helo, hmac, result, nonce;
	String returnStatus = "unset";
	try {
	    await for (String data in lineReader) {
		if (helo == null) {
		    helo = data;
		    var sjm =  SignedJsonMessage.fromString(helo, this.hmac_key, "");
		    if (sjm.payload["version"] != 1) {
			throw("incorrect protocol version");
		    }
		    nonce = sjm.nonce;
		    
		    Map<String, String> json_cmd = new Map<String, String>();
		    json_cmd["cmd"] = "open";
		    json_cmd["nonce"] = nonce;
		    var sjm2 = SignedJsonMessage(this.hmac_key, nonce);
		    sjm2.set_payload(json_cmd);
		    
		    await socket.write(sjm2.toString()+"\n");
		} else if (result == null) {
		    result = data;
		    var sjm = SignedJsonMessage.fromString(result, this.hmac_key, nonce);
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
    }
}
