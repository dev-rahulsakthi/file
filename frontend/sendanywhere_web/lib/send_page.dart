import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  String? code;

  Future<void> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;

    final file = result.files.single;

    var request = http.MultipartRequest(
      "POST",
      Uri.parse("http://192.168.2.95:3123/upload"),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        file.bytes!,
        filename: file.name,
      ),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    setState(() {
      code = body.split(":")[1].replaceAll(RegExp(r'[^\d]'), '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send File")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: pickAndUpload,
              child: const Text("Select File"),
            ),
            if (code != null) ...[
              Text("Your Code: $code", style: const TextStyle(fontSize: 22)),
              QrImageView(data: code!, size: 200),
            ]
          ],
        ),
      ),
    );
  }
}