import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:markdown/markdown.dart' as markdown;
import 'package:personal_blog/utils/auth_utils.dart';
import 'package:postgres/postgres.dart';

/// PostgreSQL connection and schema bootstrap for the blog.
class DatabaseConnection {
  static Connection? _connection;

  /// Returns a shared PostgreSQL connection, opening it on first use.
  static Future<Connection> get connection async {
    final existingConnection = _connection;
    if (existingConnection != null) {
      return existingConnection;
    }

    final openedConnection = await _openWithRetry();
    _connection = openedConnection;
    return openedConnection;
  }

  /// Creates required tables and optional example content.
  static Future<void> initialize({bool seedExampleData = true}) async {
    final conn = await connection;
    await _createSchema(conn);
    await _seedSettings(conn);

    if (seedExampleData) {
      await _seedExampleContent(conn);
    }
  }

  /// Closes the shared connection.
  static Future<void> closeConnection() async {
    final existingConnection = _connection;
    if (existingConnection == null) {
      return;
    }

    await existingConnection.close();
    _connection = null;
  }

  static Future<Connection> _openWithRetry() async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= 10; attempt += 1) {
      try {
        return await Connection.open(
          Endpoint(
            host: Platform.environment['DB_HOST'] ?? 'db',
            port: int.tryParse(Platform.environment['DB_PORT'] ?? '') ?? 5432,
            database: Platform.environment['DB_NAME'] ?? 'blog_db',
            username: Platform.environment['DB_USER'] ?? 'user',
            password: Platform.environment['DB_PASSWORD'] ?? 'password',
          ),
          settings: const ConnectionSettings(
            timeZone: 'UTC',
            sslMode: SslMode.disable,
          ),
        );
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        developer.log(
          'Database connection attempt $attempt failed.',
          name: 'personal_blog.database',
          error: error,
          stackTrace: stackTrace,
        );
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  static Future<void> _createSchema(Connection conn) async {
    await conn.execute('''
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
''');

    await conn.execute('''
CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE
)
''');

    await conn.execute('''
CREATE TABLE IF NOT EXISTS posts (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content_markdown TEXT NOT NULL,
  content_html TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
''');

    await conn.execute('''
CREATE TABLE IF NOT EXISTS comments (
  id SERIAL PRIMARY KEY,
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
''');

    await conn.execute('''
CREATE TABLE IF NOT EXISTS post_categories (
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, category_id)
)
''');

    await conn.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
''');
  }

  static Future<void> _seedSettings(Connection conn) async {
    await conn.execute('''
INSERT INTO app_settings (key, value)
VALUES ('registration_enabled', 'true')
ON CONFLICT (key) DO NOTHING
''');
  }

  static Future<void> _seedExampleContent(Connection conn) async {
    await _seedUser(
      conn,
      email: 'admin@example.com',
      username: 'admin',
      password: 'AdminPass123!',
      role: 'admin',
    );
    await _seedUser(
      conn,
      email: 'reader@example.com',
      username: 'reader',
      password: 'ReaderPass123!',
      role: 'user',
    );

    await _seedCategory(conn, name: 'Craft', slug: 'craft');
    await _seedCategory(conn, name: 'Life Notes', slug: 'life-notes');
    await _seedCategory(conn, name: 'Tools', slug: 'tools');

    final adminId = await _readUserId(conn, 'admin@example.com');
    final readerId = await _readUserId(conn, 'reader@example.com');

    final firstPostId = await _seedPost(
      conn,
      userId: adminId,
      title: 'Building a calmer personal blog',
      slug: 'building-a-calmer-personal-blog',
      categorySlug: 'craft',
      contentMarkdown: '''
## Why this space exists

A personal blog works best when it feels like a quiet notebook instead of a
noisy feed. This demo post shows how a simple Shelf server, Mustache templates,
and Tailwind CSS can produce a warm reading experience.

The goal is not complexity. The goal is a page that loads quickly, reads well,
and gives readers a friendly place to leave thoughtful comments.
''',
    );

    await _seedPost(
      conn,
      userId: adminId,
      title: 'A tiny publishing checklist',
      slug: 'a-tiny-publishing-checklist',
      categorySlug: 'tools',
      contentMarkdown: '''
## Before pressing publish

Use this small checklist when writing a new article:

- keep the opening clear and useful,
- add one practical example,
- read the post aloud once,
- publish only when the conclusion feels complete.

Small routines make personal publishing easier to sustain.
''',
    );

    await _seedComment(
      conn,
      postId: firstPostId,
      userId: readerId,
      content: 'This feels wonderfully focused. The calm layout helps a lot.',
    );
  }

  static Future<void> _seedUser(
    Connection conn, {
    required String email,
    required String username,
    required String password,
    required String role,
  }) async {
    await conn.execute(
      Sql.named('''
INSERT INTO users (email, username, password_hash, role, created_at, updated_at)
VALUES (@email, @username, @password_hash, @role, NOW(), NOW())
ON CONFLICT (email) DO NOTHING
'''),
      parameters: {
        'email': email,
        'username': username,
        'password_hash': AuthUtils.hashPassword(password),
        'role': role,
      },
    );
  }

  static Future<int> _readUserId(Connection conn, String email) async {
    final result = await conn.execute(
      Sql.named('SELECT id FROM users WHERE email = @email'),
      parameters: {'email': email},
    );
    return result.first.toColumnMap()['id'] as int;
  }

  static Future<void> _seedCategory(
    Connection conn, {
    required String name,
    required String slug,
  }) async {
    await conn.execute(
      Sql.named('''
INSERT INTO categories (name, slug)
VALUES (@name, @slug)
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
'''),
      parameters: {'name': name, 'slug': slug},
    );
  }

  static Future<int> _seedPost(
    Connection conn, {
    required int userId,
    required String title,
    required String slug,
    required String categorySlug,
    required String contentMarkdown,
  }) async {
    final contentHtml = markdown.markdownToHtml(contentMarkdown);
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
  TRUE,
  NOW(),
  NOW()
)
ON CONFLICT (slug) DO UPDATE SET
  title = EXCLUDED.title,
  content_markdown = EXCLUDED.content_markdown,
  content_html = EXCLUDED.content_html,
  published = EXCLUDED.published,
  updated_at = NOW()
RETURNING id
'''),
      parameters: {
        'user_id': userId,
        'title': title,
        'content_markdown': contentMarkdown,
        'content_html': contentHtml,
        'slug': slug,
      },
    );

    final postId = result.first.toColumnMap()['id'] as int;
    await _seedPostCategory(conn, postId: postId, categorySlug: categorySlug);
    return postId;
  }

  static Future<void> _seedPostCategory(
    Connection conn, {
    required int postId,
    required String categorySlug,
  }) async {
    final categoryResult = await conn.execute(
      Sql.named('SELECT id FROM categories WHERE slug = @slug'),
      parameters: {'slug': categorySlug},
    );
    if (categoryResult.isEmpty) {
      return;
    }

    await conn.execute(
      Sql.named('''
INSERT INTO post_categories (post_id, category_id)
VALUES (@post_id, @category_id)
ON CONFLICT (post_id, category_id) DO NOTHING
'''),
      parameters: {
        'post_id': postId,
        'category_id': categoryResult.first.toColumnMap()['id'],
      },
    );
  }

  static Future<void> _seedComment(
    Connection conn, {
    required int postId,
    required int userId,
    required String content,
  }) async {
    await conn.execute(
      Sql.named('''
INSERT INTO comments (post_id, user_id, content, created_at)
SELECT @post_id, @user_id, @content, NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM comments
  WHERE post_id = @post_id AND user_id = @user_id AND content = @content
)
'''),
      parameters: {'post_id': postId, 'user_id': userId, 'content': content},
    );
  }
}
