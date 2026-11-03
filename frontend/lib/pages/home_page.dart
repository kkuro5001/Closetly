import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../models/wear_log.dart';
import '../services/clothing_service.dart';
import '../services/storage_service.dart';
import '../services/wear_log_service.dart';
import '../utils/wardrobe_stats.dart';
import '../utils/wear_stats.dart';
import 'clothing_detail_page.dart';

// ホーム画面: 登録数・カテゴリ別/色別の件数・今の季節の服を表示する
//
// MainPage は pages[currentIndex] で1ページだけ build するため、
// タブを切り替えるたびに HomePage が作り直され initState で再取得される。
// カメラタブで服を追加してからホームに戻ると最新になる。加えて引っ張って更新にも対応。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final clothingService = ClothingService();
  final storageService = StorageService();
  final wearLogService = WearLogService();

  List<Clothing> clothes = [];
  // 着用記録は服とは別に読む。失敗しても他のカードは表示し、着用カードだけエラーにする
  List<WearLog> wearLogs = [];
  String? wearError;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadClothes();
  }

  Future<void> loadClothes() async {

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {

      final result = await clothingService.getAllClothing();
      debugPrint("===== ホーム: 服を${result.length}件取得 =====");

      List<WearLog> logs = [];
      String? wearErr;
      try {
        logs = await wearLogService.getAllWearLogs();
      } catch (e) {
        debugPrint("ホーム: 着用記録の取得に失敗: $e");
        wearErr = e.toString();
      }

      if (!mounted) return;
      setState(() {
        clothes = result;
        wearLogs = logs;
        wearError = wearErr;
        isLoading = false;
      });

    } catch (e, stackTrace) {

      debugPrint("===== ホーム取得エラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ホーム"),
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
              Text("服の取得に失敗しました\n$errorMessage", textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: loadClothes,
                child: const Text("再読み込み"),
              ),
            ],
          ),
        ),
      );
    }

    // 空のときも引っ張って更新できるよう ListView で包む
    if (clothes.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadClothes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.checkroom, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text("まだ服が登録されていません")),
            SizedBox(height: 4),
            Center(
              child: Text(
                "カメラタブから服を登録してみましょう",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final season = seasonForMonth(DateTime.now().month);
    final seasonal = clothesForSeason(clothes, season);

    return RefreshIndicator(
      onRefresh: loadClothes,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTotalCard(),
          const SizedBox(height: 16),
          _buildBreakdown("カテゴリ別", countByCategory(clothes)),
          const SizedBox(height: 16),
          _buildBreakdown("色別", countByColor(clothes)),
          const SizedBox(height: 16),
          _buildSeasonal(season, seasonal),
          const SizedBox(height: 16),
          _buildStale(),
          const SizedBox(height: 16),
          _buildFrequent(),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.checkroom, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("登録した服"),
                Text(
                  "${clothes.length} 着",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 件数に比例した横棒で表示する(チャートパッケージは使わない)
  Widget _buildBreakdown(String title, List<CountEntry> entries) {

    final maxCount = entries.isEmpty ? 1 : entries.first.count;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(e.name, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.count / maxCount,
                          minHeight: 12,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text("${e.count}", textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonal(String season, List<Clothing> seasonal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "今の季節の服($season + オールシーズン)",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "6〜8月は夏、12〜2月は冬、それ以外は春秋として判定",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (seasonal.isEmpty)
              const Text("該当する服がありません")
            else
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: seasonal.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) =>
                      _buildThumbnail(seasonal[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 着用カード共通の枠(タイトル + 本文)
  Widget _wearCard(String title, String note, Widget body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }

  Widget _wearErrorBody() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            "着用記録を読み込めませんでした",
            style: TextStyle(color: Colors.grey),
          ),
        ),
        TextButton(onPressed: loadClothes, child: const Text("再読み込み")),
      ],
    );
  }

  // 横スクロールのサムネイル列。labelFor が文字列を返せば画像の下に表示する
  Widget _thumbnailRow<T>(
    List<T> items,
    Clothing Function(T) clothingOf,
    String Function(T) labelOf,
  ) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 100,
            child: Column(
              children: [
                Expanded(child: _buildThumbnail(clothingOf(item))),
                const SizedBox(height: 4),
                Text(
                  labelOf(item),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStale() {

    const title = "しばらく着ていない服(30日以上)";
    const note = "最後に着た日(未着用は登録日)から30日以上経った服";

    if (wearError != null) {
      return _wearCard(title, note, _wearErrorBody());
    }

    final stale = staleClothes(clothes, wearLogs, DateTime.now());

    return _wearCard(
      title,
      note,
      stale.isEmpty
          ? const Text("該当する服がありません")
          : _thumbnailRow<StaleEntry>(
              stale,
              (e) => e.clothing,
              (e) => e.days == null ? "記録なし" : "${e.days}日前",
            ),
    );
  }

  Widget _buildFrequent() {

    const title = "よく着る服";
    const note = "着た回数が多い順(上位5着)";

    if (wearError != null) {
      return _wearCard(title, note, _wearErrorBody());
    }

    final frequent = frequentClothes(clothes, wearLogs);

    return _wearCard(
      title,
      note,
      frequent.isEmpty
          ? const Text("まだ着用の記録がありません")
          : _thumbnailRow<FrequentEntry>(
              frequent,
              (e) => e.clothing,
              (e) => "${e.count}回",
            ),
    );
  }

  Widget _buildThumbnail(Clothing clothing) {
    return GestureDetector(
      onTap: () async {
        final deleted = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClothingDetailPage(clothing: clothing),
          ),
        );
        // 詳細画面で削除・編集・着用記録をしたら再取得する
        if (deleted == true) {
          loadClothes();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 100,
          child: FutureBuilder<String>(
            future: storageService.getSignedUrl(clothing.imagePath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Icon(Icons.broken_image));
              }
              return Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.broken_image));
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
