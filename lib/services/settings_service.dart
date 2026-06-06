import 'package:personal_blog/models/app_setting.dart';
import 'package:personal_blog/utils/db_utils.dart';

/// Reads and updates application settings stored in PostgreSQL.
class SettingsService {
  /// Setting key that controls whether public registration is allowed.
  static const String registrationEnabledKey = 'registration_enabled';

  /// Returns a setting by key, or `null` when it does not exist.
  Future<AppSetting?> getSetting(String key) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('SELECT * FROM app_settings WHERE key = @key'),
      parameters: {'key': key},
    );

    if (result.isEmpty) {
      return null;
    }
    return AppSetting.fromMap(result.first.toColumnMap());
  }

  /// Creates or updates a setting.
  Future<AppSetting> updateSetting(String key, String value) async {
    final conn = await DatabaseConnection.connection;
    final result = await conn.execute(
      Sql.named('''
INSERT INTO app_settings (key, value, updated_at)
VALUES (@key, @value, NOW())
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  updated_at = NOW()
RETURNING *
'''),
      parameters: {'key': key, 'value': value},
    );
    return AppSetting.fromMap(result.first.toColumnMap());
  }

  /// Returns whether public registration is enabled.
  Future<bool> isRegistrationEnabled() async {
    final setting = await getSetting(registrationEnabledKey);
    return setting?.boolValue ?? true;
  }

  /// Updates whether public registration is enabled.
  Future<AppSetting> setRegistrationEnabled(bool enabled) async {
    return updateSetting(registrationEnabledKey, enabled.toString());
  }
}
