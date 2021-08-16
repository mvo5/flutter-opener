import 'package:flutter_test/flutter_test.dart';

import 'package:muopener/sjm.dart';

void main() {
    test('SignedJsonMessage signed smoke', () {
	var sjm = SignedJsonMessage("key", "nonce");
	sjm.set_payload({"foo": "bar"});
	expect(sjm.nonce, equals("nonce"));
    });

    test('SignedJsonMessage.from_string', () {
	var s = "eyJub25jZSI6ICJub25jZSIsICJ2ZXIiOiAiMSIsICJhbGciOiAiSFM1MTIifQ==.e30=.jWvOyRuz0lSMFRqkpPXj+nsvDp+gS7Xucg7w5WX6UdoZIq8FbSBR6wKS9B0TGzzr4/3vMnVSBRov0dkQWYL/yw==";
	var sjm = SignedJsonMessage.fromString(s, "key", "nonce");
	// XXX: test more
	expect(sjm.payload, equals({}));
    });
}
