import 'dart:io';
import 'dart:convert';

import 'package:personal_blog/services/comment_service.dart';
import 'package:personal_blog/services/post_service.dart';
import 'package:personal_blog/services/user_service.dart';
import 'package:personal_blog/services/category_service.dart';
import 'package:personal_blog/utils/auth_utils.dart';
import 'package:personal_blog/utils/template_manager.dart';
import 'package:personal_blog/handlers/auth_handler.dart';
import 'package:personal_blog/handlers/post_handler.dart';
import 'package:personal_blog/handlers/comment_handler.dart';
import 'package:personal_blog/handlers/category_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';

// Configure a pipeline that logs requests.
final _router = Router();
final _templateManager = TemplateManager('web/templates');

// Refactored to use a function declaration for the middleware.
final _handler = const Pipeline()
    .addMiddleware(logRequests())
    .addMiddleware(createAuthMiddleware()) // Add authentication middleware
    .addHandler(_router.call);

// Refactored to use nested function declarations to align with Dart best practices.
Middleware createAuthMiddleware() {
  Handler middleware(Handler inner) {
    Future<Response> requestHandler(Request request) async {
      // Skip authentication for public routes (login, register, static files, public blog posts)
      if (request.url.path.startsWith('api/auth/') ||
          request.url.path.startsWith('public/') ||
          request.url.path == '/' ||
          request.url.path.startsWith('blog/') ||
          request.url.path.startsWith('login') ||
          request.url.path.startsWith('register')) {
        return inner(request);
      }

      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'message': 'Authentication required'}),
        );
      }

      final token = authHeader.substring(7);
      final claim = AuthUtils.verifyJwt(token);

      if (claim == null) {
        return Response.forbidden(
          jsonEncode({'message': 'Invalid or expired token'}),
        );
      }

      // Attach user ID and role to the request context
      final userId = int.parse(claim.subject!);
      final userRole = claim.payload['role'] ?? 'user'; // Access 'role' safely
      final updatedRequest = request.change(
        context: {'auth_user_id': userId, 'auth_user_role': userRole},
      );

      return inner(updatedRequest);
    }

    return requestHandler;
  }

  return middleware;
}

Future<void> main(List<String> args) async {
  // Initialize services
  final userService = UserService();
  final postService = PostService();
  final commentService = CommentService();
  final categoryService = CategoryService();

  // Initialize handlers
  final authHandler = AuthHandler(userService);
  final postHandler = PostHandler(postService);
  final commentHandler = CommentHandler(commentService);
  final categoryHandler = CategoryHandler(categoryService);

  // Mount API handlers
  _router.mount('/api/auth/', authHandler.router.call);
  _router.mount('/api/', postHandler.router.call);
  _router.mount('/api/', commentHandler.router.call);
  _router.mount('/api/', categoryHandler.router.call);

  // Serve static files from the 'web/public' directory
  _router.mount('/public/', createStaticHandler('web/public'));

  // Frontend routes (server-side rendered)
  _router.get('/', (Request request) async {
    final posts = await postService.getAllPosts(publishedOnly: true);
    final data = {
      'title': 'Home',
      'posts':
          posts
              .map((p) => p.toMap())
              .toList(),
      'currentYear': DateTime.now().year,
      'isAuthenticated': false, // TODO: Implement actual authentication check
    };
    final html = await _templateManager.render('layout', {
      'title': data['title'],
      'isAuthenticated': data['isAuthenticated'],
      'currentYear': data['currentYear'],
      'body': await _templateManager.render('index', data),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/login', (Request request) async {
    final html = await _templateManager.render('layout', {
      'title': 'Login',
      'isAuthenticated': false,
      'currentYear': DateTime.now().year,
      'body': await _templateManager.render('login', {}),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/register', (Request request) async {
    final html = await _templateManager.render('layout', {
      'title': 'Register',
      'isAuthenticated': false,
      'currentYear': DateTime.now().year,
      'body': await _templateManager.render('register', {}),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/blog/<slug>', (Request request) async {
    // FIX: Corrected the syntax error by splitting the statement into two lines.
    final params =
        request.context['shelf_router/params'] as Map<String, String>?;
    final slug = params?['slug'];
    if (slug == null) {
      return Response.badRequest(body: 'Post slug is required');
    }
    final post = await postService.getPostBySlug(slug);
    if (post == null) {
      return Response.notFound('Post not found');
    }
    final comments = await commentService.getCommentsForPost(post.id!);
    final data = {
      'title': post.title,
      'post': post.toMap(),
      'comments':
          comments
              .map((c) => c.toMap())
              .toList(),
      'currentYear': DateTime.now().year,
      'isAuthenticated': false, // TODO: Implement actual authentication check
    };
    final html = await _templateManager.render('layout', {
      'title': data['title'],
      'isAuthenticated': data['isAuthenticated'],
      'currentYear': data['currentYear'],
      'body': await _templateManager.render('post_detail', data),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/admin', (Request request) async {
    // TODO: Implement authentication and authorization middleware
    final html = await _templateManager.render('layout', {
      'title': 'Admin Dashboard',
      'isAuthenticated': true, // Assuming authenticated for admin pages
      'currentYear': DateTime.now().year,
      'body': await _templateManager.render('admin/dashboard', {}),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/admin/posts', (Request request) async {
    // TODO: Implement authentication and authorization middleware
    final posts = await postService.getAllPosts(publishedOnly: false);
    final data = {
      'title': 'Manage Posts',
      'posts':
          posts
              .map((p) => p.toMap())
              .toList(),
      'currentYear': DateTime.now().year,
      'isAuthenticated': true,
    };
    final html = await _templateManager.render('layout', {
      'title': data['title'],
      'isAuthenticated': data['isAuthenticated'],
      'currentYear': data['currentYear'],
      'body': await _templateManager.render('admin/post_list', data),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/admin/posts/new', (Request request) async {
    // TODO: Implement authentication and authorization middleware
    final html = await _templateManager.render('layout', {
      'title': 'Create New Post',
      'isAuthenticated': true,
      'currentYear': DateTime.now().year,
      'body': await _templateManager.render('admin/post_editor', {
        'post': null,
      }),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/admin/posts/<id>/edit', (Request request) async {
    // TODO: Implement authentication and authorization middleware
    // FIX: Safely accessed router parameters to prevent potential null exceptions.
    final params =
        request.context['shelf_router/params'] as Map<String, String>?;
    final postIdString = params?['id'];

    if (postIdString == null) {
      return Response.badRequest(body: 'Invalid post ID');
    }
    final postId = int.tryParse(postIdString);

    if (postId == null) {
      return Response.badRequest(body: 'Invalid post ID');
    }
    final post = await postService.getPostById(postId);
    if (post == null) {
      return Response.notFound('Post not found');
    }
    final data = {
      'title': 'Edit Post',
      'post': post.toMap(),
      'currentYear': DateTime.now().year,
      'isAuthenticated': true,
    };
    final html = await _templateManager.render('layout', {
      'title': data['title'],
      'isAuthenticated': data['isAuthenticated'],
      'currentYear': data['currentYear'],
      'body': await _templateManager.render('admin/post_editor', data),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/admin/categories', (Request request) async {
    // TODO: Implement authentication and authorization middleware
    final categories = await categoryService.getAllCategories();
    final data = {
      'title': 'Manage Categories',
      'categories':
          categories
              .map((c) => c.toMap())
              .toList(),
      'currentYear': DateTime.now().year,
      'isAuthenticated': true,
    };
    final html = await _templateManager.render('layout', {
      'title': data['title'],
      'isAuthenticated': data['isAuthenticated'],
      'currentYear': data['currentYear'],
      'body': await _templateManager.render('admin/category_list', data),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  _router.get('/admin/users', (Request request) async {
    // TODO: Implement authentication and authorization middleware
    // For simplicity, fetching all users. In a real app, pagination/filtering would be needed.
    final users =
        await userService
            .getAllUsers(); // Assuming a getAllUsers method in UserService
    final data = {
      'title': 'Manage Users',
      // FIX: Removed unnecessary cast `(u as User)`.
      'users': users.map((u) => u.toMap()).toList(),
      'currentYear': DateTime.now().year,
      'isAuthenticated': true,
    };
    final html = await _templateManager.render('layout', {
      'title': data['title'],
      'isAuthenticated': data['isAuthenticated'],
      'currentYear': data['currentYear'],
      'body': await _templateManager.render('admin/user_list', data),
    });
    return Response.ok(html, headers: {'Content-Type': 'text/html'});
  });

  final ip = InternetAddress.anyIPv4;

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(_handler, ip, port);
  print('Server listening on port ${server.port}');
}
