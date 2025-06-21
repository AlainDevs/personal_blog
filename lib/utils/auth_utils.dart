import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AuthUtils {
  static const String _secret = 'your_super_secret_jwt_key'; // TODO: Use environment variable

  // Generate a random salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  // Hash password with salt using SHA-256
  static String hashPassword(String password) {
    final salt = _generateSalt();
    final passwordBytes = utf8.encode(password + salt);
    final digest = sha256.convert(passwordBytes);
    return '$salt:${digest.toString()}';
  }

  // Verify password against hash
  static bool verifyPassword(String password, String hashedPassword) {
    final parts = hashedPassword.split(':');
    if (parts.length != 2) return false;
    
    final salt = parts[0];
    final hash = parts[1];
    
    final passwordBytes = utf8.encode(password + salt);
    final digest = sha256.convert(passwordBytes);
    
    return digest.toString() == hash;
  }

  static String generateJwt(int userId, String role) {
    final claimSet = JwtClaim(
      issuer: 'personal_blog',
      subject: userId.toString(),
      jwtId: DateTime.now().millisecondsSinceEpoch.toString(),
      otherClaims: <String, dynamic>{
        'role': role,
      },
      maxAge: const Duration(hours: 24),
    );

    // FIX: Corrected function name to issueJwtHs256
    return issueJwtHS256(claimSet, _secret);
  }

  static JwtClaim? verifyJwt(String token) {
    try {
      // FIX: Corrected function name to verifyJwtHs256
      final decClaimSet = verifyJwtHS256Signature(token, _secret);
      decClaimSet.validate(issuer: 'personal_blog');
      return decClaimSet;
    } on JwtException {
      return null;
    }
  }
}