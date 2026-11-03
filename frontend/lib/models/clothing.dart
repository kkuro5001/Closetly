class Clothing {

  final int? id;
  final String imagePath;
  final String category;
  final String color;
  final String season;
  final DateTime? createdAt;

  Clothing({
    this.id,
    required this.imagePath,
    required this.category,
    required this.color,
    required this.season,
    this.createdAt,
  });

  // 一部の項目だけ差し替えた新しいインスタンスを返す(画像パス・idなどは引き継ぐ)
  Clothing copyWith({
    String? category,
    String? color,
    String? season,
  }) {
    return Clothing(
      id: id,
      imagePath: imagePath,
      category: category ?? this.category,
      color: color ?? this.color,
      season: season ?? this.season,
      createdAt: createdAt,
    );
  }

  // Supabase保存用
  Map<String, dynamic> toMap() {

    return {
      'image_path': imagePath,
      'category': category,
      'color': color,
      'season': season,
    };
  }

  // Supabase取得用
  factory Clothing.fromMap(
    Map<String, dynamic> map,
  ) {

    return Clothing(
      id: map['id'],
      imagePath: map['image_path'],
      category: map['category'],
      color: map['color'],
      season: map['season'],
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at']),
    );
  }
}
