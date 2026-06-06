import 'dart:math' as math;

import 'package:personal_blog/models/category.dart';
import 'package:personal_blog/models/user.dart';

/// A published or draft blog article.
class Post {
  /// Creates a post value.
  Post({
    this.id,
    required this.userId,
    required this.title,
    required this.contentMarkdown,
    required this.contentHtml,
    required this.slug,
    this.published = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.author,
    this.categories = const [],
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Builds a post from a PostgreSQL row map.
  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: _readNullableInt(map['id']),
      userId: _readInt(map['user_id']),
      title: (map['title'] ?? '').toString(),
      contentMarkdown: (map['content_markdown'] ?? '').toString(),
      contentHtml: (map['content_html'] ?? '').toString(),
      slug: (map['slug'] ?? '').toString(),
      published: _readBool(map['published']),
      createdAt: _readDateTime(map['created_at']),
      updatedAt: _readDateTime(map['updated_at']),
    );
  }

  /// Database identifier.
  final int? id;

  /// Author user identifier.
  final int userId;

  /// Article headline.
  final String title;

  /// Markdown source content.
  final String contentMarkdown;

  /// Rendered HTML content.
  final String contentHtml;

  /// URL-safe identifier.
  final String slug;

  /// Whether the article is visible publicly.
  final bool published;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

  /// Optional author details.
  final User? author;

  /// Categories assigned to the post.
  final List<Category> categories;

  /// Plain text summary for cards.
  String get excerpt {
    final plainText =
        contentMarkdown
            .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
            .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) {
              return match.group(1) ?? '';
            })
            .replaceAll(RegExp(r'[#*_`>\-]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    if (plainText.length <= 170) {
      return plainText;
    }
    return '${plainText.substring(0, 170).trim()}…';
  }

  /// Estimated reading time in minutes.
  int get readingMinutes {
    final words =
        contentMarkdown
            .split(RegExp(r'\s+'))
            .where((word) => word.trim().isNotEmpty)
            .length;
    return math.max(1, (words / 220).ceil());
  }

  /// Converts this post to a template and JSON friendly map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'userId': userId,
      'title': title,
      'content_markdown': contentMarkdown,
      'contentMarkdown': contentMarkdown,
      'content_html': contentHtml,
      'contentHtml': contentHtml,
      'slug': slug,
      'published': published,
      'created_at': createdAt.toIso8601String(),
      'createdAt': _formatDate(createdAt),
      'updated_at': updatedAt.toIso8601String(),
      'updatedAt': _formatDate(updatedAt),
      'author': author?.toPublicMap(),
      'categories': categories.map((category) => category.toMap()).toList(),
      'hasCategories': categories.isNotEmpty,
      'excerpt': excerpt,
      'readingMinutes': readingMinutes,
    };
  }

  /// Returns a copy with selected fields changed.
  Post copyWith({
    int? id,
    int? userId,
    String? title,
    String? contentMarkdown,
    String? contentHtml,
    String? slug,
    bool? published,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? author,
    List<Category>? categories,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      contentMarkdown: contentMarkdown ?? this.contentMarkdown,
      contentHtml: contentHtml ?? this.contentHtml,
      slug: slug ?? this.slug,
      published: published ?? this.published,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author ?? this.author,
      categories: categories ?? this.categories,
    );
  }
}

DateTime _readDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

int _readInt(Object? value) {
  return _readNullableInt(value) ?? 0;
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

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
