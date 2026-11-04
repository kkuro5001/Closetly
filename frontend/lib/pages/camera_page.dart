import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/storage_service.dart';
import '../services/clothing_service.dart';
import '../services/color_service.dart';
import '../models/clothing.dart';
import '../constants/clothing_options.dart';

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
  String selectedCategory = categoryOptions.first;
  String selectedSeason = seasonOptions.first;

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
        // 同じ写真を二重登録しないよう、写真と色はクリアして次の1着を登録できる状態に戻す。
        // カテゴリ・季節は続けて似た服を登録しやすいよう残す
        setState(() {
          image = null;
          pickedFileName = null;
          colorController.clear();
          // 解析中の結果が後から入らないよう番号を進める
          _colorRequestId++;
          isAnalyzingColor = false;
        });
      }

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
  void dispose() {
    colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final hasImage = image != null;

    return Scaffold(

      appBar: AppBar(
        title: const Text("服を登録"),
      ),

      // 保存ボタンは画面下に固定(入力欄をスクロールしても常に押せる)
      bottomNavigationBar: hasImage
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: isSaving ? null : saveClothing,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(isSaving ? "保存中..." : "クローゼットに保存"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            )
          : null,

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          // Webの広い画面で入力欄が横に伸びすぎないよう幅を制限
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                hasImage ? _buildPreview() : _buildPickPlaceholder(),

                // 服の情報入力
                if (hasImage) ...[

                  const SizedBox(height: 24),

                  _sectionTitle("カテゴリ"),
                  _buildChoiceChips(
                    categoryOptions,
                    selectedCategory,
                    (value) => setState(() {
                      selectedCategory = value;
                    }),
                  ),

                  const SizedBox(height: 20),

                  _sectionTitle("季節"),
                  _buildChoiceChips(
                    seasonOptions,
                    selectedSeason,
                    (value) {
                      debugPrint("季節変更: $value");
                      setState(() {
                        selectedSeason = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  _sectionTitle("色"),
                  TextField(
                    controller: colorController,
                    decoration: InputDecoration(
                      hintText: "例: 黒、ネイビー",
                      helperText: isAnalyzingColor
                          ? "写真から色を判定中…"
                          : "写真から自動で入力されます(変更できます)",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.palette_outlined),
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 写真が未選択のとき: 大きな枠の中に「撮る / 選ぶ」を並べる
  Widget _buildPickPlaceholder() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            "登録する服の写真を用意しましょう",
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "服だけが写るように撮ると色の判定が正確になります",
            style: TextStyle(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: takePhoto,
                child: const Text("写真を撮る"),
              ),
              OutlinedButton(
                onPressed: pickFromGallery,
                child: const Text("アルバムから選ぶ"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 写真を選択済みのとき: プレビューと、撮り直し/選び直しボタン
  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Image.memory(
              image!,
              height: 320,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: isSaving ? null : takePhoto,
              child: const Text("撮り直す"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: isSaving ? null : pickFromGallery,
              child: const Text("別の写真を選ぶ"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  // ドロップダウンを開かずに1タップで選べるよう、選択肢をすべてチップで並べる
  Widget _buildChoiceChips(
    List<String> options,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}
