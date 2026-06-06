/// Available roles for people who can sign in to the blog.
enum UserRole { admin, user }

/// A registered blog user.
class User {
  /// Creates a user value.
  User({
    this.id,
    required this.email,
    required this.username,
    required this.passwordHash,
    this.role = UserRole.user,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Builds a user from a PostgreSQL row map.
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: _readNullableInt(map['id']),
      email: (map['email'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      passwordHash: (map['password_hash'] ?? '').toString(),
      role: userRoleFromName(map['role']),
      createdAt: _readDateTime(map['created_at']),
      updatedAt: _readDateTime(map['updated_at']),
    );
  }

  /// Converts a stored role name into a [UserRole].
  static UserRole userRoleFromName(Object? value) {
    final roleName = value?.toString();
    return UserRole.values.firstWhere(
      (role) => role.name == roleName,
      orElse: () => UserRole.user,
    );
  }

  /// Database identifier.
  final int? id;

  /// Unique email address used for login.
  final String email;

  /// Public display name.
  final String username;

  /// Salted password hash.
  final String passwordHash;

  /// Permission role for this user.
  final UserRole role;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

  /// Whether the user can manage the blog.
  bool get isAdmin => role == UserRole.admin;

  /// Full database map, including the password hash.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'password_hash': passwordHash,
      'passwordHash': passwordHash,
      'role': role.name,
      'isAdmin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      'createdAt': _formatDate(createdAt),
      'updated_at': updatedAt.toIso8601String(),
      'updatedAt': _formatDate(updatedAt),
    };
  }

  /// Public map safe for templates and JSON responses.
  Map<String, dynamic> toPublicMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'role': role.name,
      'isAdmin': isAdmin,
      'createdAt': _formatDate(createdAt),
      'updatedAt': _formatDate(updatedAt),
    };
  }

  /// Returns a copy with selected fields changed.
  User copyWith({
    int? id,
    String? email,
    String? username,
    String? passwordHash,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime _readDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

int? _readNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
