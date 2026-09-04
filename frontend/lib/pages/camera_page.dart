import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/upload_service.dart';
import '../services/storage_service.dart';
import '../services/clothing_service.dart';
import '../models/clothing.dart';

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

  // Supabaseにアップロード後のパスを保持
  String? uploadedImagePath;

  // Supabaseアップロード用に選択中の画像ファイル名
  String? pickedFileName;

  // AI結果保持
  String? category;
  String? color;
  String? suggestion;

  // 入力用コントローラー
  final categoryController = TextEditingController();
  final colorController = TextEditingController();

  // 選択された季節
  String selectedSeason = "春秋";

  Future<void> takePhoto() => _pickAndProcessImage(ImageSource.camera);

  Future<void> pickFromGallery() => _pickAndProcessImage(ImageSource.gallery);

  Future<void> _pickAndProcessImage(ImageSource source) async {

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
      uploadedImagePath = null; // 新しい画像を選び直したのでアップロード状態をリセット
    });

    debugPrint("画像表示更新完了");

    // AI解析（従来通りGoへローカルファイルを送信）
    try {

      debugPrint("===== GO通信開始 =====");

      final result = await UploadService.uploadImage(
        imageBytes,
        fileName,
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
      categoryController.text = decoded['category'] ?? "";
      colorController.text = decoded['color'] ?? "";

      // 画面更新
      setState(() {
        category = decoded['category'];
        color = decoded['color'];
        suggestion = decoded['suggestion'];
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

  // 選択中の画像をSupabase Storageへアップロード
  Future<void> uploadToSupabase() async {

    if (image == null || pickedFileName == null) {
      return;
    }

    debugPrint("===== Supabaseアップロード開始 =====");

    try {

      final userId = Supabase.instance.client.auth.currentUser!.id;

      final path = await storageService.uploadOriginal(
        image!,
        userId,
        pickedFileName!,
      );

      setState(() {
        uploadedImagePath = path;
      });

      debugPrint("Supabaseアップロード完了: $path");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("画像をSupabaseに保存しました"),
          ),
        );
      }

    } catch (e, stackTrace) {

      debugPrint("===== Supabaseアップロードエラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("画像の保存に失敗しました: $e"),
          ),
        );
      }
    }
  }

  // 撮影した服を保存
  Future<void> saveClothing() async {

    debugPrint("===== 保存開始 =====");

    if (uploadedImagePath == null) {
      debugPrint("uploadedImagePathがnull");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("先に「追加」ボタンで画像をSupabaseに保存してください"),
          ),
        );
      }

      return;
    }

    final clothing = Clothing(
      imagePath: uploadedImagePath!,  // ← Supabaseのstorage pathを保存
      category: categoryController.text,
      color: colorController.text,
      season: selectedSeason,
    );

    debugPrint("保存データ:");
    debugPrint("imagePath: $uploadedImagePath");
    debugPrint("category: ${categoryController.text}");
    debugPrint("color: ${colorController.text}");
    debugPrint("season: $selectedSeason");

    await clothingService.insertClothing(
      clothing,
    );

    debugPrint("保存完了");

    // Snackbar表示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("服を保存しました"),
        ),
      );
    }

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
                  Image.memory(
                    image!,
                    height: 300,
                  ),

                // Supabaseへの追加ボタン
                if (image != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: uploadedImagePath == null ? uploadToSupabase : null,
                    child: Text(uploadedImagePath == null ? "追加" : "追加済み"),
                  ),
                ],

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
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: "カテゴリ",
                      border: OutlineInputBorder(),
                    ),
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
                    value: selectedSeason,
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