import 'dart:developer' as developer;
import 'dart:io';

import 'package:personal_blog/handlers/auth_handler.dart';
import 'package:personal_blog/handlers/category_handler.dart';
import 'package:personal_blog/handlers/comment_handler.dart';
import 'package:personal_blog/handlers/post_handler.dart';
import 'package:personal_blog/handlers/settings_handler.dart';
import 'package:personal_blog/services/category_service.dart';
import 'package:personal_blog/services/comment_service.dart';
import 'package:personal_blog/services/post_service.dart';
import 'package:personal_blog/services/settings_service.dart';
import 'package:personal_blog/services/user_service.dart';
import 'package:personal_blog/utils/auth_utils.dart';
import 'package:personal_blog/utils/db_utils.dart';
import 'package:personal_blog/utils/request_utils.dart';
import 'package:personal_blog/utils/template_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

const String _htmlContentType = 'text/html; charset=utf-8';
const String _cssContentType = 'text/css; charset=utf-8';

final TemplateManager _templateManager = TemplateManager('web/templates');

/// Creates the Shelf handler used by the executable and tests.
Handler createAppHandler({
  UserService? userService,
  PostService? postService,
  CommentService? commentService,
  CategoryService? categoryService,
  SettingsService? settingsService,
}) {
  final users = userService ?? UserService();
  final posts = postService ?? PostService();
  final comments = commentService ?? CommentService();
  final categories = categoryService ?? CategoryService();
  final settings = settingsService ?? SettingsService();
  final router = Router();

  _mountApiRoutes(router, users, posts, comments, categories, settings);
  _mountStaticRoutes(router);
  _mountPageRoutes(router, users, posts, comments, categories, settings);

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(createAuthMiddleware())
      .addHandler(router.call);
}

/// Middleware that attaches valid JWT context and protects private routes.
Middleware createAuthMiddleware() {
  return (inner) {
    return (request) async {
      final token = AuthUtils.extractTokenFromHeaders(request.headers);
      final claim = token == null ? null : AuthUtils.verifyJwt(token);
      var updatedRequest = request;

      if (claim != null) {
        final userId = int.tryParse(claim.subject ?? '');
        if (userId != null) {
          updatedRequest = request.change(
            context: {
              'auth_user_id': userId,
              'auth_user_role': (claim['role'] ?? 'user').toString(),
              'auth_username': claim['username']?.toString(),
            },
          );
        }
      }

      final path = updatedRequest.url.path;
      if (_isProtectedAdminPage(path) && !isAdminRequest(updatedRequest)) {
        return Response.found('/login');
      }

      if (_isProtectedAdminApi(path) && !isAdminRequest(updatedRequest)) {
        return jsonResponse({
          'message': 'Admin access required.',
        }, statusCode: 403);
      }

      if (_isProtectedCommentPost(updatedRequest) &&
          authenticatedUserId(updatedRequest) == null) {
        return jsonResponse({
          'message': 'You must be logged in to comment.',
        }, statusCode: 403);
      }

      return inner(updatedRequest);
    };
  };
}

Future<void> main(List<String> args) async {
  await DatabaseConnection.initialize();

  final ip = InternetAddress.anyIPv4;
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await serve(createAppHandler(), ip, port);

  developer.log(
    'Server listening on port ${server.port}.',
    name: 'personal_blog.server',
  );
}

void _mountApiRoutes(
  Router router,
  UserService userService,
  PostService postService,
  CommentService commentService,
  CategoryService categoryService,
  SettingsService settingsService,
) {
  router.mount(
    '/api/auth/',
    AuthHandler(userService, settingsService).router.call,
  );
  router.mount('/api/', PostHandler(postService).router.call);
  router.mount('/api/', CommentHandler(commentService).router.call);
  router.mount('/api/', CategoryHandler(categoryService).router.call);
  router.mount('/api/', SettingsHandler(settingsService).router.call);
}

void _mountStaticRoutes(Router router) {
  router.mount(
    '/public/',
    createStaticHandler('web/public', defaultDocument: 'index.html'),
  );

  router.get('/output.css', (request) async {
    final file = File('web/output.css');
    if (!await file.exists()) {
      return Response.notFound('CSS file not found');
    }

    return Response.ok(
      await file.readAsString(),
      headers: {'Content-Type': _cssContentType},
    );
  });
}

void _mountPageRoutes(
  Router router,
  UserService userService,
  PostService postService,
  CommentService commentService,
  CategoryService categoryService,
  SettingsService settingsService,
) {
  router.get('/', (request) async {
    final posts = await postService.getAllPosts(publishedOnly: true);
    final data = await _pageData(request, settingsService, title: 'Home');
    data.addAll({
      'posts': posts.map((post) => post.toMap()).toList(),
      'hasPosts': posts.isNotEmpty,
      'postCount': posts.length,
    });
    return _renderPage('index', data);
  });

  router.get('/login', (request) async {
    if (authenticatedUserId(request) != null) {
      return Response.found('/');
    }

    final data = await _pageData(request, settingsService, title: 'Login');
    return _renderPage('login', data);
  });

  router.get('/logout', (request) {
    return Response.found(
      '/',
      headers: {'Set-Cookie': AuthUtils.clearAuthCookie()},
    );
  });

  router.get('/register', (request) async {
    if (authenticatedUserId(request) != null) {
      return Response.found('/');
    }

    final data = await _pageData(request, settingsService, title: 'Register');
    return _renderPage('register', data);
  });

  router.get('/blog/<slug>', (request) async {
    final slug = request.params['slug'];
    if (slug == null) {
      return Response.badRequest(body: 'Post slug is required.');
    }

    final post = await postService.getPostBySlug(slug);
    if (post == null) {
      return Response.notFound('Post not found.');
    }

    final postId = post.id;
    if (postId == null) {
      return Response.internalServerError(body: 'Post is missing an id.');
    }

    final comments = await commentService.getCommentsForPost(postId);
    final data = await _pageData(request, settingsService, title: post.title);
    data.addAll({
      'post': post.toMap(),
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'hasComments': comments.isNotEmpty,
      'commentCount': comments.length,
    });
    return _renderPage('post_detail', data);
  });

  router.get('/admin', (request) async {
    final data = await _pageData(
      request,
      settingsService,
      title: 'Admin Dashboard',
    );
    return _renderPage('admin/dashboard', data);
  });

  router.get('/admin/posts', (request) async {
    final posts = await postService.getAllPosts(publishedOnly: false);
    final data = await _pageData(
      request,
      settingsService,
      title: 'Manage Posts',
    );
    data.addAll({
      'posts': posts.map((post) => post.toMap()).toList(),
      'hasPosts': posts.isNotEmpty,
    });
    return _renderPage('admin/post_list', data);
  });

  router.get('/admin/posts/new', (request) async {
    final data = await _pageData(
      request,
      settingsService,
      title: 'Create New Post',
    );
    data['post'] = null;
    return _renderPage('admin/post_editor', data);
  });

  router.get('/admin/posts/<id>/edit', (request) async {
    final postId = readPathInt(request, 'id');
    if (postId == null) {
      return Response.badRequest(body: 'Invalid post id.');
    }

    final post = await postService.getPostById(postId);
    if (post == null) {
      return Response.notFound('Post not found.');
    }

    final data = await _pageData(request, settingsService, title: 'Edit Post');
    data['post'] = post.toMap();
    return _renderPage('admin/post_editor', data);
  });

  router.get('/admin/categories', (request) async {
    final categories = await categoryService.getAllCategories();
    final data = await _pageData(
      request,
      settingsService,
      title: 'Manage Categories',
    );
    data.addAll({
      'categories': categories.map((category) => category.toMap()).toList(),
      'hasCategories': categories.isNotEmpty,
    });
    return _renderPage('admin/category_list', data);
  });

  router.get('/admin/users', (request) async {
    final users = await userService.getAllUsers();
    final data = await _pageData(
      request,
      settingsService,
      title: 'Manage Users',
    );
    data.addAll({
      'users': users.map((user) => user.toPublicMap()).toList(),
      'hasUsers': users.isNotEmpty,
    });
    return _renderPage('admin/user_list', data);
  });

  router.get('/admin/settings', (request) async {
    final data = await _pageData(request, settingsService, title: 'Settings');
    return _renderPage('admin/settings', data);
  });
}

Future<Response> _renderPage(
  String templateName,
  Map<String, dynamic> data,
) async {
  final body = await _templateManager.render(templateName, data);
  final html = await _templateManager.render('layout', {...data, 'body': body});

  return Response.ok(html, headers: {'Content-Type': _htmlContentType});
}

Future<Map<String, dynamic>> _pageData(
  Request request,
  SettingsService settingsService, {
  required String title,
}) async {
  final currentUser = _currentUserMap(request);
  final registrationEnabled = await settingsService.isRegistrationEnabled();

  return {
    'title': title,
    'currentYear': DateTime.now().year,
    'isAuthenticated': currentUser != null,
    'isAdmin': isAdminRequest(request),
    'currentUser': currentUser,
    'registrationEnabled': registrationEnabled,
    'registrationDisabled': !registrationEnabled,
  };
}

Map<String, dynamic>? _currentUserMap(Request request) {
  final userId = authenticatedUserId(request);
  if (userId == null) {
    return null;
  }

  return {
    'id': userId,
    'username': request.context['auth_username'] ?? 'Reader',
    'role': authenticatedUserRole(request) ?? 'user',
    'isAdmin': isAdminRequest(request),
  };
}

bool _isProtectedAdminPage(String path) {
  return path == 'admin' || path.startsWith('admin/');
}

bool _isProtectedAdminApi(String path) {
  return path.startsWith('api/admin/') || path.startsWith('api/comments/');
}

bool _isProtectedCommentPost(Request request) {
  return request.method.toUpperCase() == 'POST' &&
      RegExp(r'^api/posts/\d+/comments$').hasMatch(request.url.path);
}
