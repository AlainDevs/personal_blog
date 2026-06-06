import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/utils/auth_utils.dart';
import 'package:personal_blog/utils/db_utils.dart';

/// Provides user persistence and credential validation.
class UserService {
  /// Finds a user by database id.
  Future<User?> getUserById(int id) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM users WHERE id = @id'),
      parameters: {'id': id},
    );

    if (result.isEmpty) {
      return null;
    }
    return User.fromMap(result.first.toColumnMap());
  }

  /// Finds a user by email address.
  Future<User?> getUserByEmail(String email) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM users WHERE email = @email'),
      parameters: {'email': email.toLowerCase()},
    );

    if (result.isEmpty) {
      return null;
    }
    return User.fromMap(result.first.toColumnMap());
  }

  /// Finds a user by username.
  Future<User?> getUserByUsername(String username) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM users WHERE username = @username'),
      parameters: {'username': username},
    );

    if (result.isEmpty) {
      return null;
    }
    return User.fromMap(result.first.toColumnMap());
  }

  /// Creates a user with a hashed password.
  Future<User> createUser(
    String email,
    String username,
    String password, {
    UserRole role = UserRole.user,
  }) async {
    final conn = await DatabaseConnection.connection;
    final now = DateTime.now().toUtc();
    final result = await conn.execute(
      Sql.named('''
INSERT INTO users (email, username, password_hash, role, created_at, updated_at)
VALUES (@email, @username, @password_hash, @role, @created_at, @updated_at)
RETURNING *
'''),
      parameters: {
        'email': email.toLowerCase(),
        'username': username,
        'password_hash': AuthUtils.hashPassword(password),
        'role': role.name,
        'created_at': now,
        'updated_at': now,
      },
    );
    return User.fromMap(result.first.toColumnMap());
  }

  /// Validates an email and password pair.
  Future<User?> validateUser(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user == null) {
      return null;
    }

    return AuthUtils.verifyPassword(password, user.passwordHash) ? user : null;
  }

  /// Returns every registered user.
  Future<List<User>> getAllUsers() async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute('SELECT * FROM users ORDER BY id ASC');
    return result.map((row) => User.fromMap(row.toColumnMap())).toList();
  }
}
