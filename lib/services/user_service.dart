import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/utils/db_utils.dart';
import 'package:personal_blog/utils/auth_utils.dart';

class UserService {
  Future<User?> getUserByEmail(String email) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT * FROM users WHERE email = @email',
      parameters: {'email': email},
    );

    if (result.isEmpty) {
      return null;
    }
    return User.fromMap(result.first.toColumnMap());
  }

  Future<User?> getUserByUsername(String username) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      'SELECT * FROM users WHERE username = @username',
      parameters: {'username': username},
    );

    if (result.isEmpty) {
      return null;
    }
    return User.fromMap(result.first.toColumnMap());
  }

  Future<User> createUser(
    String email,
    String username,
    String password,
  ) async {
    final conn = await DatabaseConnection.connection;
    final hashedPassword = await AuthUtils.hashPassword(password);

    final result = await conn.execute(
      'INSERT INTO users (email, username, password_hash, role, created_at, updated_at) VALUES (@email, @username, @password_hash, @role, @created_at, @updated_at) RETURNING *',
      parameters: {
        'email': email,
        'username': username,
        'password_hash': hashedPassword,
        'role': UserRole.user.toString().split('.').last,
        'created_at': DateTime.now(),
        'updated_at': DateTime.now(),
      },
    );
    return User.fromMap(result.first.toColumnMap());
  }

  Future<User?> validateUser(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user == null) {
      return null;
    }

    if (await AuthUtils.verifyPassword(password, user.passwordHash)) {
      return user;
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute('SELECT * FROM users');
    return result.map((row) => User.fromMap(row.toColumnMap())).toList();
  }
}
