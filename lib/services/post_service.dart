import 'package:markdown/markdown.dart' as md;
import 'package:personal_blog/models/post.dart';
import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/utils/db_utils.dart';

class PostService {
  Future<List<Post>> getAllPosts({bool publishedOnly = true}) async {
    final conn = await DatabaseConnection.connection;
    String query =
        'SELECT p.*, u.username as author_username, u.email as author_email, u.role as author_role FROM posts p JOIN users u ON p.user_id = u.id';
    if (publishedOnly) {
      query += ' WHERE p.published = TRUE';
    }
    query += ' ORDER BY p.created_at DESC';

    final result = await conn.execute(query);

    return result.map((row) {
      final postMap = row.toColumnMap();
      final authorMap = {
        'id': postMap['user_id'],
        'username': postMap['author_username'],
        'email': postMap['author_email'],
        'role': postMap['author_role'],
        'created_at': postMap['created_at'],
        'updated_at': postMap['updated_at'],
      };
      final post = Post.fromMap(postMap);
      post.author = User.fromMap(authorMap);
      return post;
    }).toList();
  }

  Future<Post?> getPostBySlug(String slug) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT p.*, u.username as author_username, u.email as author_email, u.role as author_role FROM posts p JOIN users u ON p.user_id = u.id WHERE p.slug = @slug',
      parameters: {'slug': slug},
    );

    if (result.isEmpty) {
      return null;
    }

    final postMap = result.first.toColumnMap();
    final authorMap = {
      'id': postMap['user_id'],
      'username': postMap['author_username'],
      'email': postMap['author_email'],
      'role': postMap['author_role'],
      'created_at': postMap['created_at'],
      'updated_at': postMap['updated_at'],
    };
    final post = Post.fromMap(postMap);
    post.author = User.fromMap(authorMap);
    return post;
  }

  Future<Post> createPost(
    int userId,
    String title,
    String contentMarkdown,
    String slug, {
    bool published = false,
  }) async {
    final conn = await DatabaseConnection.connection;
    final contentHtml = md.markdownToHtml(contentMarkdown);

    final result = await conn.execute(
      'INSERT INTO posts (user_id, title, content_markdown, content_html, slug, published, created_at, updated_at) VALUES (@user_id, @title, @content_markdown, @content_html, @slug, @published, @created_at, @updated_at) RETURNING *',
      parameters: {
        'user_id': userId,
        'title': title,
        'content_markdown': contentMarkdown,
        'content_html': contentHtml,
        'slug': slug,
        'published': published,
        'created_at': DateTime.now(),
        'updated_at': DateTime.now(),
      },
    );
    return Post.fromMap(result.first.toColumnMap());
  }

  Future<Post?> updatePost(
    int postId, {
    String? title,
    String? contentMarkdown,
    String? slug,
    bool? published,
  }) async {
    final conn = await DatabaseConnection.connection;
    final updates = <String, dynamic>{};
    String? contentHtml;

    if (title != null) updates['title'] = title;
    if (contentMarkdown != null) {
      updates['content_markdown'] = contentMarkdown;
      contentHtml = md.markdownToHtml(contentMarkdown);
      updates['content_html'] = contentHtml;
    }
    if (slug != null) updates['slug'] = slug;
    if (published != null) updates['published'] = published;

    if (updates.isEmpty) return await getPostById(postId);

    updates['updated_at'] = DateTime.now();

    final updateClauses = updates.keys.map((key) => '$key = @$key').join(', ');
    final result = await conn.execute(
      'UPDATE posts SET $updateClauses WHERE id = @id RETURNING *',
      parameters: {...updates, 'id': postId},
    );

    if (result.isEmpty) return null;
    return Post.fromMap(result.first.toColumnMap());
  }

  Future<void> deletePost(int postId) async {
    final conn = await DatabaseConnection.connection;
    await conn.execute(
      'DELETE FROM posts WHERE id = @id',
      parameters: {'id': postId},
    );
  }

  Future<Post?> getPostById(int postId) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT p.*, u.username as author_username, u.email as author_email, u.role as author_role FROM posts p JOIN users u ON p.user_id = u.id WHERE p.id = @id',
      parameters: {'id': postId},
    );

    if (result.isEmpty) {
      return null;
    }
    final postMap = result.first.toColumnMap();
    final authorMap = {
      'id': postMap['user_id'],
      'username': postMap['author_username'],
      'email': postMap['author_email'],
      'role': postMap['author_role'],
      'created_at': postMap['created_at'],
      'updated_at': postMap['updated_at'],
    };
    final post = Post.fromMap(postMap);
    post.author = User.fromMap(authorMap);
    return post;
  }
}
