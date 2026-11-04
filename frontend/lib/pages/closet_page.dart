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

  static const _sortLabels = {
    ClosetSort.newest: "新しい順",
    ClosetSort.oldest: "古い順",
    ClosetSort.category: "カテゴリ順",
  };

  void _updateFilter(ClosetFilter next) {
    setState(() {
      filter = next;
    });
  }

  // 絞り込みボタン・並び順・件数を1行にまとめ、選択中の条件は下に×付きチップで表示する
  Widget _buildFilterBar(int visibleCount) {
    final scheme = Theme.of(context).colorScheme;
    final activeCount = filter.activeFilterCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Badge(
                isLabelVisible: activeCount > 0,
                label: Text("$activeCount"),
                child: OutlinedButton.icon(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune),
                  label: const Text("絞り込み"),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ClosetSort>(
                tooltip: "並び順",
                initialValue: filter.sort,
                onSelected: (value) =>
                    _updateFilter(filter.copyWith(sort: value)),
                itemBuilder: (context) => [
                  for (final entry in _sortLabels.entries)
                    CheckedPopupMenuItem(
                      value: entry.key,
                      checked: filter.sort == entry.key,
                      child: Text(entry.value),
                    ),
                ],
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 20, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        _sortLabels[filter.sort]!,
                        style: TextStyle(color: scheme.primary),
                      ),
                      Icon(Icons.arrow_drop_down, color: scheme.primary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                filter.hasActiveFilter
                    ? "$visibleCount / ${clothes.length}着"
                    : "${clothes.length}着",
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (filter.hasActiveFilter)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final v in filter.categories)
                    _activeChip(v, () => _updateFilter(filter.copyWith(
                          categories: _toggle(filter.categories, v, false),
                        ))),
                  for (final v in filter.seasons)
                    _activeChip(v, () => _updateFilter(filter.copyWith(
                          seasons: _toggle(filter.seasons, v, false),
                        ))),
                  for (final v in filter.colors)
                    _activeChip(v, () => _updateFilter(filter.copyWith(
                          colors: _toggle(filter.colors, v, false),
                        ))),
                  TextButton(
                    onPressed: () => _updateFilter(filter.clearFilters()),
                    child: const Text("すべて解除"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 選択中の条件。×で個別に外せる
  Widget _activeChip(String label, VoidCallback onDeleted) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteButtonTooltipMessage: "「$label」を外す",
      visualDensity: VisualDensity.compact,
    );
  }

  // 絞り込み条件を選ぶボトムシート。
  // 選んだ瞬間に後ろの一覧にも反映する(「適用」を押し忘れて条件が消えることがないように)
  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void change(ClosetFilter next) {
              _updateFilter(next);
              setSheetState(() {});
            }

            final visibleCount = filter.apply(clothes).length;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            "絞り込み",
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: filter.hasActiveFilter
                                ? () => change(filter.clearFilters())
                                : null,
                            child: const Text("すべて解除"),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetSection(
                              "種類",
                              availableCategories(clothes),
                              filter.categories,
                              (v, sel) => change(filter.copyWith(
                                categories: _toggle(filter.categories, v, sel),
                              )),
                            ),
                            _sheetSection(
                              "季節",
                              availableSeasons(clothes),
                              filter.seasons,
                              (v, sel) => change(filter.copyWith(
                                seasons: _toggle(filter.seasons, v, sel),
                              )),
                            ),
                            _sheetSection(
                              "色",
                              availableColors(clothes),
                              filter.colors,
                              (v, sel) => change(filter.copyWith(
                                colors: _toggle(filter.colors, v, sel),
                              )),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text("$visibleCount着を表示"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ボトムシート内の1項目。折り返し表示なので横スクロール不要(Webのマウス操作でも全部見える)
  Widget _sheetSection(
    String label,
    List<String> options,
    Set<String> selected,
    void Function(String value, bool selected) onChanged,
  ) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected.isEmpty ? label : "$label(${selected.length})",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (value) => onChanged(option, value),
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
        _buildFilterBar(visible.length),
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