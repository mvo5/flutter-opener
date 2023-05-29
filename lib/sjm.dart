import 'dart:convert';

import 'package:crypto/crypto.dart';


class SignedJsonMessage {
    String key;
    String? _nonce;
    late Map<String, String> _header;
    late Map<String, dynamic> _payload;

    SignedJsonMessage(String this.key, String? this._nonce) {
	this._header =  {
            "ver": "1",
            "alg": "HS256",
	};
        if (this._nonce != null) {
            this._header["nonce"] = this._nonce!;
        }
	this._payload = {};
    }

    String? get nonce => _header["nonce"];
    Map<String, dynamic> get payload => _payload;
    
    void set_payload(Map<String, dynamic> payload) {
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

    factory SignedJsonMessage.fromString(String s, String key, String? expected_nonce) {
	// equivalent to s.rsplit(".", 1)
	int idx = s.lastIndexOf(".");
	var encoded_header_payload = s.substring(0,idx).trim();
	var encoded_signature = s.substring(idx+1).trim();
	var recv_sig = base64.decode(encoded_signature);
	var hmac = new Hmac(sha256, utf8.encode(key));
	var calculated_sig = hmac.convert(utf8.encode(encoded_header_payload));
	if (calculated_sig.bytes.toString() != recv_sig.toString()) {
	    throw("incorrect signature");
	}
	idx = encoded_header_payload.indexOf(".");
	var encoded_header = encoded_header_payload.substring(0, idx).trim();
	var encoded_payload = encoded_header_payload.substring(idx+1).trim();
	var header = jsonDecode(utf8.decode(base64.decode(encoded_header)));
	var payload = jsonDecode(utf8.decode(base64.decode(encoded_payload)));
	if (expected_nonce != null) {
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
