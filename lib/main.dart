import 'package:flutter/material.dart';
import 'package:furstapp/const.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(const BluetoothChatApp());

class BluetoothChatApp extends StatelessWidget {
  const BluetoothChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const BluetoothScreen(),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  String receivedText = "No data received yet";
  String threatAssessment = "";

  @override
  void initState() {
    super.initState();

    scanForDevices();
  }

  void scanForDevices() {
    // Use static access for FlutterBluePlus methods and properties
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.name == "RaspberryPi") {
          // Stop scanning and connect to the Raspberry Pi
          await FlutterBluePlus.stopScan();
          await result.device.connect();
          setState(() {
            connectedDevice = result.device;
          });
          discoverServices(result.device);
          break;
        }
      }
    });
  }

  void discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          setState(() {
            targetCharacteristic = characteristic;
          });

          // Enable notifications and listen for data
          await characteristic.setNotifyValue(true);
          characteristic.value.listen((value) {
            final decodedText = utf8.decode(value);
            setState(() {
              receivedText = decodedText;
            });
            assessThreat(decodedText);
          });
        }
      }
    }
  }

  Future<void> assessThreat(String text) async {
    const apiKey = open_api_key; // Replace with your API key
    const endpoint = 'https://api.openai.com/v1/chat/completions';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "system", "content": "Classify text as 'Threat' or 'No Threat'."},
          {"role": "user", "content": text}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final result = responseData['choices'][0]['message']['content'];
      setState(() {
        threatAssessment = result.contains("Threat") ? "Threat" : "No Threat";
      });
    } else {
      setState(() {
        threatAssessment = "Error in API call";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BTP App"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Received Text: $receivedText", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text("Assessment: $threatAssessment",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
