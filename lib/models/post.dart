
import 'package:personal_blog/models/user.dart';

class Post {
  final int? id;
  final int userId;
  final String title;
  final String contentMarkdown;
  final String contentHtml;
  final String slug;
  final bool published;
  final DateTime createdAt;
  final DateTime updatedAt;
  User? author; // Optional: to be populated when fetching posts with author info

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
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'],
      contentMarkdown: map['content_markdown'],
      contentHtml: map['content_html'],
      slug: map['slug'],
      published: map['published'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      author: map.containsKey('author_id') ? User.fromMap(map) : null, // Assuming author details are flattened in the map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content_markdown': contentMarkdown,
      'content_html': contentHtml,
      'slug': slug,
      'published': published,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

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
    );
  }
}