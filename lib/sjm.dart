import 'dart:convert';

import 'package:crypto/crypto.dart';


class SignedJsonMessage {
    String key;
    String _nonce;
    late Map<String, String> _header;
    late Map<String, dynamic> _payload;

    SignedJsonMessage(this.key, this._nonce) {
	this._header =  {
            "ver": "1",
            "alg": "HS256",
	    "nonce": this._nonce,
	};
	this._payload = {};
    }

    String get nonce => _header["nonce"] ?? "";
    Map<String, dynamic> get payload => _payload;
    
    void setPayload(Map<String, dynamic> payload) {
	this._payload = payload;
    }

    String toString() {
	String hp = base64.encode(utf8.encode(jsonEncode(this._header))) +
	    "." +
	    base64.encode(utf8.encode(jsonEncode(this._payload)));
	var hmac = new Hmac(sha256, utf8.encode(this.key));
	var digest = hmac.convert(utf8.encode(hp));
	return hp + "." + base64.encode(digest.bytes);
    }

    factory SignedJsonMessage.fromString(String s, String key, String expectedNonce) {
	// equivalent to s.rsplit(".", 1)
	int idx = s.lastIndexOf(".");
	var encodedHeaderPayload = s.substring(0,idx).trim();
	var encodedSignature = s.substring(idx+1).trim();
	var recvSig = base64.decode(encodedSignature);
	var hmac = new Hmac(sha256, utf8.encode(key));
	var calculatedSig = hmac.convert(utf8.encode(encodedHeaderPayload));
	if (calculatedSig.bytes.toString() != recvSig.toString()) {
	    throw("incorrect signature");
	}
	idx = encodedHeaderPayload.indexOf(".");
	var encodedHeader = encodedHeaderPayload.substring(0, idx).trim();
	var encodedPayload = encodedHeaderPayload.substring(idx+1).trim();
	var header = jsonDecode(utf8.decode(base64.decode(encodedHeader)));
	var payload = jsonDecode(utf8.decode(base64.decode(encodedPayload)));
	var nonce = header["nonce"];
	if (expectedNonce != "") {
	    if (nonce != expectedNonce) {
		throw("incorrect nonce ($nonce != $expectedNonce)");
	    }
	}
	var sjm = SignedJsonMessage(key, nonce);
	sjm.setPayload(payload);
	return sjm;
    }
}
