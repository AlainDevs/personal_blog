import 'dart:convert';
import 'package:personal_blog/services/user_service.dart';
import 'package:personal_blog/utils/auth_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class AuthHandler {
  final UserService _userService;

  AuthHandler(this._userService);

  Router get router {
    final router = Router();

    router.post('/register', _register);
    router.post('/login', _login);

    return router;
  }

  Future<Response> _register(Request request) async {
    final payload = jsonDecode(await request.readAsString());
    final email = payload['email'];
    final username = payload['username'];
    final password = payload['password'];

    if (email == null || username == null || password == null) {
      return Response.badRequest(
        body: jsonEncode({'message': 'Missing required fields'}),
      );
    }

    if (await _userService.getUserByEmail(email) != null) {
      return Response.badRequest(
        body: jsonEncode({'message': 'Email already registered'}),
      );
    }

    if (await _userService.getUserByUsername(username) != null) {
      return Response.badRequest(
        body: jsonEncode({'message': 'Username already taken'}),
      );
    }

    try {
      final user = await _userService.createUser(email, username, password);
      final token = AuthUtils.generateJwt(
        user.id!,
        user.role.toString().split('.').last,
      );
      return Response.ok(
        jsonEncode({'message': 'User registered successfully', 'token': token}),
      );
    } catch (e) {
      print('Error registering user: $e');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to register user'}),
      );
    }
  }

  Future<Response> _login(Request request) async {
    final payload = jsonDecode(await request.readAsString());
    final email = payload['email'];
    final password = payload['password'];

    if (email == null || password == null) {
      return Response.badRequest(
        body: jsonEncode({'message': 'Missing email or password'}),
      );
    }

    final user = await _userService.validateUser(email, password);

    if (user == null) {
      return Response.forbidden(
        jsonEncode({'message': 'Invalid credentials'}),
      );
    }

    final token = AuthUtils.generateJwt(
      user.id!,
      user.role.toString().split('.').last,
    );
    return Response.ok(
      jsonEncode({'message': 'Login successful', 'token': token}),
    );
  }
}
