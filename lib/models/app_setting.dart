/// A persisted application setting.
class AppSetting {
  /// Creates a setting value.
  AppSetting({required this.key, required this.value, DateTime? updatedAt})
    : updatedAt = updatedAt ?? DateTime.now();

  /// Builds a setting from a PostgreSQL row map.
  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: (map['key'] ?? '').toString(),
      value: (map['value'] ?? '').toString(),
      updatedAt: _readDateTime(map['updated_at']),
    );
  }

  /// Setting key.
  final String key;

  /// Stored string value.
  final String value;

  /// Last update timestamp.
  final DateTime updatedAt;

  /// Boolean interpretation of [value].
  bool get boolValue => value.toLowerCase() == 'true';

  /// Converts this setting to a template and JSON friendly map.
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'boolValue': boolValue,
      'updated_at': updatedAt.toIso8601String(),
      'updatedAt': _formatDate(updatedAt),
    };
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
