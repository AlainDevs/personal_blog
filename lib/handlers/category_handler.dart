import 'dart:developer' as developer;

import 'package:personal_blog/services/category_service.dart';
import 'package:personal_blog/utils/request_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Handles category API requests.
class CategoryHandler {
  /// Creates a category handler.
  CategoryHandler(this._categoryService);

  final CategoryService _categoryService;

  /// API router for category endpoints.
  Router get router {
    final router = Router();

    router.get('/categories', _getAllCategories);
    router.post('/admin/categories', _createCategory);
    router.put('/admin/categories/<id>', _updateCategory);
    router.delete('/admin/categories/<id>', _deleteCategory);

    return router;
  }

  Future<Response> _getAllCategories(Request request) async {
    final categories = await _categoryService.getAllCategories();
    return jsonResponse(
      categories.map((category) => category.toMap()).toList(),
    );
  }

  Future<Response> _createCategory(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final payload = await readJsonObject(request);
    if (payload == null) {
      return jsonResponse({'message': 'Invalid JSON body.'}, statusCode: 400);
    }

    final name = readRequiredString(payload, 'name');
    final slug = readRequiredString(payload, 'slug');
    if (name == null || slug == null) {
      return jsonResponse({
        'message': 'Name and slug are required.',
      }, statusCode: 400);
    }

    try {
      final category = await _categoryService.createCategory(name, slug);
      return jsonResponse(category.toMap(), statusCode: 201);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to create category.',
        name: 'personal_blog.categories',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to create category.',
      }, statusCode: 500);
    }
  }

  Future<Response> _updateCategory(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final categoryId = readPathInt(request, 'id');
    final payload = await readJsonObject(request);
    if (categoryId == null || payload == null) {
      return jsonResponse({
        'message': 'Invalid category update.',
      }, statusCode: 400);
    }

    try {
      final updatedCategory = await _categoryService.updateCategory(
        categoryId,
        name: readRequiredString(payload, 'name'),
        slug: readRequiredString(payload, 'slug'),
      );
      if (updatedCategory == null) {
        return jsonResponse({
          'message': 'Category not found.',
        }, statusCode: 404);
      }
      return jsonResponse(updatedCategory.toMap());
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to update category.',
        name: 'personal_blog.categories',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to update category.',
      }, statusCode: 500);
    }
  }

  Future<Response> _deleteCategory(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final categoryId = readPathInt(request, 'id');
    if (categoryId == null) {
      return jsonResponse({'message': 'Invalid category id.'}, statusCode: 400);
    }

    try {
      await _categoryService.deleteCategory(categoryId);
      return jsonResponse({'message': 'Category deleted successfully.'});
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to delete category.',
        name: 'personal_blog.categories',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to delete category.',
      }, statusCode: 500);
    }
  }
}
