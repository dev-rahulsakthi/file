import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final controller = TextEditingController();

  void download() {
    final code = controller.text;
    html.window.open(
      "http://192.168.2.95:3123/download/$code",
      "_blank",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Receive File")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Enter 6-digit code",
              ),
            ),
            ElevatedButton(
              onPressed: download,
              child: const Text("Download"),
            ),
          ],
        ),
      ),
    );
  }
}