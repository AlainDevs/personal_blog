import 'package:personal_blog/models/category.dart';
import 'package:personal_blog/utils/db_utils.dart';

class CategoryService {
  Future<List<Category>> getAllCategories() async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT * FROM categories ORDER BY name ASC',
    );
    return result.map((row) => Category.fromMap(row.toColumnMap())).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT * FROM categories WHERE id = @id',
      parameters: {'id': id},
    );
    if (result.isEmpty) {
      return null;
    }
    return Category.fromMap(result.first.toColumnMap());
  }

  Future<Category?> getCategoryBySlug(String slug) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT * FROM categories WHERE slug = @slug',
      parameters: {'slug': slug},
    );
    if (result.isEmpty) {
      return null;
    }
    return Category.fromMap(result.first.toColumnMap());
  }

  Future<Category> createCategory(String name, String slug) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'INSERT INTO categories (name, slug) VALUES (@name, @slug) RETURNING *',
      parameters: {'name': name, 'slug': slug},
    );
    return Category.fromMap(result.first.toColumnMap());
  }

  Future<Category?> updateCategory(int id, {String? name, String? slug}) async {
    final conn = await DatabaseConnection.connection;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (slug != null) updates['slug'] = slug;

    if (updates.isEmpty) return await getCategoryById(id);

    final updateClauses = updates.keys.map((key) => '$key = @$key').join(', ');
    final result = await conn.execute(
      'UPDATE categories SET $updateClauses WHERE id = @id RETURNING *',
      parameters: {...updates, 'id': id},
    );

    if (result.isEmpty) return null;
    return Category.fromMap(result.first.toColumnMap());
  }

  Future<void> deleteCategory(int id) async {
    final conn = await DatabaseConnection.connection;
    await conn.execute(
      'DELETE FROM categories WHERE id = @id',
      parameters: {'id': id},
    );
  }
}
