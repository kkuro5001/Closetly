import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../models/outfit.dart';
import '../services/clothing_service.dart';
import '../services/outfit_service.dart';
import '../services/wear_log_service.dart';
import '../utils/outfit_utils.dart';
import '../widgets/clothing_thumbnail.dart';
import 'clothing_detail_page.dart';

// コーデの詳細。変更(削除・服の編集/削除)があれば true で pop する
class OutfitDetailPage extends StatefulWidget {

  final Outfit outfit;

  const OutfitDetailPage({super.key, required this.outfit});

  @override
  State<OutfitDetailPage> createState() => _OutfitDetailPageState();
}

class _OutfitDetailPageState extends State<OutfitDetailPage> {

  final outfitService = OutfitService();
  final clothingService = ClothingService();
  final wearLogService = WearLogService();

  List<Clothing> items = [];
  bool isLoading = true;
  String? errorMessage;

  bool isDeleting = false;
  bool isRecording = false;

  // 服の編集・削除があったか(あれば戻ったとき一覧を再読み込みさせる)
  bool changed = false;

  Outfit get outfit => widget.outfit;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final all = await clothingService.getAllClothing();
      if (!mounted) return;
      setState(() {
        items = resolveOutfitClothes(outfit, all);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("コーデの服取得エラー: $e");
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> recordToday() async {

    if (isRecording || items.isEmpty) return;
    setState(() => isRecording = true);

    try {
      // 端末のローカル日付で記録する
      await wearLogService.recordWear(
        items.map((c) => c.id).whereType<int>().toList(),
        DateTime.now(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("今日着たものとして記録しました")),
      );
    } catch (e) {
      debugPrint("着用記録エラー: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("記録に失敗しました: $e")),
      );
    } finally {
      if (mounted) setState(() => isRecording = false);
    }
  }

  Future<void> deleteOutfit() async {

    final id = outfit.id;
    if (id == null || isDeleting) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("コーデを削除"),
        content: const Text("このコーデを削除しますか?(服は削除されません)"),
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
    if (ok != true) return;

    setState(() => isDeleting = true);

    try {
      await outfitService.deleteOutfit(id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("コーデ削除エラー: $e");
      if (!mounted) return;
      setState(() => isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("削除に失敗しました: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(outfit.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: "削除",
              onPressed: isDeleting ? null : deleteOutfit,
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("服の取得に失敗しました\n$errorMessage", textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loadItems,
              child: const Text("再読み込み"),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (outfit.note.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(outfit.note),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // 服が削除されて減っていても、エラーにせず状況を知らせる
        if (items.length < outfit.clothingIds.length || items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              "削除された服はこのコーデから外れています",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        if (items.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final clothing = items[index];
              return GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ClothingDetailPage(clothing: clothing),
                    ),
                  );
                  // 編集・削除されたら服を取り直し、一覧側にも変更を伝える
                  if (result == true) {
                    changed = true;
                    loadItems();
                  }
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClothingThumbnail(
                          imagePath: clothing.imagePath,
                          width: double.infinity,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          clothing.category,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: (isRecording || items.isEmpty) ? null : recordToday,
          icon: isRecording
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text("今日このコーデを着た"),
        ),
      ],
    );
  }
}
