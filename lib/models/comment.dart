import 'package:personal_blog/models/user.dart';

class Comment {
  final int? id;
  final int postId;
  final int userId;
  final String content;
  final DateTime createdAt;
  User?
  author; // Optional: to be populated when fetching comments with author info

  Comment({
    this.id,
    required this.postId,
    required this.userId,
    required this.content,
    DateTime? createdAt,
    this.author,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      postId: map['post_id'],
      userId: map['user_id'],
      content: map['content'],
      createdAt: map['created_at'],
      author:
          map.containsKey('author_id')
              ? User.fromMap(map)
              : null, // Assuming author details are flattened in the map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt,
    };
  }

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
