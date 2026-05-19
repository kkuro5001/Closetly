class Clothing {

  final int? id;
  final String imagePath;
  final String category;
  final String color;
  final String memo;

  Clothing({
    this.id,
    required this.imagePath,
    required this.category,
    required this.color,
    required this.memo,
  });

  // DB保存用
  Map<String, dynamic> toMap() {

    return {
      'id': id,
      'imagePath': imagePath,
      'category': category,
      'color': color,
      'memo': memo,
    };
  }

  // DB取得用
  factory Clothing.fromMap(
    Map<String, dynamic> map,
  ) {

    return Clothing(
      id: map['id'],
      imagePath: map['imagePath'],
      category: map['category'],
      color: map['color'],
      memo: map['memo'],
    );
  }
}