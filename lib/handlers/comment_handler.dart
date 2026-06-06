import 'dart:developer' as developer;

import 'package:personal_blog/services/comment_service.dart';
import 'package:personal_blog/utils/request_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Handles comment API requests.
class CommentHandler {
  /// Creates a comment handler.
  CommentHandler(this._commentService);

  final CommentService _commentService;

  /// API router for comment endpoints.
  Router get router {
    final router = Router();

    router.get('/posts/<postId>/comments', _getCommentsForPost);
    router.post('/posts/<postId>/comments', _addComment);
    router.delete('/comments/<commentId>', _deleteComment);

    return router;
  }

  Future<Response> _getCommentsForPost(Request request) async {
    final postId = readPathInt(request, 'postId');
    if (postId == null) {
      return jsonResponse({'message': 'Invalid post id.'}, statusCode: 400);
    }

    final comments = await _commentService.getCommentsForPost(postId);
    return jsonResponse(comments.map((comment) => comment.toMap()).toList());
  }

  Future<Response> _addComment(Request request) async {
    final postId = readPathInt(request, 'postId');
    final userId = authenticatedUserId(request);
    final payload = await readJsonObject(request);

    if (postId == null || userId == null || payload == null) {
      return jsonResponse({
        'message': 'Invalid comment request.',
      }, statusCode: 400);
    }

    final content = readRequiredString(payload, 'content');
    if (content == null) {
      return jsonResponse({
        'message': 'Comment content is required.',
      }, statusCode: 400);
    }

    try {
      final comment = await _commentService.addComment(postId, userId, content);
      return jsonResponse(comment.toMap(), statusCode: 201);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to add comment.',
        name: 'personal_blog.comments',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to add comment.',
      }, statusCode: 500);
    }
  }

  Future<Response> _deleteComment(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final commentId = readPathInt(request, 'commentId');
    if (commentId == null) {
      return jsonResponse({'message': 'Invalid comment id.'}, statusCode: 400);
    }

    try {
      await _commentService.deleteComment(commentId);
      return jsonResponse({'message': 'Comment deleted successfully.'});
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to delete comment.',
        name: 'personal_blog.comments',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to delete comment.',
      }, statusCode: 500);
    }
  }
}
