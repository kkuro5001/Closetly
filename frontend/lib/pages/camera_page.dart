import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/storage_service.dart';
import '../services/clothing_service.dart';
import '../models/clothing.dart';

const _categoryOptions = [
  "Tシャツ",
  "シャツ",
  "パーカー",
  "セーター",
  "アウター",
  "パンツ",
  "スカート",
  "ワンピース",
  "靴",
  "帽子",
  "その他",
];

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {

  Uint8List? image;
  final picker = ImagePicker();
  final storageService = StorageService();
  final clothingService = ClothingService();

  // Supabaseアップロード用に選択中の画像ファイル名
  String? pickedFileName;

  bool isSaving = false;

  // 入力用コントローラー
  final colorController = TextEditingController();

  // 選択されたカテゴリ・季節
  String selectedCategory = _categoryOptions.first;
  String selectedSeason = "春秋";

  Future<void> takePhoto() => _pickImage(ImageSource.camera);

  Future<void> pickFromGallery() => _pickImage(ImageSource.gallery);

  Future<void> _pickImage(ImageSource source) async {

    debugPrint("===== CAMERA START =====");

    final pickedFile = await picker.pickImage(
      source: source,
    );

    debugPrint("撮影完了");

    if (pickedFile == null) {
      debugPrint("画像なし");
      debugPrint("===== CAMERA END =====");
      return;
    }

    debugPrint("画像パス: ${pickedFile.path}");

    final imageBytes = await pickedFile.readAsBytes();
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    setState(() {
      image = imageBytes;
      pickedFileName = fileName;
    });

    debugPrint("画像表示更新完了");
    debugPrint("===== CAMERA END =====");
  }

  // 画像をSupabase Storageへアップロードし、服の情報をSupabaseへ保存
  Future<void> saveClothing() async {

    if (image == null || pickedFileName == null) {
      return;
    }

    debugPrint("===== 保存開始 =====");

    setState(() {
      isSaving = true;
    });

    try {

      debugPrint("===== Supabaseアップロード開始 =====");

      final userId = Supabase.instance.client.auth.currentUser!.id;

      final imagePath = await storageService.uploadOriginal(
        image!,
        userId,
        pickedFileName!,
      );

      debugPrint("Supabaseアップロード完了: $imagePath");

      final clothing = Clothing(
        imagePath: imagePath,
        category: selectedCategory,
        color: colorController.text,
        season: selectedSeason,
      );

      debugPrint("保存データ:");
      debugPrint("imagePath: $imagePath");
      debugPrint("category: $selectedCategory");
      debugPrint("color: ${colorController.text}");
      debugPrint("season: $selectedSeason");

      await clothingService.insertClothing(
        clothing,
      );

      debugPrint("保存完了");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("服を保存しました"),
          ),
        );
      }

    } catch (e, stackTrace) {

      debugPrint("===== 保存エラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("服の保存に失敗しました: $e"),
          ),
        );
      }

    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }

    debugPrint("===== 保存終了 =====");
  }

  @override
  Widget build(BuildContext context) {

    debugPrint("===== build実行 =====");

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
                  Image.memory(
                    image!,
                    height: 300,
                  ),

                const SizedBox(height: 20),

                // 撮影・追加ボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: takePhoto,
                      child: const Text("写真を撮る"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: pickFromGallery,
                      child: const Text("写真を追加"),
                    ),
                  ],
                ),

                // 服の情報入力
                if (image != null) ...[

                  const SizedBox(height: 20),

                  // カテゴリ選択
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: "カテゴリ",
                      border: OutlineInputBorder(),
                    ),
                    items: _categoryOptions
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  // 色入力
                  TextField(
                    controller: colorController,
                    decoration: const InputDecoration(
                      labelText: "色",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 季節選択
                  DropdownButtonFormField<String>(
                    initialValue: selectedSeason,
                    decoration: const InputDecoration(
                      labelText: "季節",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "春秋",
                        child: Text("春秋"),
                      ),
                      DropdownMenuItem(
                        value: "夏",
                        child: Text("夏"),
                      ),
                      DropdownMenuItem(
                        value: "冬",
                        child: Text("冬"),
                      ),
                      DropdownMenuItem(
                        value: "オールシーズン",
                        child: Text("オールシーズン"),
                      ),
                    ],
                    onChanged: (value) {
                      debugPrint("季節変更: $value");
                      setState(() {
                        selectedSeason = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // 保存ボタン（Supabaseへのアップロード＋登録を一括で行う）
                  ElevatedButton(
                    onPressed: isSaving ? null : saveClothing,
                    child: Text(isSaving ? "保存中..." : "保存"),
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
