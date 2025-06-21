class Category {
  final int? id;
  final String name;
  final String slug;

  Category({
    this.id,
    required this.name,
    required this.slug,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      slug: map['slug'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? slug,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
    );
  }
}