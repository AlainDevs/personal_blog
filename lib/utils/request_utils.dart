import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Returns a JSON response with a consistent content type.
Response jsonResponse(
  Object body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json; charset=utf-8', ...headers},
  );
}

/// Reads a JSON object from the request body.
Future<Map<String, dynamic>?> readJsonObject(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Reads a non-empty string field from a JSON map.
String? readRequiredString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Reads an optional boolean field from a JSON map.
bool? readOptionalBool(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
}

/// Reads an integer route parameter safely.
int? readPathInt(Request request, String key) {
  final value = request.params[key];
  return value == null ? null : int.tryParse(value);
}

/// Reads the authenticated user id attached by auth middleware.
int? authenticatedUserId(Request request) {
  final value = request.context['auth_user_id'];
  return value is int ? value : null;
}

/// Reads the authenticated user role attached by auth middleware.
String? authenticatedUserRole(Request request) {
  final value = request.context['auth_user_role'];
  return value is String ? value : null;
}

/// Whether the current request belongs to an admin user.
bool isAdminRequest(Request request) {
  return authenticatedUserRole(request) == 'admin';
}
