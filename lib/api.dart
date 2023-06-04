import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:f_logs/f_logs.dart';

import 'sjm.dart';

class OpenerApi {
    late String host, hmacKey, deviceInfo;
    late int port;
    
    void init(host, port, hmacKey, deviceInfo) {
	this.host = host;
	this.port = port;
	this.hmacKey = hmacKey;
	this.deviceInfo = deviceInfo;
    }
    
    Future<String> open() async {
	FLog.debug(text: "open(${this.host})");
	Socket socket;
	try {
	    // XXX: there is a potential race in the esp32 opener code
	    // on errno=111 (connection refused) - it may mean that
	    // the esp32 is not listening on the socket just now but
	    // instead had a timeout and is feeding the watchdog. it
	    // should be hard to hit this race but maybe the code
	    // should auto-retry on 111?
	    socket = await Socket.connect(this.host, this.port);
	    FLog.debug(text: "socket connection established");
	} on SocketException catch(error) {
	    FLog.error(
		text: "socket exception for ${this.host}",
		exception: error);
	    // XXX: android specific
	    if (error.osError?.errorCode == 7) {
		return "cannot find ${this.host}: not fully connected yet?";
	    }
	    if (error.osError?.errorCode == 111) {
		return "cannot connect ${this.host}: $error (esp32 doing the watchdog race?)";
	    }
	    return "cannot connect (socket error) to ${this.host}: $error";
	} catch(error) {
	    FLog.error(
		text: "cannot connect to ${this.host}",
		exception: error);
	    return "cannot connect to ${this.host}: $error";
	}
	var lineReader = utf8.decoder.bind(socket)
	    .transform(LineSplitter())
	    .timeout(Duration(seconds: 20), onTimeout: (_) {
		FLog.error(text: "timeout (20s) in line reader, closing socket");
		print("timeout in line reader, closing socket");
		socket.close();
	    });
	
	String? helo, result;
        String nonce = "";
	String returnStatus = "unset";
	try {
	    await for (String data in lineReader) {
		FLog.debug(text: "reading line '$data'");
		if (helo == null) {
		    helo = data;
		    var sjm =  SignedJsonMessage.fromString(helo, this.hmacKey, "");
		    if (sjm.payload["version"] != 1) {
			FLog.error(text: "incorrect protocol version");
			FLog.error(text: "from $sjm");
			throw("incorrect protocol version");
		    }
		    nonce = sjm.nonce;

		    Map<String, String> jsonCmd = new Map<String, String>();
		    jsonCmd["cmd"] = "open";
		    jsonCmd["nonce"] = nonce;
		    jsonCmd["device-info"] = this.deviceInfo;
		    var sjm2 = SignedJsonMessage(this.hmacKey, nonce);
		    sjm2.setPayload(jsonCmd);

		    var sendLine = sjm2.toString()+"\n";
		    FLog.debug(text: "sending line '$sendLine'");
		    socket.write(sendLine);
		} else if (result == null) {
		    result = data;
		    SignedJsonMessage.fromString(result, this.hmacKey, nonce);
		    helo = result = nonce = "";
		    socket.destroy();
		}
		returnStatus = "Done";
	    }
	} catch(error) {
	    FLog.error(text: "error during line reader", exception: error);
	    returnStatus = "error: $error";
	}
	socket.close();
	socket.destroy();

	FLog.info(text: "done open(), returning $returnStatus");
	return returnStatus;
    }
}
