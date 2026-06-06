import 'package:personal_blog/models/comment.dart';
import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/utils/db_utils.dart';

/// Provides comment persistence for blog posts.
class CommentService {
  /// Returns comments for a post, newest first.
  Future<List<Comment>> getCommentsForPost(int postId) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('''
SELECT
  c.*,
  u.username AS author_username,
  u.email AS author_email,
  u.role AS author_role,
  u.created_at AS author_created_at,
  u.updated_at AS author_updated_at
FROM comments c
JOIN users u ON c.user_id = u.id
WHERE c.post_id = @post_id
ORDER BY c.created_at DESC
'''),
      parameters: {'post_id': postId},
    );

    return result.map((row) => _hydrateComment(row.toColumnMap())).toList();
  }

  /// Adds a comment to a post.
  Future<Comment> addComment(int postId, int userId, String content) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('''
INSERT INTO comments (post_id, user_id, content, created_at)
VALUES (@post_id, @user_id, @content, @created_at)
RETURNING *
'''),
      parameters: {
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'created_at': DateTime.now().toUtc(),
      },
    );
    return Comment.fromMap(result.first.toColumnMap());
  }

  /// Deletes a comment.
  Future<void> deleteComment(int commentId) async {
    final conn = await DatabaseConnection.connection;
    await conn.execute(
      Sql.named('DELETE FROM comments WHERE id = @id'),
      parameters: {'id': commentId},
    );
  }

  Comment _hydrateComment(Map<String, dynamic> commentMap) {
    final comment = Comment.fromMap(commentMap);
    final author = User.fromMap({
      'id': comment.userId,
      'username': commentMap['author_username'],
      'email': commentMap['author_email'],
      'password_hash': '',
      'role': commentMap['author_role'],
      'created_at': commentMap['author_created_at'] ?? comment.createdAt,
      'updated_at': commentMap['author_updated_at'] ?? comment.createdAt,
    });
    return comment.copyWith(author: author);
  }
}
