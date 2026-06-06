import 'dart:convert';

import 'package:personal_blog/handlers/auth_handler.dart';
import 'package:personal_blog/handlers/comment_handler.dart';
import 'package:personal_blog/models/app_setting.dart';
import 'package:personal_blog/models/comment.dart';
import 'package:personal_blog/models/post.dart';
import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/server.dart';
import 'package:personal_blog/services/comment_service.dart';
import 'package:personal_blog/services/post_service.dart';
import 'package:personal_blog/services/settings_service.dart';
import 'package:personal_blog/services/user_service.dart';
import 'package:personal_blog/utils/auth_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('AppSetting', () {
    test('reads bool values from database maps', () {
      final setting = AppSetting.fromMap({
        'key': SettingsService.registrationEnabledKey,
        'value': 'true',
        'updated_at': DateTime.utc(2026),
      });

      expect(setting.boolValue, isTrue);
      expect(setting.toMap()['boolValue'], isTrue);
    });
  });

  group('AuthUtils', () {
    test('hashes and verifies passwords', () {
      final hash = AuthUtils.hashPassword('ReaderPass123!');

      expect(hash, isNot(equals('ReaderPass123!')));
      expect(AuthUtils.verifyPassword('ReaderPass123!', hash), isTrue);
      expect(AuthUtils.verifyPassword('wrong-password', hash), isFalse);
    });

    test('creates and reads auth cookies', () {
      final token = AuthUtils.generateJwt(42, 'admin', username: 'admin');
      final cookie = AuthUtils.createAuthCookie(token);
      final cookieValue = AuthUtils.readCookie(
        cookie,
        AuthUtils.authCookieName,
      );

      expect(AuthUtils.verifyJwt(cookieValue!), isNotNull);
    });
  });

  group('AuthHandler', () {
    test(
      'rejects registration when the database setting disables it',
      () async {
        final users = FakeUserService();
        final settings = FakeSettingsService(registrationEnabled: false);
        final handler = AuthHandler(users, settings).router.call;

        final response = await handler(
          jsonRequest('POST', 'http://localhost/register', {
            'email': 'new@example.com',
            'username': 'new_reader',
            'password': 'ReaderPass123!',
          }),
        );

        final body = jsonDecode(await response.readAsString()) as Map;
        expect(response.statusCode, equals(403));
        expect(body['message'], contains('disabled'));
        expect(users.createCalled, isFalse);
      },
    );

    test('login returns an auth cookie for valid credentials', () async {
      final user = User(
        id: 7,
        email: 'admin@example.com',
        username: 'admin',
        passwordHash: AuthUtils.hashPassword('AdminPass123!'),
        role: UserRole.admin,
      );
      final users = FakeUserService(validatedUser: user);
      final settings = FakeSettingsService(registrationEnabled: true);
      final handler = AuthHandler(users, settings).router.call;

      final response = await handler(
        jsonRequest('POST', 'http://localhost/login', {
          'email': 'admin@example.com',
          'password': 'AdminPass123!',
        }),
      );

      expect(response.statusCode, equals(200));
      expect(
        response.headers.values.join(';'),
        contains(AuthUtils.authCookieName),
      );
    });
  });

  group('CommentHandler', () {
    test(
      'uses authenticated user context instead of a hard-coded user id',
      () async {
        final comments = FakeCommentService();
        final handler = CommentHandler(comments).router.call;
        final request = jsonRequest(
          'POST',
          'http://localhost/posts/10/comments',
          {'content': 'A thoughtful response.'},
        ).change(context: {'auth_user_id': 42, 'auth_user_role': 'user'});

        final response = await handler(request);

        expect(response.statusCode, equals(201));
        expect(comments.lastUserId, equals(42));
        expect(comments.lastPostId, equals(10));
      },
    );
  });

  group('page routes', () {
    test(
      'renders a blog detail page from the slug path parameter',
      () async {
        final handler = createAppHandler(
          postService: FakePostService(
            Post(
              id: 2,
              userId: 1,
              title: 'A tiny publishing checklist',
              contentMarkdown: '## Before pressing publish',
              contentHtml: '<h2>Before pressing publish</h2>',
              slug: 'a-tiny-publishing-checklist',
              published: true,
              author: User(
                id: 1,
                email: 'admin@example.com',
                username: 'admin',
                passwordHash: 'hash',
                role: UserRole.admin,
              ),
            ),
          ),
          commentService: FakeCommentService(),
          settingsService: FakeSettingsService(registrationEnabled: true),
        );

        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://localhost/blog/a-tiny-publishing-checklist'),
          ),
        );

        expect(response.statusCode, equals(200));
        expect(
          await response.readAsString(),
          contains('A tiny publishing checklist'),
        );
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });

  group('createAuthMiddleware', () {
    test('redirects anonymous admin page requests to login', () async {
      final handler = createAuthMiddleware()((request) async {
        return Response.ok('admin');
      });

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/admin')),
      );

      expect(response.statusCode, equals(302));
      expect(response.headers['location'], equals('/login'));
    });

    test('allows admin page requests with an admin auth cookie', () async {
      final token = AuthUtils.generateJwt(1, 'admin', username: 'admin');
      final handler = createAuthMiddleware()((request) async {
        return Response.ok(request.context['auth_user_role'].toString());
      });

      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/admin'),
          headers: {
            'Cookie':
                '${AuthUtils.authCookieName}=${Uri.encodeComponent(token)}',
          },
        ),
      );

      expect(response.statusCode, equals(200));
      expect(await response.readAsString(), equals('admin'));
    });
  });
}

Request jsonRequest(String method, String url, Map<String, Object?> body) {
  return Request(
    method,
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService({required this.registrationEnabled});

  bool registrationEnabled;

  @override
  Future<bool> isRegistrationEnabled() async => registrationEnabled;

  @override
  Future<AppSetting> setRegistrationEnabled(bool enabled) async {
    registrationEnabled = enabled;
    return AppSetting(
      key: SettingsService.registrationEnabledKey,
      value: enabled.toString(),
    );
  }
}

class FakeUserService extends UserService {
  FakeUserService({this.validatedUser});

  final User? validatedUser;
  bool createCalled = false;

  @override
  Future<User?> getUserByEmail(String email) async => null;

  @override
  Future<User?> getUserByUsername(String username) async => null;

  @override
  Future<User?> validateUser(String email, String password) async {
    return validatedUser;
  }

  @override
  Future<User> createUser(
    String email,
    String username,
    String password, {
    UserRole role = UserRole.user,
  }) async {
    createCalled = true;
    return User(
      id: 11,
      email: email,
      username: username,
      passwordHash: AuthUtils.hashPassword(password),
      role: role,
    );
  }
}

class FakePostService extends PostService {
  FakePostService(this.post);

  final Post post;

  @override
  Future<Post?> getPostBySlug(String slug) async {
    if (slug == post.slug) {
      return post;
    }
    return null;
  }
}

class FakeCommentService extends CommentService {
  int? lastPostId;
  int? lastUserId;

  @override
  Future<List<Comment>> getCommentsForPost(int postId) async => const [];

  @override
  Future<Comment> addComment(int postId, int userId, String content) async {
    lastPostId = postId;
    lastUserId = userId;
    return Comment(id: 1, postId: postId, userId: userId, content: content);
  }
}
