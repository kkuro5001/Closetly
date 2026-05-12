import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/upload_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {

  File? image;

  final picker = ImagePicker();

  Future<void> takePhoto() async {

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
    );
    print("撮影完了");
    if (pickedFile == null) {
        print("画像なし");
        return;
    }

    print("画像パス: ${pickedFile.path}");

    setState(() {
      image = File(pickedFile.path);
    });

    try {

      print("Goへ送信開始");

      final result = await UploadService.uploadImage(
        pickedFile.path,
      );

      print("レスポンス:");
      print(result);

    } catch (e) {

      print("エラー発生");
      print(e);

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Camera"),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            if (image != null)
              Image.file(
                image!,
                height: 300,
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: takePhoto,
              child: const Text("写真を撮る"),
            ),
          ],
        ),
      ),
    );
  }
}