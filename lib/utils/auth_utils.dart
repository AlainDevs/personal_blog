import 'package:dargon2/dargon2.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AuthUtils {
  static const String _secret = 'your_super_secret_jwt_key'; // TODO: Use environment variable

  // FIX: Replaced with a working Argon2 implementation
  static Future<String> hashPassword(String password) async {
    final s = Salt.newSalt();
    final result = await argon2.hashPasswordString(
      password,
      salt: s,
    );
    return result.encodedString;
  }

  // FIX: Replaced with a working Argon2 verification
  static Future<bool> verifyPassword(String password, String hashedPassword) async {
    return await argon2.verifyHashString(password, hashedPassword);
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