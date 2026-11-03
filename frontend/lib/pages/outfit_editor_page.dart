import 'package:flutter/material.dart';

import '../constants/clothing_options.dart';
import '../models/clothing.dart';
import '../services/clothing_service.dart';
import '../services/outfit_service.dart';
import '../utils/outfit_utils.dart';
import '../widgets/clothing_thumbnail.dart';

// コーデの手動作成。名前を入れて、服をグリッドから2着以上選んで保存する。
// 保存したら true で pop する
class OutfitEditorPage extends StatefulWidget {
  const OutfitEditorPage({super.key});

  @override
  State<OutfitEditorPage> createState() => _OutfitEditorPageState();
}

class _OutfitEditorPageState extends State<OutfitEditorPage> {

  final outfitService = OutfitService();
  final clothingService = ClothingService();
  final nameController = TextEditingController();

  List<Clothing> clothes = [];
  final Set<int> selectedIds = {};
  String? categoryFilter;

  bool isLoading = true;
  String? errorMessage;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadClothes();
    // 保存ボタンの有効/無効を名前の入力に合わせて更新する
    nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> loadClothes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await clothingService.getAllClothing();
      if (!mounted) return;
      setState(() {
        clothes = result;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("コーデ作成用の服取得エラー: $e");
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> save() async {

    if (isSaving) return;

    final error = validateOutfitInput(nameController.text, selectedIds.length);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => isSaving = true);

    try {
      await outfitService.createOutfit(
        name: nameController.text.trim(),
        clothingIds: selectedIds.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("コーデを保存しました")));
      Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint("===== コーデ保存エラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("保存に失敗しました: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {

    final canSave = !isSaving &&
        validateOutfitInput(nameController.text, selectedIds.length) == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("コーデを作る"),
        actions: [
          TextButton(
            onPressed: canSave ? save : null,
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("保存"),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: nameController,
              enabled: !isSaving,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: "コーデの名前",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "選択中: ${selectedIds.length}着($minOutfitItems着以上)",
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
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
              onPressed: loadClothes,
              child: const Text("再読み込み"),
            ),
          ],
        ),
      );
    }

    if (clothes.isEmpty) {
      return const Center(child: Text("まだ服が登録されていません"));
    }

    // 実在するカテゴリだけをチップに出す(定義順)
    final categories = categoryOptions
        .where((cat) => clothes.any((c) => c.category == cat))
        .toList();
    final visible = filterByCategory(clothes, categoryFilter);

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text("すべて"),
                  selected: categoryFilter == null,
                  onSelected: (_) => setState(() => categoryFilter = null),
                ),
              ),
              for (final cat in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: categoryFilter == cat,
                    onSelected: (_) => setState(() => categoryFilter = cat),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: visible.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final clothing = visible[index];
              final id = clothing.id;
              final selected = id != null && selectedIds.contains(id);
              return GestureDetector(
                onTap: (id == null || isSaving)
                    ? null
                    : () => setState(() {
                          if (selected) {
                            selectedIds.remove(id);
                          } else {
                            selectedIds.add(id);
                          }
                        }),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ClothingThumbnail(imagePath: clothing.imagePath),
                    ),
                    if (selected)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black26,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                    if (selected)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 12,
                          child: Icon(Icons.check, size: 16),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
