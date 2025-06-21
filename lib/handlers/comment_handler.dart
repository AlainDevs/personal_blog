import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:personal_blog/services/comment_service.dart';

class CommentHandler {
  final CommentService _commentService;

  CommentHandler(this._commentService);

  Router get router {
    final router = Router();

    router.get('/posts/<postId>/comments', _getCommentsForPost);
    router.post('/posts/<postId>/comments', _addComment); // Requires authentication
    router.delete('/comments/<commentId>', _deleteComment); // Requires authentication and admin/owner role

    return router;
  }

  Future<Response> _getCommentsForPost(Request request) async {
    final postId = int.parse(request.params['postId']!);
    final comments = await _commentService.getCommentsForPost(postId);
    return Response.ok(jsonEncode(comments.map((c) => c.toMap()).toList()));
  }

  Future<Response> _addComment(Request request) async {
    // TODO: Implement authentication middleware to get userId
    final postId = int.parse(request.params['postId']!);
    final payload = jsonDecode(await request.readAsString());
    final userId = payload['user_id']; // This should come from authenticated user
    final content = payload['content'];

    if (userId == null || content == null) {
      return Response.badRequest(body: jsonEncode({'message': 'Missing required fields'}));
    }

    try {
      final comment = await _commentService.addComment(postId, userId, content);
      return Response.ok(jsonEncode(comment.toMap()));
    } catch (e) {
      print('Error adding comment: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to add comment'}));
    }
  }

  Future<Response> _deleteComment(Request request) async {
    // TODO: Implement authentication and authorization middleware
    final commentId = int.parse(request.params['commentId']!);

    try {
      await _commentService.deleteComment(commentId);
      return Response.ok(jsonEncode({'message': 'Comment deleted successfully'}));
    } catch (e) {
      print('Error deleting comment: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete comment'}));
    }
  }
}