import 'dart:developer' as developer;

import 'package:personal_blog/models/user.dart';
import 'package:personal_blog/services/settings_service.dart';
import 'package:personal_blog/services/user_service.dart';
import 'package:personal_blog/utils/auth_utils.dart';
import 'package:personal_blog/utils/request_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Handles login and registration API requests.
class AuthHandler {
  /// Creates an auth handler.
  AuthHandler(this._userService, this._settingsService);

  final UserService _userService;
  final SettingsService _settingsService;

  /// API router for authentication endpoints.
  Router get router {
    final router = Router();

    router.post('/register', _register);
    router.post('/login', _login);

    return router;
  }

  Future<Response> _register(Request request) async {
    if (!await _settingsService.isRegistrationEnabled()) {
      return jsonResponse({
        'message': 'Registration is currently disabled.',
      }, statusCode: 403);
    }

    final payload = await readJsonObject(request);
    if (payload == null) {
      return jsonResponse({'message': 'Invalid JSON body.'}, statusCode: 400);
    }

    final email = readRequiredString(payload, 'email')?.toLowerCase();
    final username = readRequiredString(payload, 'username');
    final password = readRequiredString(payload, 'password');

    if (email == null || username == null || password == null) {
      return jsonResponse({
        'message': 'Email, username, and password are required.',
      }, statusCode: 400);
    }

    if (!_isValidEmail(email)) {
      return jsonResponse({
        'message': 'Enter a valid email address.',
      }, statusCode: 400);
    }

    if (password.length < 8) {
      return jsonResponse({
        'message': 'Password must be at least 8 characters.',
      }, statusCode: 400);
    }

    if (await _userService.getUserByEmail(email) != null) {
      return jsonResponse({
        'message': 'Email is already registered.',
      }, statusCode: 409);
    }

    if (await _userService.getUserByUsername(username) != null) {
      return jsonResponse({
        'message': 'Username is already taken.',
      }, statusCode: 409);
    }

    try {
      final user = await _userService.createUser(
        email,
        username,
        password,
        role: UserRole.user,
      );
      return _signedInResponse(request, user, 'Registration successful.', 201);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to register user.',
        name: 'personal_blog.auth',
        error: error,
        stackTrace: stackTrace,
      );
      return jsonResponse({
        'message': 'Failed to register user.',
      }, statusCode: 500);
    }
  }

  Future<Response> _login(Request request) async {
    final payload = await readJsonObject(request);
    if (payload == null) {
      return jsonResponse({'message': 'Invalid JSON body.'}, statusCode: 400);
    }

    final email = readRequiredString(payload, 'email')?.toLowerCase();
    final password = readRequiredString(payload, 'password');

    if (email == null || password == null) {
      return jsonResponse({
        'message': 'Email and password are required.',
      }, statusCode: 400);
    }

    final user = await _userService.validateUser(email, password);
    if (user == null) {
      return jsonResponse({
        'message': 'Invalid email or password.',
      }, statusCode: 403);
    }

    return _signedInResponse(request, user, 'Login successful.', 200);
  }

  Response _signedInResponse(
    Request request,
    User user,
    String message,
    int statusCode,
  ) {
    final userId = user.id;
    if (userId == null) {
      return jsonResponse({
        'message': 'User account is missing an identifier.',
      }, statusCode: 500);
    }

    final token = AuthUtils.generateJwt(
      userId,
      user.role.name,
      username: user.username,
    );
    return jsonResponse(
      {'message': message, 'token': token, 'user': user.toPublicMap()},
      statusCode: statusCode,
      headers: {
        'Set-Cookie': AuthUtils.createAuthCookie(
          token,
          secure: request.requestedUri.scheme == 'https',
        ),
      },
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}
