import 'package:flutter/material.dart';

import '../constants/clothing_options.dart';
import '../models/clothing.dart';
import '../services/clothing_service.dart';
import '../services/storage_service.dart';

class ClothingDetailPage extends StatefulWidget {

  final Clothing clothing;

  const ClothingDetailPage({
    super.key,
    required this.clothing,
  });

  @override
  State<ClothingDetailPage> createState() => _ClothingDetailPageState();
}

class _ClothingDetailPageState extends State<ClothingDetailPage> {

  final storageService = StorageService();
  final clothingService = ClothingService();

  bool isDeleting = false;
  bool isSaving = false;

  // 編集後の値を反映するための表示用コピー
  late Clothing clothing = widget.clothing;

  // 編集したかどうか(戻るときに一覧の再読み込みを促す)
  bool edited = false;

  Future<void> _edit() async {

    final result = await showDialog<Clothing>(
      context: context,
      builder: (context) => _EditDialog(clothing: clothing),
    );

    if (result == null) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {

      await clothingService.updateClothing(
        clothing.id!,
        category: result.category,
        color: result.color,
        season: result.season,
      );

      if (!mounted) return;

      setState(() {
        clothing = result;
        edited = true;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("更新しました")),
      );

    } catch (e) {

      debugPrint("服の更新に失敗: $e");

      if (mounted) {
        setState(() {
          isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("更新に失敗しました: $e")),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _confirmAndDelete() async {

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("服を削除"),
        content: const Text("この服を削除しますか？この操作は取り消せません。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("削除"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {

      await clothingService.deleteClothing(widget.clothing.id!);
      await storageService.deleteImage(widget.clothing.imagePath);

      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e) {

      if (mounted) {
        setState(() {
          isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("削除に失敗しました: $e"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 編集済みなら true を返して一覧を再読み込みさせる
          Navigator.pop(context, edited);
        }
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {

    return Scaffold(

      appBar: AppBar(
        title: const Text("服の詳細"),
        actions: [
          IconButton(
            onPressed: (isDeleting || isSaving) ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: (isDeleting || isSaving) ? null : _confirmAndDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            if (isSaving) const LinearProgressIndicator(),

            Center(
              child: FutureBuilder<String>(
                future: storageService.getSignedUrl(clothing.imagePath),
                builder: (context, snapshot) {

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 350,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox(
                      height: 350,
                      child: Center(
                        child: Icon(Icons.broken_image, size: 64),
                      ),
                    );
                  }

                  return Image.network(
                    snapshot.data!,
                    height: 350,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 350,
                        child: Center(
                          child: Icon(Icons.broken_image, size: 64),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "カテゴリ: ${clothing.category}",
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "色: ${clothing.color}",
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "季節: ${clothing.season}",
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            if (clothing.createdAt != null) ...[
              const SizedBox(height: 10),

              Text(
                "保存日: ${_formatDate(clothing.createdAt!)}",
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// カテゴリ・色・季節の編集ダイアログ。保存で編集後のClothingを返す
class _EditDialog extends StatefulWidget {

  final Clothing clothing;

  const _EditDialog({required this.clothing});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {

  late String category = widget.clothing.category;
  late String season = widget.clothing.season;
  late final TextEditingController colorController =
      TextEditingController(text: widget.clothing.color);

  String? colorError;

  @override
  void dispose() {
    colorController.dispose();
    super.dispose();
  }

  void _submit() {

    final color = colorController.text.trim();

    if (color.isEmpty) {
      setState(() {
        colorError = "色を入力してください";
      });
      return;
    }

    Navigator.pop(
      context,
      widget.clothing.copyWith(
        category: category,
        color: color,
        season: season,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      title: const Text("服を編集"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: "カテゴリ"),
              items: optionsWithCurrent(categoryOptions, widget.clothing.category)
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: colorController,
              decoration: InputDecoration(
                labelText: "色",
                errorText: colorError,
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: season,
              decoration: const InputDecoration(labelText: "季節"),
              items: optionsWithCurrent(seasonOptions, widget.clothing.season)
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => season = v ?? season),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text("保存"),
        ),
      ],
    );
  }
}
