import 'dart:convert';
import 'package:personal_blog/services/category_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class CategoryHandler {
  final CategoryService _categoryService;

  CategoryHandler(this._categoryService);

  Router get router {
    final router = Router();

    router.get('/categories', _getAllCategories);
    router.post('/admin/categories', _createCategory); // Requires authentication and admin role
    router.put('/admin/categories/<id>', _updateCategory); // Requires authentication and admin role
    router.delete('/admin/categories/<id>', _deleteCategory); // Requires authentication and admin role

    return router;
  }

  Future<Response> _getAllCategories(Request request) async {
    final categories = await _categoryService.getAllCategories();
    return Response.ok(jsonEncode(categories.map((c) => c.toMap()).toList()));
  }

  Future<Response> _createCategory(Request request) async {
    // TODO: Implement authentication and authorization middleware
    final payload = jsonDecode(await request.readAsString());
    final name = payload['name'];
    final slug = payload['slug'];

    if (name == null || slug == null) {
      return Response.badRequest(body: jsonEncode({'message': 'Missing required fields'}));
    }

    try {
      final category = await _categoryService.createCategory(name, slug);
      return Response.ok(jsonEncode(category.toMap()));
    } catch (e) {
      print('Error creating category: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create category'}));
    }
  }

  Future<Response> _updateCategory(Request request) async {
    // TODO: Implement authentication and authorization middleware
    final categoryId = int.parse(request.params['id']!);
    final payload = jsonDecode(await request.readAsString());
    final name = payload['name'];
    final slug = payload['slug'];

    try {
      final updatedCategory = await _categoryService.updateCategory(
        categoryId,
        name: name,
        slug: slug,
      );
      if (updatedCategory == null) {
        return Response.notFound(jsonEncode({'message': 'Category not found'}));
      }
      return Response.ok(jsonEncode(updatedCategory.toMap()));
    } catch (e) {
      print('Error updating category: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update category'}));
    }
  }

  Future<Response> _deleteCategory(Request request) async {
    // TODO: Implement authentication and authorization middleware
    final categoryId = int.parse(request.params['id']!);

    try {
      await _categoryService.deleteCategory(categoryId);
      return Response.ok(jsonEncode({'message': 'Category deleted successfully'}));
    } catch (e) {
      print('Error deleting category: $e');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete category'}));
    }
  }
}