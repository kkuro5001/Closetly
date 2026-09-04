class Clothing {

  final int? id;
  final String imagePath;
  final String category;
  final String color;
  final String season;

  Clothing({
    this.id,
    required this.imagePath,
    required this.category,
    required this.color,
    required this.season,
  });

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
    );
  }
}
