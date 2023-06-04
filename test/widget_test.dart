// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:slider_button/slider_button.dart';

import 'package:mockito/annotations.dart';

import 'package:mockito/mockito.dart';

import 'package:muopener/main.dart';
import 'package:muopener/api.dart';

import 'widget_test.mocks.dart';

@GenerateMocks([OpenerApi,FlutterSecureStorage])
void main() {
    testWidgets('Opener main flow with valid config', (WidgetTester tester) async {
	var storage = MockFlutterSecureStorage();
	when(storage.read(key: "cfg")).thenAnswer(
	    (_) async => '{"hostname": "opener", "hmac-key": "hmackey"}'
	);
	
	var opener = MockOpenerApi();
	when(opener.init("opener", 8877, "hmackey", "unknown")).thenReturn(0);
	when(opener.open()).thenAnswer((_) async => "Opening...");

	// Build our app
	var app = OpenerApp();
	await tester.pumpWidget(app);

	// add mocks
	final state = tester.state(find.byType(OpenerHomePage)) as OpenerHomePageState;
	state.opener = opener;
	state.storage = storage;
	// readCfg must be called again with fake storage
	state.readCfg();
	// XXX: why does "await tester.pumpAndSettle()" does not work here ?
	await tester.pumpWidget(OpenerApp(),  Duration(milliseconds: 100));

	// Verify that we have a text
	expect(find.text('Slide to open'), findsOneWidget);
	expect(find.text('close'), findsNothing);

	// pretend to drag the open slider
	await tester.drag(find.byType(SliderButton), Offset(500.0, 0.0));
	// pumpAndSettle cannot be used because of the spinner animation
	for (int i = 0 ; i<10; i++) {
	    await tester.pumpWidget(app,  Duration(milliseconds: 100));
	}

	// Verify that it tries to open the door
	expect(find.byKey(Key("label_status")), findsOneWidget);
	var labelStatus = find.byKey(Key("label_status")).evaluate().first.widget as Text;
	expect(labelStatus.data, "Opening...");
    });
}
