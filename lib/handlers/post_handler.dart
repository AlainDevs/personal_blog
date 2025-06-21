import 'dart:convert';
import 'package:personal_blog/services/post_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
class PostHandler {
  final PostService _postService;

  PostHandler(this._postService);

  Router get router {
    final router = Router();

    router.get('/posts', _getAllPosts);
    router.get('/posts/<slug>', _getPostBySlug);
    router.post('/admin/posts', _createPost); // Requires authentication and admin role
    router.put('/admin/posts/<id>', _updatePost); // Requires authentication and admin role
    router.delete('/admin/posts/<id>', _deletePost); // Requires authentication and admin role

    return router;
  }

  Future<Response> _getAllPosts(Request request) async {
    final posts = await _postService.getAllPosts();
    return Response.ok(jsonEncode(posts.map((p) => p.toMap()).toList()));
  }

  Future<Response> _getPostBySlug(Request request) async {
    final slug = request.params['slug'];
    if (slug == null) {
      return Response.badRequest(body: jsonEncode({'message': 'Slug is required'}));
    }
    final post = await _postService.getPostBySlug(slug);
    if (post == null) {
      return Response.notFound(jsonEncode({'message': 'Post not found'}));
    }
    return Response.ok(jsonEncode(post.toMap()));
  }

  Future<Response> _createPost(Request request) async {
    // TODO: Implement authentication and authorization middleware
    // For now, assuming user_id is passed in the request body for testing
    final payload = jsonDecode(await request.readAsString());
    final userId = payload['user_id']; // This should come from authenticated user
    final title = payload['title'];
    final contentMarkdown = payload['content_markdown'];
    final slug = payload['slug'];
    final published = payload['published'] ?? false;

    if (userId == null || title == null || contentMarkdown == null || slug == null) {
      return Response.badRequest(body: jsonEncode({'message': 'Missing required fields'}));
    }

    try {
      final post = await _postService.createPost(userId, title, contentMarkdown, slug, published: published);
      return Response.ok(jsonEncode(post.toMap()));
    } catch (e) {
      print('Error creating post: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create post'}));
    }
  }

  Future<Response> _updatePost(Request request) async {
    // TODO: Implement authentication and authorization middleware
    final postId = int.parse(request.params['id']!);
    final payload = jsonDecode(await request.readAsString());
    final title = payload['title'];
    final contentMarkdown = payload['content_markdown'];
    final slug = payload['slug'];
    final published = payload['published'];

    try {
      final updatedPost = await _postService.updatePost(
        postId,
        title: title,
        contentMarkdown: contentMarkdown,
        slug: slug,
        published: published,
      );
      if (updatedPost == null) {
        return Response.notFound(jsonEncode({'message': 'Post not found'}));
      }
      return Response.ok(jsonEncode(updatedPost.toMap()));
    } catch (e) {
      print('Error updating post: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update post'}));
    }
  }

  Future<Response> _deletePost(Request request) async {
    // TODO: Implement authentication and authorization middleware
    final postId = int.parse(request.params['id']!);

    try {
      await _postService.deletePost(postId);
      return Response.ok(jsonEncode({'message': 'Post deleted successfully'}));
    } catch (e) {
      print('Error deleting post: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete post'}));
    }
  }
}