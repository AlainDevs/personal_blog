/// A label used to group related blog posts.
class Category {
  /// Creates a category value.
  const Category({this.id, required this.name, required this.slug});

  /// Builds a category from a PostgreSQL row map.
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: _readNullableInt(map['id']),
      name: (map['name'] ?? '').toString(),
      slug: (map['slug'] ?? '').toString(),
    );
  }

  /// Database identifier.
  final int? id;

  /// Display name.
  final String name;

  /// URL-safe identifier.
  final String slug;

  /// Converts this category to a template and JSON friendly map.
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'slug': slug};
  }

  /// Returns a copy with selected fields changed.
  Category copyWith({int? id, String? name, String? slug}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
    );
  }
}

int? _readNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
