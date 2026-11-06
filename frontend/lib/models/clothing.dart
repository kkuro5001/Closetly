class Clothing {

  final int? id;
  final String imagePath;
  final String category;
  final String color;
  final String season;
  // サイズは任意項目。未設定(既存データ含む)は null
  final String? size;
  final DateTime? createdAt;

  Clothing({
    this.id,
    required this.imagePath,
    required this.category,
    required this.color,
    required this.season,
    this.size,
    this.createdAt,
  });

  // copyWith で「サイズを null に戻す」と「サイズを指定しない」を区別するための目印
  static const _unset = Object();

  // 一部の項目だけ差し替えた新しいインスタンスを返す(画像パス・idなどは引き継ぐ)。
  // size は null を渡すと未設定に戻る(省略時は元の値を引き継ぐ)
  Clothing copyWith({
    String? category,
    String? color,
    String? season,
    Object? size = _unset,
  }) {
    return Clothing(
      id: id,
      imagePath: imagePath,
      category: category ?? this.category,
      color: color ?? this.color,
      season: season ?? this.season,
      size: identical(size, _unset) ? this.size : size as String?,
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
      // 未設定のときは送らない(列のデフォルト null になる)
      if (size != null) 'size': size,
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
      size: map['size'],
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at']),
    );
  }
}
