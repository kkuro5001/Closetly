import 'dart:io';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/upload_service.dart';

import '../database/database_helper.dart';
import '../models/clothing.dart';

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

  //保存する入力ようのコントローラー
  final categoryController =
    TextEditingController();

  final colorController =
      TextEditingController();

  final memoController =
      TextEditingController();

  Future<void> takePhoto() async {

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
    );
    debugPrint("撮影完了");
    if (pickedFile == null) {
        debugPrint("画像なし");
        return;
    }

    debugPrint("画像パス: ${pickedFile.path}");

    setState(() {
      image = File(pickedFile.path);
    });

    try {

      debugPrint("Goへ送信開始");

      final result = await UploadService.uploadImage(
        pickedFile.path,
      );

      debugPrint("レスポンス:");
      debugPrint(result);

      //JSON解析
      final decoded = jsonDecode(result);

      setState(() {
        category = decoded['category'];
        color = decoded['color'];
        suggestion = decoded['suggestion'];
      });

    } catch (e) {

      debugPrint("エラー発生");
      debugPrint(e.toString());

    }

  }

  //撮影した服を保存する関数
  Future<void> saveClothing() async {

    if (image == null) {
      return;
    }

    final clothing = Clothing(
      imagePath: image!.path,
      category: categoryController.text,
      color: colorController.text,
      memo: memoController.text,
    );

    await DatabaseHelper.instance.insertClothing(
      clothing,
    );

    debugPrint("保存完了");
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

            // AI結果表示して、カテゴリなどを入力して保存する
            if (category != null) ...[
              const SizedBox(height: 20),

              Text(
                "カテゴリ: $category",
                style: const TextStyle(fontSize: 18),
              ),

              Text(
                "色: $color",
                style: const TextStyle(fontSize: 18),
              ),

              Text(
                "おすすめ: $suggestion",
                style: const TextStyle(fontSize: 18),
              ),

              const SizedBox(height: 20),

              //カテゴリ入力
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: "カテゴリ",
                ),
              ),

              //色入力
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: "色",
                ),
              ),

              //メモ入力
              TextField(
                controller: memoController,
                decoration: const InputDecoration(
                  labelText: "メモ",
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: saveClothing,
                child: const Text("保存"),
              ),
            ],

          ],
        ),
      ),
    );
  }
}