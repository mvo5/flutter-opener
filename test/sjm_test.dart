import 'package:flutter_test/flutter_test.dart';

import 'package:muopener/sjm.dart';

void main() {
    test('SignedJsonMessage signed smoke', () {
	var sjm = SignedJsonMessage("key", "nonce");
	sjm.set_payload({"foo": "bar"});
	expect(sjm.nonce, equals("nonce"));
    });

    test('SignedJsonMessage.from_string', () {
	var s = "eyJ2ZXIiOiAiMSIsICJhbGciOiAiSFMyNTYiLCAibm9uY2UiOiAibm9uY2UifQ==.e30=.iCQB3KZ4Kd9wnDrhYtTF/TBX3iJLFgApBfX+wMGw5hY=";
	var sjm = SignedJsonMessage.fromString(s, "key", "nonce");
	// XXX: test more
	expect(sjm.payload, equals({}));
    });

    test('SignedJsonMessage.from_string expected nonce is optional', () {
	var s = "eyJ2ZXIiOiAiMSIsICJhbGciOiAiSFMyNTYiLCAibm9uY2UiOiAibm9uY2UifQ==.e30=.iCQB3KZ4Kd9wnDrhYtTF/TBX3iJLFgApBfX+wMGw5hY=";
	var sjm = SignedJsonMessage.fromString(s, "key", "");
	// XXX: test more
	expect(sjm.payload, equals({}));
    });
}
