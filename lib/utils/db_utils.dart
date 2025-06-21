import 'package:postgres/postgres.dart';

class DatabaseConnection {
  static Connection? _connection;

  static Future<Connection> get connection async {
    _connection ??= await Connection.open(
      Endpoint(
        host: 'db', // Service name from docker-compose.yml
        port: 5432,
        database: 'blog_db',
        username: 'user',
        password: 'password',
      ),
      settings: ConnectionSettings(timeZone: 'UTC'),
    );
    return _connection!;
  }

  static Future<void> closeConnection() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
    }
  }
}
