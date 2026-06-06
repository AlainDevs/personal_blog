import 'package:markdown/markdown.dart' as markdown;
import 'package:personal_blog/models/category.dart';
import 'package:personal_blog/models/post.dart';
import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/utils/db_utils.dart';

/// Provides blog post persistence and markdown rendering.
class PostService {
  /// Returns posts, optionally limited to published posts.
  Future<List<Post>> getAllPosts({bool publishedOnly = true}) async {
    final conn = await DatabaseConnection.connection;
    var query = '''
SELECT
  p.*,
  u.username AS author_username,
  u.email AS author_email,
  u.role AS author_role,
  u.created_at AS author_created_at,
  u.updated_at AS author_updated_at
FROM posts p
JOIN users u ON p.user_id = u.id
''';

    if (publishedOnly) {
      query += ' WHERE p.published = TRUE';
    }
    query += ' ORDER BY p.created_at DESC';

    final result = await conn.execute(query);
    final posts = <Post>[];
    for (final row in result) {
      posts.add(await _hydratePost(row.toColumnMap()));
    }
    return posts;
  }

  /// Finds a post by slug.
  Future<Post?> getPostBySlug(String slug) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('''
SELECT
  p.*,
  u.username AS author_username,
  u.email AS author_email,
  u.role AS author_role,
  u.created_at AS author_created_at,
  u.updated_at AS author_updated_at
FROM posts p
JOIN users u ON p.user_id = u.id
WHERE p.slug = @slug
'''),
      parameters: {'slug': slug},
    );

    if (result.isEmpty) {
      return null;
    }
    return _hydratePost(result.first.toColumnMap());
  }

  /// Finds a post by database id.
  Future<Post?> getPostById(int postId) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('''
SELECT
  p.*,
  u.username AS author_username,
  u.email AS author_email,
  u.role AS author_role,
  u.created_at AS author_created_at,
  u.updated_at AS author_updated_at
FROM posts p
JOIN users u ON p.user_id = u.id
WHERE p.id = @id
'''),
      parameters: {'id': postId},
    );

    if (result.isEmpty) {
      return null;
    }
    return _hydratePost(result.first.toColumnMap());
  }

  /// Creates a post.
  Future<Post> createPost(
    int userId,
    String title,
    String contentMarkdown,
    String slug, {
    bool published = false,
  }) async {
    final conn = await DatabaseConnection.connection;
    final contentHtml = markdown.markdownToHtml(contentMarkdown);
    final now = DateTime.now().toUtc();

    final result = await conn.execute(
      Sql.named('''
INSERT INTO posts (
  user_id,
  title,
  content_markdown,
  content_html,
  slug,
  published,
  created_at,
  updated_at
)
VALUES (
  @user_id,
  @title,
  @content_markdown,
  @content_html,
  @slug,
  @published,
  @created_at,
  @updated_at
)
RETURNING id
'''),
      parameters: {
        'user_id': userId,
        'title': title,
        'content_markdown': contentMarkdown,
        'content_html': contentHtml,
        'slug': slug,
        'published': published,
        'created_at': now,
        'updated_at': now,
      },
    );

    final createdPostId = result.first.toColumnMap()['id'] as int;
    final post = await getPostById(createdPostId);
    if (post == null) {
      throw StateError('Created post could not be loaded.');
    }
    return post;
  }

  /// Updates a post.
  Future<Post?> updatePost(
    int postId, {
    String? title,
    String? contentMarkdown,
    String? slug,
    bool? published,
  }) async {
    final conn = await DatabaseConnection.connection;
    final updates = <String, dynamic>{};

    if (title != null) {
      updates['title'] = title;
    }
    if (contentMarkdown != null) {
      updates['content_markdown'] = contentMarkdown;
      updates['content_html'] = markdown.markdownToHtml(contentMarkdown);
    }
    if (slug != null) {
      updates['slug'] = slug;
    }
    if (published != null) {
      updates['published'] = published;
    }

    if (updates.isEmpty) {
      return getPostById(postId);
    }

    updates['updated_at'] = DateTime.now().toUtc();
    final updateClauses = updates.keys.map((key) => '$key = @$key').join(', ');
    final result = await conn.execute(
      Sql.named('UPDATE posts SET $updateClauses WHERE id = @id RETURNING id'),
      parameters: {...updates, 'id': postId},
    );

    if (result.isEmpty) {
      return null;
    }
    return getPostById(postId);
  }

  /// Deletes a post.
  Future<void> deletePost(int postId) async {
    final conn = await DatabaseConnection.connection;
    await conn.execute(
      Sql.named('DELETE FROM posts WHERE id = @id'),
      parameters: {'id': postId},
    );
  }

  Future<Post> _hydratePost(Map<String, dynamic> postMap) async {
    final post = Post.fromMap(postMap);
    final author = User.fromMap({
      'id': post.userId,
      'username': postMap['author_username'],
      'email': postMap['author_email'],
      'password_hash': '',
      'role': postMap['author_role'],
      'created_at': postMap['author_created_at'] ?? post.createdAt,
      'updated_at': postMap['author_updated_at'] ?? post.updatedAt,
    });
    final categories = await _getCategoriesForPost(post.id ?? 0);
    return post.copyWith(author: author, categories: categories);
  }

  Future<List<Category>> _getCategoriesForPost(int postId) async {
    if (postId <= 0) {
      return const [];
    }

    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('''
SELECT c.*
FROM categories c
JOIN post_categories pc ON pc.category_id = c.id
WHERE pc.post_id = @post_id
ORDER BY c.name ASC
'''),
      parameters: {'post_id': postId},
    );
    return result.map((row) => Category.fromMap(row.toColumnMap())).toList();
  }
}
