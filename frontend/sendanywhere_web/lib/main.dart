import 'package:flutter/material.dart';
import 'send_page.dart';
import 'receive_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Send Anywhere Clone',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send Anywhere Clone")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("Send File"),
              onPressed: () =>
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SendPage())),
            ),
            ElevatedButton(
              child: const Text("Receive File"),
              onPressed: () =>
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ReceivePage())),
            ),
          ],
        ),
      ),
    );
  }
}