import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';

// Configure a pipeline that logs requests.
final _handler = const Pipeline()
    .addMiddleware(logRequests())
    .addHandler(createStaticHandler('web', defaultDocument: 'index.html'));

void main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(_handler, ip, port);
  print('Server listening on port ${server.port}');
}