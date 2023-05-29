import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:f_logs/f_logs.dart';

import 'sjm.dart';

class OpenerApi {
    late String host, hmac_key, device_info;
    late int port;
    
    void init(host, port, hmac_key, device_info) {
	this.host = host;
	this.port = port;
	this.hmac_key = hmac_key;
	this.device_info = device_info;
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
	
	String? helo, result, nonce;
        String hmac;
	String returnStatus = "unset";
	try {
	    await for (String data in lineReader) {
		FLog.debug(text: "line $data read");
		if (helo == null) {
		    helo = data;
		    var sjm =  SignedJsonMessage.fromString(helo, this.hmac_key, "");
		    if (sjm.payload["version"] != 1) {
			FLog.error(text: "incorrect protocol version");
			FLog.error(text: "from $sjm");
			throw("incorrect protocol version");
		    }
		    nonce = sjm.nonce;

		    Map<String, String> json_cmd = new Map<String, String>();
		    json_cmd["cmd"] = "open";
                    if (nonce != null) {
		        json_cmd["nonce"] = nonce!;
                    }
		    json_cmd["device-info"] = this.device_info;
		    var sjm2 = SignedJsonMessage(this.hmac_key, nonce);
		    sjm2.set_payload(json_cmd);
		    
		    socket.write(sjm2.toString()+"\n");
		} else if (result == null) {
		    result = data;
		    var sjm = SignedJsonMessage.fromString(result, this.hmac_key, nonce);
		    helo = hmac = result = nonce = "";
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
