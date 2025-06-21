
import 'package:personal_blog/models/comment.dart';
import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/utils/db_utils.dart';

class CommentService {
  Future<List<Comment>> getCommentsForPost(int postId) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT c.*, u.username as author_username, u.email as author_email, u.role as author_role FROM comments c JOIN users u ON c.user_id = u.id WHERE c.post_id = @post_id ORDER BY c.created_at DESC',
      parameters: {'post_id': postId},
    );

    return result.map((row) {
      final commentMap = row.toColumnMap();
      final authorMap = {
        'id': commentMap['user_id'],
        'username': commentMap['author_username'],
        'email': commentMap['author_email'],
        'role': commentMap['author_role'],
        'created_at': commentMap['created_at'],
        'updated_at': commentMap['updated_at'],
      };
      final comment = Comment.fromMap(commentMap);
      comment.author = User.fromMap(authorMap);
      return comment;
    }).toList();
  }

  Future<Comment> addComment(int postId, int userId, String content) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'INSERT INTO comments (post_id, user_id, content, created_at) VALUES (@post_id, @user_id, @content, @created_at) RETURNING *',
      parameters: {
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'created_at': DateTime.now(),
      },
    );
    return Comment.fromMap(result.first.toColumnMap());
  }

  Future<void> deleteComment(int commentId) async {
    final conn = await DatabaseConnection.connection;
    await conn.execute('DELETE FROM comments WHERE id = @id', parameters: {'id': commentId});
  }
}