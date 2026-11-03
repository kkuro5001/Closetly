import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../models/outfit.dart';
import '../services/clothing_service.dart';
import '../services/outfit_service.dart';
import '../utils/outfit_utils.dart';
import '../widgets/clothing_thumbnail.dart';
import 'outfit_detail_page.dart';
import 'outfit_editor_page.dart';
import 'outfit_suggest_page.dart';

// コーデ一覧
class OutfitsPage extends StatefulWidget {
  const OutfitsPage({super.key});

  @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> {

  final outfitService = OutfitService();
  final clothingService = ClothingService();

  List<Outfit> outfits = [];
  List<Clothing> clothes = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    load();
  }

  // コーデと服を両方読み込む(サムネイルに服の画像パスが要るため)
  Future<void> load() async {

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        outfitService.getAllOutfits(),
        clothingService.getAllClothing(),
      ]);
      if (!mounted) return;
      setState(() {
        outfits = results[0] as List<Outfit>;
        clothes = results[1] as List<Clothing>;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint("===== コーデ取得エラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _open(Widget page) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (changed == true) load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("コーデ"),
        actions: [
          IconButton(
            tooltip: "AIにコーデを提案してもらう",
            onPressed: () => _open(const OutfitSuggestPage()),
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "コーデを作る",
        onPressed: () => _open(const OutfitEditorPage()),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text("コーデの取得に失敗しました\n$errorMessage",
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: load,
                child: const Text("再読み込み"),
              ),
            ],
          ),
        ),
      );
    }

    // 空でも引っ張って更新できるよう ListView で包む
    if (outfits.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.style, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text("まだコーデがありません")),
            SizedBox(height: 4),
            Center(
              child: Text(
                "右下の＋で作るか、右上のAIボタンで提案してもらえます",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: outfits.length,
        itemBuilder: (context, index) => _buildCard(outfits[index]),
      ),
    );
  }

  Widget _buildCard(Outfit outfit) {

    final items = resolveOutfitClothes(outfit, clothes);

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _open(OutfitDetailPage(outfit: outfit)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                outfit.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Text("服が残っていません",
                    style: TextStyle(color: Colors.grey))
              else
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ClothingThumbnail(
                        imagePath: items[i].imagePath,
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
