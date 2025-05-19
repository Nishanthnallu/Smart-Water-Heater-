import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'dart:async'; // Import to use Timer

double desiredTemp = 40.0;
int timerMinutes = 1;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const WaterHeaterApp());
}

class WaterHeaterApp extends StatelessWidget {
  const WaterHeaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WaterHeaterScreen(),
    );
  }
}

class WaterHeaterScreen extends StatefulWidget {
  const WaterHeaterScreen({super.key});

  @override
  State<WaterHeaterScreen> createState() => _WaterHeaterScreenState();
}

class _WaterHeaterScreenState extends State<WaterHeaterScreen> {
  bool heaterOn = false;
  double temperature = 0.0;
  double flowRate = 0.0;
  double current = 0.0;
  int remainingSeconds = 0;
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
    'waterHeaterData',
  );
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String spokenCommand = "";

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _fetchFirebaseData();
  }

  Future<void> _initSpeech() async {
    await Permission.microphone.request();
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

void _fetchFirebaseData() {
  dbRef.onValue.listen((event) {
    final data = event.snapshot.value as Map?;
    if (data != null) {
      setState(() {
        temperature = double.tryParse(data['temperature'].toString()) ?? 0.0;
        flowRate = double.tryParse(data['flowRate'].toString()) ?? 0.0;
        current = double.tryParse(data['current'].toString()) ?? 0.0;

        final status = data['heaterStatus']?.toString().toLowerCase();
        heaterOn = status == 'on';
      });
    }
  });
}


void _toggleHeater(bool turnOn) {
  if (heaterOn == turnOn) return; // Skip if already in desired state

  setState(() {
    heaterOn = turnOn;
  });

  dbRef.update({'heaterStatus': heaterOn ? "ON" : "OFF"});
}


  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult, localeId: 'en_US');
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      spokenCommand = result.recognizedWords;
      if (spokenCommand.toLowerCase().contains("turn on")) {
        _toggleHeater(true);
      } else if (spokenCommand.toLowerCase().contains("turn off")) {
        _toggleHeater(false);
      }
      setState(() {});
    }
  }

  void _startTimer() {
    _toggleHeater(true);
    remainingSeconds = timerMinutes * 60;
    setState(() {});
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        _toggleHeater(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text('Smart Water Heater'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        // Wrap the body in a scrollable widget
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (remainingSeconds > 0)
              Text(
                'Time Remaining: ${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Set Desired Temperature (°C)",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                desiredTemp = double.tryParse(val) ?? desiredTemp;
              },
            ),
            const SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Set Timer (minutes)",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                timerMinutes = int.tryParse(val) ?? timerMinutes;
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _toggleHeater(true);
                _startTimer();
              },
              child: const Text("Start Timer"),
            ),
            const SizedBox(height: 20),
            Center(
              child: Icon(
                Icons.hot_tub,
                size: 80,
                color: heaterOn ? Colors.red : Colors.grey,
              ),
            ),
            Center(
              child: Text(
                heaterOn ? "Heater is ON" : "Heater is OFF",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Center(
              child: Switch(
                value: heaterOn,
                onChanged: (value) => _toggleHeater(value),
                activeColor: Colors.red,
              ),
            ),
            const Divider(height: 20),
            buildSensorTile("Temperature", "$temperature °C"),
            buildSensorTile("Flow Rate", "$flowRate L/min"),
            buildSensorTile("Current", "$current A"),
            const SizedBox(height: 20),
            const Text(
              "Voice Command Result:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(spokenCommand),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? _stopListening : _startListening,
        tooltip: 'Listen',
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }

  Widget buildSensorTile(String label, String value) {
    return ListTile(
      leading: const Icon(Icons.analytics),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontSize: 18)),
    );
  }
}
