import 'package:personal_blog/models/category.dart';
import 'package:personal_blog/utils/db_utils.dart';

/// Provides category persistence for blog posts.
class CategoryService {
  /// Returns every category alphabetically.
  Future<List<Category>> getAllCategories() async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT * FROM categories ORDER BY name ASC',
    );
    return result.map((row) => Category.fromMap(row.toColumnMap())).toList();
  }

  /// Finds a category by database id.
  Future<Category?> getCategoryById(int id) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM categories WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) {
      return null;
    }
    return Category.fromMap(result.first.toColumnMap());
  }

  /// Finds a category by slug.
  Future<Category?> getCategoryBySlug(String slug) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM categories WHERE slug = @slug'),
      parameters: {'slug': slug},
    );
    if (result.isEmpty) {
      return null;
    }
    return Category.fromMap(result.first.toColumnMap());
  }

  /// Creates a category.
  Future<Category> createCategory(String name, String slug) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named(
        'INSERT INTO categories (name, slug) VALUES (@name, @slug) RETURNING *',
      ),
      parameters: {'name': name, 'slug': slug},
    );
    return Category.fromMap(result.first.toColumnMap());
  }

  /// Updates a category.
  Future<Category?> updateCategory(int id, {String? name, String? slug}) async {
    final conn = await DatabaseConnection.connection;
    final updates = <String, dynamic>{};
    if (name != null) {
      updates['name'] = name;
    }
    if (slug != null) {
      updates['slug'] = slug;
    }

    if (updates.isEmpty) {
      return getCategoryById(id);
    }

    final updateClauses = updates.keys.map((key) => '$key = @$key').join(', ');
    final result = await conn.execute(
      Sql.named(
        'UPDATE categories SET $updateClauses WHERE id = @id RETURNING *',
      ),
      parameters: {...updates, 'id': id},
    );

    if (result.isEmpty) {
      return null;
    }
    return Category.fromMap(result.first.toColumnMap());
  }

  /// Deletes a category.
  Future<void> deleteCategory(int id) async {
    final conn = await DatabaseConnection.connection;
    await conn.execute(
      Sql.named('DELETE FROM categories WHERE id = @id'),
      parameters: {'id': id},
    );
  }
}
