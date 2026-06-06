import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

/// Authentication helpers for password hashing, JWTs, and auth cookies.
class AuthUtils {
  /// Cookie name used by server-rendered pages and same-origin API calls.
  static const String authCookieName = 'personal_blog_auth';

  /// JWT issuer used during validation.
  static const String issuer = 'personal_blog';

  /// Default JWT lifetime.
  static const Duration tokenLifetime = Duration(hours: 24);

  static String get _secret {
    return Platform.environment['JWT_SECRET'] ??
        'local-development-secret-change-me';
  }

  /// Hashes a password with a random salt.
  static String hashPassword(String password) {
    final salt = _generateSalt();
    final passwordBytes = utf8.encode(password + salt);
    final digest = sha256.convert(passwordBytes);
    return '$salt:$digest';
  }

  /// Verifies a password against a stored salted hash.
  static bool verifyPassword(String password, String hashedPassword) {
    final parts = hashedPassword.split(':');
    if (parts.length != 2) {
      return false;
    }

    final salt = parts[0];
    final hash = parts[1];
    final passwordBytes = utf8.encode(password + salt);
    final digest = sha256.convert(passwordBytes);

    return digest.toString() == hash;
  }

  /// Creates a signed JWT for an authenticated user.
  static String generateJwt(int userId, String role, {String? username}) {
    final claimSet = JwtClaim(
      issuer: issuer,
      subject: userId.toString(),
      jwtId: DateTime.now().millisecondsSinceEpoch.toString(),
      otherClaims: <String, dynamic>{
        'role': role,
        if (username != null) 'username': username,
      },
      maxAge: tokenLifetime,
    );

    return issueJwtHS256(claimSet, _secret);
  }

  /// Validates a signed JWT and returns its claims when valid.
  static JwtClaim? verifyJwt(String token) {
    try {
      final claimSet = verifyJwtHS256Signature(token, _secret);
      claimSet.validate(issuer: issuer);
      return claimSet;
    } on JwtException {
      return null;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Reads the bearer token or auth cookie from request headers.
  static String? extractTokenFromHeaders(Map<String, String> headers) {
    final authorization = headers['Authorization'] ?? headers['authorization'];
    if (authorization != null && authorization.startsWith('Bearer ')) {
      return authorization.substring(7).trim();
    }

    final cookieHeader = headers['Cookie'] ?? headers['cookie'];
    return readCookie(cookieHeader, authCookieName);
  }

  /// Reads a single cookie value from a cookie header.
  static String? readCookie(String? cookieHeader, String name) {
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      return null;
    }

    for (final part in cookieHeader.split(';')) {
      final pair = part.trim().split('=');
      if (pair.length < 2 || pair.first != name) {
        continue;
      }
      return Uri.decodeComponent(pair.sublist(1).join('='));
    }
    return null;
  }

  /// Creates a Set-Cookie header for the auth token.
  static String createAuthCookie(String token, {bool secure = false}) {
    final securePart = secure ? '; Secure' : '';
    return '$authCookieName=${Uri.encodeComponent(token)}; '
        'Path=/; Max-Age=${tokenLifetime.inSeconds}; HttpOnly; '
        'SameSite=Lax$securePart';
  }

  /// Creates a Set-Cookie header that clears the auth token.
  static String clearAuthCookie() {
    return '$authCookieName=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax';
  }

  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(saltBytes);
  }
}
