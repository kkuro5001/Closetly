// コーディネート(Supabase の outfits + outfit_items)
class Outfit {

  final int? id;
  final String name;

  // AIの提案理由など(手動作成では空)
  final String note;

  // コーデに含まれる服の id(服が削除されると DB 側で自動的に外れる)
  final List<int> clothingIds;

  final DateTime? createdAt;

  Outfit({
    this.id,
    required this.name,
    this.note = '',
    required this.clothingIds,
    this.createdAt,
  });

  // outfits.select('id, name, note, created_at, outfit_items(clothing_id)') の1行から作る
  factory Outfit.fromMap(Map<String, dynamic> map) {
    final items = (map['outfit_items'] as List?) ?? const [];
    return Outfit(
      id: map['id'],
      name: map['name'],
      note: map['note'] ?? '',
      clothingIds: items
          .map((e) => (e as Map<String, dynamic>)['clothing_id'] as int)
          .toList(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at']),
    );
  }
}

// Go API (POST /suggest-outfit) が返すAIの提案1件(まだ保存していないもの)
class OutfitSuggestion {

  final String name;
  final List<int> clothingIds;
  final String reason;

  OutfitSuggestion({
    required this.name,
    required this.clothingIds,
    required this.reason,
  });

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) {
    return OutfitSuggestion(
      name: json['name'] ?? '',
      clothingIds: ((json['clothing_ids'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      reason: json['reason'] ?? '',
    );
  }
}
