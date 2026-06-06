import 'dart:developer' as developer;

import 'package:personal_blog/services/post_service.dart';
import 'package:personal_blog/utils/request_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Handles post API requests.
class PostHandler {
  /// Creates a post handler.
  PostHandler(this._postService);

  final PostService _postService;

  /// API router for post endpoints.
  Router get router {
    final router = Router();

    router.get('/posts', _getAllPosts);
    router.get('/posts/<slug>', _getPostBySlug);
    router.post('/admin/posts', _createPost);
    router.put('/admin/posts/<id>', _updatePost);
    router.delete('/admin/posts/<id>', _deletePost);

    return router;
  }

  Future<Response> _getAllPosts(Request request) async {
    final posts = await _postService.getAllPosts();
    return jsonResponse(posts.map((post) => post.toMap()).toList());
  }

  Future<Response> _getPostBySlug(Request request) async {
    final slug = request.params['slug'];
    if (slug == null) {
      return jsonResponse({'message': 'Slug is required.'}, statusCode: 400);
    }

    final post = await _postService.getPostBySlug(slug);
    if (post == null) {
      return jsonResponse({'message': 'Post not found.'}, statusCode: 404);
    }
    return jsonResponse(post.toMap());
  }

  Future<Response> _createPost(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final userId = authenticatedUserId(request);
    final payload = await readJsonObject(request);
    if (userId == null || payload == null) {
      return jsonResponse({'message': 'Invalid request.'}, statusCode: 400);
    }

    final title = readRequiredString(payload, 'title');
    final contentMarkdown = readRequiredString(payload, 'content_markdown');
    final slug = readRequiredString(payload, 'slug');
    final published = readOptionalBool(payload, 'published') ?? false;

    if (title == null || contentMarkdown == null || slug == null) {
      return jsonResponse({
        'message': 'Title, slug, and markdown content are required.',
      }, statusCode: 400);
    }

    try {
      final post = await _postService.createPost(
        userId,
        title,
        contentMarkdown,
        slug,
        published: published,
      );
      return jsonResponse(post.toMap(), statusCode: 201);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to create post.',
        name: 'personal_blog.posts',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to create post.',
      }, statusCode: 500);
    }
  }

  Future<Response> _updatePost(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final postId = readPathInt(request, 'id');
    final payload = await readJsonObject(request);
    if (postId == null || payload == null) {
      return jsonResponse({'message': 'Invalid post update.'}, statusCode: 400);
    }

    try {
      final updatedPost = await _postService.updatePost(
        postId,
        title: readRequiredString(payload, 'title'),
        contentMarkdown: readRequiredString(payload, 'content_markdown'),
        slug: readRequiredString(payload, 'slug'),
        published: readOptionalBool(payload, 'published'),
      );
      if (updatedPost == null) {
        return jsonResponse({'message': 'Post not found.'}, statusCode: 404);
      }
      return jsonResponse(updatedPost.toMap());
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to update post.',
        name: 'personal_blog.posts',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to update post.',
      }, statusCode: 500);
    }
  }

  Future<Response> _deletePost(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final postId = readPathInt(request, 'id');
    if (postId == null) {
      return jsonResponse({'message': 'Invalid post id.'}, statusCode: 400);
    }

    try {
      await _postService.deletePost(postId);
      return jsonResponse({'message': 'Post deleted successfully.'});
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to delete post.',
        name: 'personal_blog.posts',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to delete post.',
      }, statusCode: 500);
    }
  }
}
