import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/storage_service.dart';
import '../services/clothing_service.dart';
import '../services/color_service.dart';
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

  final colorService = ColorService();

  // 色の自動解析中かどうか
  bool isAnalyzingColor = false;

  // 最新の色解析リクエスト番号(古い結果の上書き防止用)
  int _colorRequestId = 0;

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

    // 保存処理とは独立して色を自動入力する(失敗しても保存は可能)
    await _autofillColor(imageBytes);
  }

  // 画像から色を解析して色欄に入れる
  Future<void> _autofillColor(Uint8List imageBytes) async {

    // 解析中に別の写真が選ばれた場合に古い結果で上書きしないための番号
    final requestId = ++_colorRequestId;

    // 解析中にユーザーが色を手入力した場合はそちらを優先するため、開始時の値を覚えておく
    final textAtStart = colorController.text;

    debugPrint("===== 色解析開始 (#$requestId) =====");

    setState(() {
      isAnalyzingColor = true;
    });

    try {

      final color = await colorService.analyzeColor(imageBytes);

      // 画面破棄済み、または新しい写真が選ばれていたら結果を捨てる
      if (!mounted || requestId != _colorRequestId) {
        debugPrint("色解析結果を破棄 (#$requestId)");
        return;
      }

      if (colorController.text != textAtStart) {
        debugPrint("手入力済みのため自動入力しない (#$requestId)");
      } else if (color != null) {
        colorController.text = color;
        debugPrint("色を自動入力: $color");
      }

    } catch (e, stackTrace) {

      // 失敗しても色欄はそのまま(手入力・保存は引き続き可能)
      debugPrint("===== 色解析エラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

    } finally {
      if (mounted && requestId == _colorRequestId) {
        setState(() {
          isAnalyzingColor = false;
        });
      }
    }

    debugPrint("===== 色解析終了 (#$requestId) =====");
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
                    decoration: InputDecoration(
                      labelText: "色",
                      border: const OutlineInputBorder(),
                      // 解析中は小さなインジケーターを表示
                      suffixIcon: isAnalyzingColor
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
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
