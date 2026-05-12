import 'dart:io';

import 'dart:convert';
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

  //写真の結果保持
  String? category;
  String? color;
  String? suggestion;

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

      //JSON解析
      final decoded = jsonDecode(result);

      setState(() {
        category = decoded['category'];
        color = decoded['color'];
        suggestion = decoded['suggestion'];
      });

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

            // AI結果表示
            if (category != null) ...[
              const SizedBox(height: 20),

              Text("カテゴリ: $category", style: const TextStyle(fontSize: 18)),
              Text("色: $color", style: const TextStyle(fontSize: 18)),
              Text("おすすめ: $suggestion", style: const TextStyle(fontSize: 18)),
            ],

          ],
        ),
      ),
    );
  }
}