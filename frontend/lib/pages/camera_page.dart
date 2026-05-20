// pages/camera_page.dart

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

  // AI結果保持
  String? category;
  String? color;
  String? suggestion;

  // 入力用コントローラー
  final categoryController =
      TextEditingController();

  final colorController =
      TextEditingController();

  final seasonController =
      TextEditingController();

  Future<void> takePhoto() async {

    debugPrint("===== CAMERA START =====");

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
    );

    debugPrint("撮影完了");

    if (pickedFile == null) {

      debugPrint("画像なし");
      debugPrint("===== CAMERA END =====");

      return;
    }

    debugPrint("画像パス: ${pickedFile.path}");

    setState(() {
      image = File(pickedFile.path);
    });

    debugPrint("画像表示更新完了");

    try {

      debugPrint("===== GO通信開始 =====");

      final result = await UploadService.uploadImage(
        pickedFile.path,
      );

      debugPrint("===== GOレスポンス =====");
      debugPrint(result);

      // JSON解析
      final decoded = jsonDecode(result);

      debugPrint("===== JSON解析結果 =====");
      debugPrint(decoded.toString());

      debugPrint("category: ${decoded['category']}");
      debugPrint("color: ${decoded['color']}");
      debugPrint("suggestion: ${decoded['suggestion']}");

      // 入力欄へ自動反映
      categoryController.text =
          decoded['category'] ?? "";

      colorController.text =
          decoded['color'] ?? "";

      // 画面更新
      setState(() {

        category =
            decoded['category'];

        color =
            decoded['color'];

        suggestion =
            decoded['suggestion'];
      });

      debugPrint("setState完了");
      debugPrint("現在のcategory: $category");

      debugPrint("===== CAMERA SUCCESS =====");

    } catch (e, stackTrace) {

      debugPrint("===== エラー発生 =====");

      debugPrint(e.toString());

      debugPrint("===== STACK TRACE =====");

      debugPrint(stackTrace.toString());

    }

    debugPrint("===== CAMERA END =====");
  }

  // 撮影した服を保存
  Future<void> saveClothing() async {

    debugPrint("===== 保存開始 =====");

    if (image == null) {

      debugPrint("imageがnull");

      return;
    }

    final clothing = Clothing(
      imagePath: image!.path,
      category: categoryController.text,
      color: colorController.text,
      season: seasonController.text,
    );

    debugPrint("保存データ:");
    debugPrint("imagePath: ${image!.path}");
    debugPrint("category: ${categoryController.text}");
    debugPrint("color: ${colorController.text}");
    debugPrint("season: ${seasonController.text}");

    await DatabaseHelper.instance.insertClothing(
      clothing,
    );

    debugPrint("保存完了");
    debugPrint("===== 保存終了 =====");
  }

  @override
  Widget build(BuildContext context) {

    debugPrint("===== build実行 =====");
    debugPrint("category: $category");

    return Scaffold(

      appBar: AppBar(
        title: const Text("Camera"),
      ),

      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [

                // 撮影画像
                if (image != null)
                  Image.file(
                    image!,
                    height: 300,
                  ),

                const SizedBox(height: 20),

                // 撮影ボタン
                ElevatedButton(
                  onPressed: takePhoto,
                  child: const Text("写真を撮る"),
                ),

                // AI結果表示
                if (category != null) ...[

                  const SizedBox(height: 20),

                  const Text(
                    "AI判定結果",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "カテゴリ: $category",
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  Text(
                    "色: $color",
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  Text(
                    "おすすめ: $suggestion",
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // カテゴリ入力
                  TextField(
                    controller:
                        categoryController,
                    decoration:
                        const InputDecoration(
                      labelText: "カテゴリ",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 色入力
                  TextField(
                    controller:
                        colorController,
                    decoration:
                        const InputDecoration(
                      labelText: "色",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 季節入力
                  TextField(
                    controller:
                        seasonController,
                    decoration:
                        const InputDecoration(
                      labelText: "季節",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 20),

                  // 保存ボタン
                  ElevatedButton(
                    onPressed: saveClothing,
                    child: const Text("保存"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}