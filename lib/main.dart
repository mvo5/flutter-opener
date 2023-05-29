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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:f_logs/f_logs.dart';
import 'package:open_settings/open_settings.dart';

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
    OpenerHomePage({super.key, required this.title});
    final String title;
    
    @override
    OpenerHomePageState createState() => OpenerHomePageState();
}

class OpenerHomePageState extends State<OpenerHomePage> {
    final deviceInfo = DeviceInfoPlugin();
    bool _openerCall = false;
    String _statusText = "";
    String _logsText = "";
    final logCfg = FLog.getDefaultConfigurations()
	  ..formatType = FormatType.FORMAT_CUSTOM
	  ..customClosingDivider = ":"
          ..timestampFormat = TimestampFormat.TIME_FORMAT_FULL_3
          // XXX: make configurable
	  ..activeLogLevel = LogLevel.DEBUG
	  ..logLevelsEnabled = [
	      LogLevel.DEBUG,
	      LogLevel.INFO,
	      LogLevel.WARNING,
	      LogLevel.ERROR,
	      LogLevel.SEVERE
          ]
	  ..fieldOrderFormatCustom = [
	      FieldName.TIMESTAMP,
	      FieldName.LOG_LEVEL,
	      FieldName.TEXT,
	      FieldName.EXCEPTION,
	      FieldName.STACKTRACE
	  ];

    // this is read from the security store at startup
    // XXX: make it a list to support multiple doors
    Map<String, dynamic> cfg = new Map<String, dynamic>();

    // will be mocked in tests
    late OpenerApi opener;
    late FlutterSecureStorage storage;

    void initState() {
	super.initState();
	initLogs();

	this.storage = new FlutterSecureStorage();
	this.opener = new OpenerApi();
	readCfg();
    }

    initLogs() async {
	FLog.applyConfigurations(logCfg);
    }

    readCfg() async {
	final json_cfg = await storage.read(key: "cfg");
	setState(() {
	    if (json_cfg != null) {
		this.cfg = json.decode(json_cfg);
	    } else {
		this.cfg = Map<String, dynamic>();
	    };
	    _statusText = "Ready";
	});
    }
    
    Future<String> callOpenerApi() async {
	final hmac_key = cfg["hmac-key"];
	final host = cfg["hostname"];
	final port = 8877;

	// XXX: add code that tries to reach the "host" before
	//      calling the opener API to avoid the issue that
	//      e.g. the network may not be connected yet?

	// XXX: ideally we would get the "device_name" here but flutter
	// seems to have no way to get it
	var device_info = "unknown";
	if (Platform.isAndroid) {
	    final androidInfo = await deviceInfo.androidInfo;
	    device_info = "${androidInfo.model}/${androidInfo.host}";
	}
	opener.init(host, port, hmac_key, device_info);
	
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

    Widget getOpenOrSpinnerWidget() {
	if (cfg == null) {
	    return Column(
		crossAxisAlignment: CrossAxisAlignment.center,
		children: <Widget>[
		    Text("Initializing..."),
		]);
	}else if (cfg.length == 0) {
	    return Column(
		crossAxisAlignment: CrossAxisAlignment.center,
		children: <Widget>[
		    Text("No configuration yet"),
		    Container(
			child: ElevatedButton(
			    child: Text("Scan setting"),
			    onPressed: () {
				scanSecret();
			    }
			),
		    ),
		],
	    );
	} else if(_openerCall) {
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
		    FLog.debug(text: "slider button action");
		    setState(() {
			_openerCall = true;
		    });
		    doCallOpenerApi();
		});
	};
    }

    Future scanSecret() async {
	await Permission.camera.request();
	var cameraScanResult = await scanner.scan();
	if (cameraScanResult == null || cameraScanResult == "") {
	    return;
	}
	var json_cfg = cameraScanResult;
	// XXX: do basic validation?
	await storage.write(key: "cfg", value: json_cfg);

	await readCfg();
    }

    Future clearSecret() async {
	await storage.delete(key: "cfg");
	await readCfg();
    }

    void showLogs() async {
	// to console
	FLog.printLogs();

	// to the widget
	var formatter = Formatter();
	var logs = await FLog.getAllLogs();
	var buffer = StringBuffer();
	setState(() {
	    buffer.write("Current logs:\n");
	    for (var log in logs) {
		buffer.write(Formatter.format(log, logCfg));
	    }
	    _logsText = buffer.toString();
	});
        
    }

    void clearLogs() async {
	setState(() {
	    _logsText = "";
	});
	await FLog.clearLogs();
    }

    void onSelectedClick(String value) {
	switch (value) {
	case 'Open WiFi settings':
	    OpenSettings.openWIFISetting();
	    break;
	case 'Scan settings':
	    scanSecret();
	    break;
	case 'Clear settings':
	    clearSecret();
	    break;
	case 'Show logs':
	    showLogs();
	    break;
	case 'Clear logs':
	    clearLogs();
	    break;
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
			    return {
				'Open WiFi settings',
				'Scan settings',
				'Show logs',
				'',
				'Clear logs',
				'Clear settings',
			    }.map((String choice) {
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
			Expanded(
			    child: SingleChildScrollView(
				scrollDirection: Axis.vertical,
                                reverse: true,
				child: Text(_logsText, textAlign: TextAlign.left,),
			    ),
			),
		    ],
		),
	    ),
	);
    }
}
