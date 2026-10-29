import 'package:flutter/material.dart';

import '../models/clothing.dart';
import '../utils/closet_filter.dart';
import '../services/clothing_service.dart';
import '../services/storage_service.dart';
import 'clothing_detail_page.dart';

class ClosetPage extends StatefulWidget {
  const ClosetPage({super.key});

  @override
  State<ClosetPage> createState() =>
      _ClosetPageState();
}

class _ClosetPageState
    extends State<ClosetPage> {

  List<Clothing> clothes = [];
  final storageService = StorageService();
  final clothingService = ClothingService();

  // 絞り込み・並び替え条件(詳細ページから戻っても State が残るので保持される)
  ClosetFilter filter = const ClosetFilter();

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

      setState(() {
        clothes = result;
        filter = _pruneFilter(filter, result);
        isLoading = false;
      });

    } catch (e, stackTrace) {

      debugPrint("===== クローゼット取得エラー =====");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // 削除などで存在しなくなった値が選択されたままにならないよう取り除く
  ClosetFilter _pruneFilter(ClosetFilter f, List<Clothing> items) {
    final cats = availableCategories(items).toSet();
    final seasons = availableSeasons(items).toSet();
    final colors = availableColors(items).toSet();
    final pruned = f.copyWith(
      categories: f.categories.intersection(cats),
      seasons: f.seasons.intersection(seasons),
      colors: f.colors.intersection(colors),
    );
    debugPrint(
      "絞り込み条件を更新: カテゴリ=${pruned.categories} 季節=${pruned.seasons} 色=${pruned.colors} 並び=${pruned.sort}",
    );
    return pruned;
  }

  // 選択肢の追加/削除(複数選択)
  Set<String> _toggle(Set<String> current, String value, bool selected) {
    final next = {...current};
    if (selected) {
      next.add(value);
    } else {
      next.remove(value);
    }
    return next;
  }

  Widget _buildChipRow(
    String label,
    List<String> options,
    Set<String> selected,
    void Function(String value, bool selected) onChanged,
  ) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(option),
                        selected: selected.contains(option),
                        onSelected: (value) => onChanged(option, value),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          _buildChipRow(
            "種類",
            availableCategories(clothes),
            filter.categories,
            (v, sel) => setState(() {
              filter = filter.copyWith(
                categories: _toggle(filter.categories, v, sel),
              );
            }),
          ),
          _buildChipRow(
            "季節",
            availableSeasons(clothes),
            filter.seasons,
            (v, sel) => setState(() {
              filter = filter.copyWith(
                seasons: _toggle(filter.seasons, v, sel),
              );
            }),
          ),
          _buildChipRow(
            "色",
            availableColors(clothes),
            filter.colors,
            (v, sel) => setState(() {
              filter = filter.copyWith(
                colors: _toggle(filter.colors, v, sel),
              );
            }),
          ),
          Row(
            children: [
              const Text("並び順", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              DropdownButton<ClosetSort>(
                value: filter.sort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: ClosetSort.newest,
                    child: Text("新しい順"),
                  ),
                  DropdownMenuItem(
                    value: ClosetSort.oldest,
                    child: Text("古い順"),
                  ),
                  DropdownMenuItem(
                    value: ClosetSort.category,
                    child: Text("カテゴリ順"),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    filter = filter.copyWith(sort: value);
                  });
                },
              ),
              const Spacer(),
              if (filter.hasActiveFilter)
                TextButton(
                  onPressed: () => setState(() {
                    filter = filter.clearFilters();
                  }),
                  child: const Text("絞り込みを解除"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("クローゼット"),
        actions: [
          IconButton(
            onPressed: loadClothes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: _buildBody(),
    );
  }

  Widget _buildBody() {

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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

    if (clothes.isEmpty) {
      return const Center(
        child: Text("まだ服が登録されていません"),
      );
    }

    final visible = filter.apply(clothes);

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: visible.isEmpty
              ? _buildNoMatch()
              : _buildGrid(visible),
        ),
      ],
    );
  }

  // 条件に合う服が0件のときの表示(服が1着もない場合とは別)
  Widget _buildNoMatch() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text("条件に合う服がありません"),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(() {
              filter = filter.clearFilters();
            }),
            child: const Text("絞り込みを解除"),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Clothing> visible) {

    return RefreshIndicator(
      onRefresh: loadClothes,
      child: GridView.builder(

        padding:
            const EdgeInsets.all(12),

        itemCount: visible.length,

        gridDelegate:
            const SliverGridDelegateWithMaxCrossAxisExtent(

          // 1枚の最大幅。スマホ幅では2列、Webでは画面幅に応じて列が増える
          maxCrossAxisExtent: 200,

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

          childAspectRatio: 0.7,
        ),

        itemBuilder: (context, index) {

          final clothing =
              visible[index];

          return GestureDetector(

            onTap: () async {

              final deleted = await Navigator.push(

                context,

                MaterialPageRoute(

                  builder: (context) =>
                      ClothingDetailPage(
                    clothing: clothing,
                  ),
                ),
              );

              if (deleted == true) {
                loadClothes();
              }
            },

            child: Card(

              elevation: 3,

              clipBehavior:
                  Clip.antiAlias,

              child: Column(

                children: [

                  Expanded(
                    child: FutureBuilder<String>(
                      future: storageService.getSignedUrl(clothing.imagePath),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Center(
                            child: Icon(Icons.broken_image),
                          );
                        }

                        return Image.network(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  Padding(

                    padding:
                        const EdgeInsets.all(
                      8,
                    ),

                    child: Column(

                      children: [

                        // カテゴリ
                        Text(

                          clothing.category,

                          style:
                              const TextStyle(

                            fontWeight:
                                FontWeight.bold,

                            fontSize: 16,
                          ),

                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        // 季節
                        Text(

                          clothing.season,

                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}