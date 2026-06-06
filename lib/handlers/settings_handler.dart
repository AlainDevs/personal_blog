import 'package:personal_blog/services/settings_service.dart';
import 'package:personal_blog/utils/request_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Handles application settings API requests.
class SettingsHandler {
  /// Creates a settings handler.
  SettingsHandler(this._settingsService);

  final SettingsService _settingsService;

  /// API router for settings endpoints.
  Router get router {
    final router = Router();

    router.get('/admin/settings', _getSettings);
    router.put('/admin/settings/registration', _updateRegistration);

    return router;
  }

  Future<Response> _getSettings(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final registrationEnabled = await _settingsService.isRegistrationEnabled();
    return jsonResponse({'registration_enabled': registrationEnabled});
  }

  Future<Response> _updateRegistration(Request request) async {
    if (!isAdminRequest(request)) {
      return jsonResponse({
        'message': 'Admin access required.',
      }, statusCode: 403);
    }

    final payload = await readJsonObject(request);
    final enabled =
        payload == null
            ? null
            : readOptionalBool(payload, 'registration_enabled');

    if (enabled == null) {
      return jsonResponse({
        'message': 'registration_enabled must be true or false.',
      }, statusCode: 400);
    }

    final setting = await _settingsService.setRegistrationEnabled(enabled);
    return jsonResponse({'setting': setting.toMap()});
  }
}
