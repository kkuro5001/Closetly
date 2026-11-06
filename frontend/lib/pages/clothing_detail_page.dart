import 'package:flutter/material.dart';

import '../constants/clothing_options.dart';
import '../models/clothing.dart';
import '../services/clothing_service.dart';
import '../models/wear_log.dart';
import '../services/storage_service.dart';
import '../services/wear_log_service.dart';
import '../utils/wear_stats.dart';
import '../widgets/size_field.dart';

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
  final wearLogService = WearLogService();

  bool isDeleting = false;
  bool isSaving = false;

  // 編集後の値を反映するための表示用コピー
  late Clothing clothing = widget.clothing;

  // 編集したかどうか(戻るときに一覧の再読み込みを促す)
  bool edited = false;

  // 着用記録。読み込み失敗(テーブル未作成など)でも他の表示・操作は壊さず、着用欄だけエラーにする
  List<WearLog> wearLogs = [];
  bool wearLoading = true;
  String? wearError;
  bool isWearBusy = false; // 連打防止

  @override
  void initState() {
    super.initState();
    _loadWearLogs();
  }

  Future<void> _loadWearLogs() async {

    setState(() {
      wearLoading = true;
      wearError = null;
    });

    try {

      final logs = await wearLogService.getWearLogsForClothing(clothing.id!);

      if (!mounted) return;
      setState(() {
        wearLogs = logs;
        wearLoading = false;
      });

    } catch (e) {

      debugPrint("着用記録の取得に失敗: $e");

      if (!mounted) return;
      setState(() {
        wearError = e.toString();
        wearLoading = false;
      });
    }
  }

  // 今日(端末のローカル日付)の記録があるか
  bool get _wornToday {
    final today = dateOnly(DateTime.now());
    return wearLogs.any((l) => l.wornOn == today);
  }

  // 「今日着た」の記録 / 取り消し
  Future<void> _toggleWornToday() async {

    if (isWearBusy) return;

    final today = dateOnly(DateTime.now());
    final cancel = _wornToday;

    setState(() {
      isWearBusy = true;
    });

    try {

      if (cancel) {
        await wearLogService.removeWear(clothing.id!, today);
      } else {
        await wearLogService.recordWear([clothing.id!], today);
      }

      final logs = await wearLogService.getWearLogsForClothing(clothing.id!);

      if (!mounted) return;
      setState(() {
        wearLogs = logs;
        wearError = null;
        edited = true;
        isWearBusy = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cancel ? "今日の記録を取り消しました" : "今日着た記録を保存しました")),
      );

    } catch (e) {

      debugPrint("着用記録の更新に失敗: $e");

      if (!mounted) return;
      setState(() {
        isWearBusy = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("着用記録の更新に失敗しました: $e")),
      );
    }
  }

  Widget _buildWearSection() {

    const titleStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    if (wearLoading) {
      return const Row(
        children: [
          Text("着用", style: titleStyle),
          SizedBox(width: 12),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    if (wearError != null) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              "着用記録を読み込めませんでした",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: _loadWearLogs,
            child: const Text("再読み込み"),
          ),
        ],
      );
    }

    final summary = summarizeWearLogs(wearLogs)[clothing.id];
    final last = summary?.lastWornOn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("着用", style: titleStyle),
        const SizedBox(height: 6),
        Text("着た回数: ${summary?.count ?? 0} 回", style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          "最後に着た日: ${last == null ? "まだ着ていません" : _formatDate(last)}",
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 8),
        _wornToday
            ? OutlinedButton.icon(
                onPressed: isWearBusy ? null : _toggleWornToday,
                icon: const Icon(Icons.undo),
                label: const Text("今日の記録を取り消す"),
              )
            : ElevatedButton.icon(
                onPressed: isWearBusy ? null : _toggleWornToday,
                icon: const Icon(Icons.check),
                label: const Text("今日着た"),
              ),
      ],
    );
  }

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
        size: result.size,
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

      // 着用欄を足して縦に伸びたので、小さい画面でも溢れないようスクロール可能にする
      body: SingleChildScrollView(
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

            const SizedBox(height: 10),

            Text(
              "サイズ: ${clothing.size ?? "未設定"}",
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

            const SizedBox(height: 16),

            _buildWearSection(),
          ],
        ),
      ),
    );
  }
}

// カテゴリ・色・季節・サイズの編集ダイアログ。保存で編集後のClothingを返す
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
  late final TextEditingController sizeController =
      TextEditingController(text: widget.clothing.size ?? "");

  String? colorError;

  @override
  void dispose() {
    colorController.dispose();
    sizeController.dispose();
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
        size: normalizeSize(sizeController.text),
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

            const SizedBox(height: 12),

            SizeField(
              controller: sizeController,
              labelText: "サイズ(任意)",
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
