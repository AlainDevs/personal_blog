import 'package:personal_blog/models/user.dart';

/// A reader response attached to a blog post.
class Comment {
  /// Creates a comment value.
  Comment({
    this.id,
    required this.postId,
    required this.userId,
    required this.content,
    DateTime? createdAt,
    this.author,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Builds a comment from a PostgreSQL row map.
  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: _readNullableInt(map['id']),
      postId: _readInt(map['post_id']),
      userId: _readInt(map['user_id']),
      content: (map['content'] ?? '').toString(),
      createdAt: _readDateTime(map['created_at']),
    );
  }

  /// Database identifier.
  final int? id;

  /// Related post identifier.
  final int postId;

  /// Author user identifier.
  final int userId;

  /// Comment body.
  final String content;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Optional author details.
  final User? author;

  /// Converts this comment to a template and JSON friendly map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'postId': postId,
      'user_id': userId,
      'userId': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'createdAt': _formatDate(createdAt),
      'author': author?.toPublicMap(),
    };
  }

  /// Returns a copy with selected fields changed.
  Comment copyWith({
    int? id,
    int? postId,
    int? userId,
    String? content,
    DateTime? createdAt,
    User? author,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
