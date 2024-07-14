import 'dart:async';
import 'dart:convert';
import 'dart:io';


import 'package:flutter/material.dart';

import 'package:qrscan/qrscan.dart' as scanner;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fble;
// XXX: move to biometric storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:slider_button/slider_button.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:f_logs/f_logs.dart';
import 'package:open_settings/open_settings.dart';

import 'api.dart';

void main() {
    runApp(OpenerApp());
}

class OpenerApp extends StatelessWidget {
    // This widget is the root of your application.
    @override
    Widget build(BuildContext context) {
	return MaterialApp(
	    theme: ThemeData(),
	    darkTheme: ThemeData.dark(),
	    themeMode: ThemeMode.system,
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
    String _deviceName = "unsetb device name";
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
    // XXX2: ugly workaround for not being able to assign "null" to the map
    Map<String, dynamic> cfg = {
	"state": "initializing",
    };

    // will be mocked in tests
    late OpenerApi opener;
    late FlutterSecureStorage storage;

    void initState() {
	super.initState();
	initLogs();

	this.storage = new FlutterSecureStorage();
	this.opener = new OpenerApi();
	readCfg();
        initDeviceNameFromBluetooth();
    }

    initLogs() async {
	FLog.applyConfigurations(logCfg);
    }

    readCfg() async {
	final jsonCfg = await storage.read(key: "cfg");
	setState(() {
	    if (jsonCfg != null) {
		this.cfg = json.decode(jsonCfg);
	    } else {
		this.cfg = Map<String, dynamic>();
	    }
	    _statusText = "Ready";
	});
    }

    // get the name of the phone as advertised via bluetooth
    initDeviceNameFromBluetooth() async {
        var status = await Permission.bluetoothConnect.status;
        if (status.isDenied) {
            await Permission.bluetoothConnect.request();
        }
        if (await Permission.bluetoothConnect.status.isPermanentlyDenied) {
            openAppSettings();
        }

	_deviceName = await fble.FlutterBluePlus.adapterName;
	FLog.debug(text: "bluetooth device name: $_deviceName");
    }
    
    Future<String> callOpenerApi() async {
	final hmacKey = cfg["hmac-key"];
	final host = cfg["hostname"];
	final port = 8877;

	// XXX: add code that tries to reach the "host" before
	//      calling the opener API to avoid the issue that
	//      e.g. the network may not be connected yet?

	// XXX: ideally we would get the "device_name" here but flutter
	// seems to have no way to get it
	var info = "$_deviceName";
	if (Platform.isAndroid) {
	    final androidInfo = await deviceInfo.androidInfo;
	    info = "$_deviceName (${androidInfo.model}/${androidInfo.host})";
	}
	opener.init(host, port, hmacKey, info);
	
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
	// XXX: ugly
	if (cfg.length == 1 && cfg["state"] == "initializing") {
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
		action: () async{
		    FLog.debug(text: "slider button action");
		    setState(() {
			      _openerCall = true;
		    });
		    doCallOpenerApi();
        return true;
		});
	}
    }

    Future scanSecret() async {
	await Permission.camera.request();
	var cameraScanResult = await scanner.scan();
	if (cameraScanResult == null || cameraScanResult == "") {
	    return;
	}
	var jsonCfg = cameraScanResult;
	// XXX: do basic validation?
	await storage.write(key: "cfg", value: jsonCfg);

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
	var logs = await FLog.getAllLogs();
	var buffer = StringBuffer();
	setState(() {
	    buffer.write("Current logs:\n");
	    for (var log in logs.reversed) {
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
				child: Text(_logsText, textAlign: TextAlign.left,),
			    ),
			),
		    ],
		),
	    ),
	);
    }
}
