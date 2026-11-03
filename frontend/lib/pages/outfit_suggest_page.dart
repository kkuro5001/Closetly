import 'package:flutter/material.dart';

import '../constants/clothing_options.dart';
import '../models/clothing.dart';
import '../models/outfit.dart';
import '../services/clothing_service.dart';
import '../services/outfit_service.dart';
import '../utils/wardrobe_stats.dart';
import '../widgets/clothing_thumbnail.dart';

// AIにコーデを提案してもらう画面。
// コーデ一覧画面からこのページを開き、1件以上保存したら true を返して pop する
// (一覧側は true なら再読み込みする)。コンストラクタは引数なしのまま変えないこと。
class OutfitSuggestPage extends StatefulWidget {
  const OutfitSuggestPage({super.key});

  @override
  State<OutfitSuggestPage> createState() => _OutfitSuggestPageState();
}

class _OutfitSuggestPageState extends State<OutfitSuggestPage> {

  static const _sceneMaxLength = 200;

  final _outfitService = OutfitService();
  final _clothingService = ClothingService();
  final _sceneController = TextEditingController();

  late String _season = seasonForMonth(DateTime.now().month);

  bool _loading = false;
  String? _error;
  List<OutfitSuggestion> _suggestions = [];

  // 提案に含まれる服の id から画像パスを引くための表
  Map<int, Clothing> _clothesById = {};

  // 提案を取り直したときに古い結果を捨てるための番号
  int _requestId = 0;

  // 保存済み・保存中のカード(提案リスト内の位置)
  final Set<int> _savedIndexes = {};
  final Set<int> _savingIndexes = {};

  @override
  void dispose() {
    _sceneController.dispose();
    super.dispose();
  }

  String _messageOf(Object e) {
    final text = e.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }

  Future<void> _suggest() async {

    if (_loading) return;

    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
      _savedIndexes.clear();
      _savingIndexes.clear();
    });

    try {
      final results = await Future.wait([
        _outfitService.suggestOutfits(
          scene: _sceneController.text.trim(),
          season: _season,
        ),
        _clothingService.getAllClothing(),
      ]);

      // 別のリクエストが走っていたら、この結果は捨てる
      if (!mounted || requestId != _requestId) return;

      final suggestions = results[0] as List<OutfitSuggestion>;
      final clothes = results[1] as List<Clothing>;
      setState(() {
        _suggestions = suggestions;
        _clothesById = {
          for (final c in clothes)
            if (c.id != null) c.id!: c,
        };
        _loading = false;
        if (suggestions.isEmpty) {
          _error = "提案を作れませんでした。もう一度試してください";
        }
      });
    } catch (e) {
      debugPrint("コーデ提案に失敗: $e");
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = e is Exception
            ? _messageOf(e)
            : "提案の取得に失敗しました";
      });
    }
  }

  Future<void> _save(int index) async {

    if (_savedIndexes.contains(index) || _savingIndexes.contains(index)) {
      return;
    }

    final suggestion = _suggestions[index];
    final requestId = _requestId;
    setState(() => _savingIndexes.add(index));

    try {
      await _outfitService.createOutfit(
        name: suggestion.name,
        note: suggestion.reason,
        clothingIds: suggestion.clothingIds,
      );
      if (!mounted) return;
      // 保存した事実は、提案が取り直されていても件数に数える
      _savedCount++;
      if (requestId == _requestId) {
        setState(() {
          _savingIndexes.remove(index);
          _savedIndexes.add(index);
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("コーデを保存しました")));
    } catch (e) {
      debugPrint("コーデの保存に失敗: $e");
      if (!mounted) return;
      if (requestId == _requestId) {
        setState(() => _savingIndexes.remove(index));
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("コーデの保存に失敗しました")));
    }
  }

  int _savedCount = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_savedCount > 0);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("AIにコーデを提案してもらう")),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _sceneController,
              maxLength: _sceneMaxLength,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: "場面(任意)",
                hintText: "例: 友達と食事、通勤、デート",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _season,
              decoration: const InputDecoration(
                labelText: "季節",
                border: OutlineInputBorder(),
              ),
              items: seasonOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null) setState(() => _season = value);
                    },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _suggest,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_suggestions.isEmpty && _error == null
                  ? "提案してもらう"
                  : "もう一度提案してもらう"),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("提案を考えています。数十秒かかることがあります"),
                ],
              ),
            if (_error != null && !_loading)
              Column(
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(onPressed: _suggest, child: const Text("再試行")),
                ],
              ),
            for (var i = 0; i < _suggestions.length; i++) _buildCard(i),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(int index) {

    final suggestion = _suggestions[index];
    final saved = _savedIndexes.contains(index);
    final saving = _savingIndexes.contains(index);
    final clothes = suggestion.clothingIds
        .map((id) => _clothesById[id])
        .whereType<Clothing>()
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in clothes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ClothingThumbnail(
                          imagePath: c.imagePath,
                          width: 96,
                          height: 96,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (suggestion.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(suggestion.reason),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: (saved || saving) ? null : () => _save(index),
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
                label: Text(saved ? "保存済み" : "このコーデを保存"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
