import 'dart:io';
import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;

class TemplateManager {
  final String _basePath;
  final Map<String, Template> _templateCache = {};

  TemplateManager(String basePath) : _basePath = basePath;

  Future<String> render(String templateName, Map<String, dynamic> data) async {
    Template? template = _templateCache[templateName];

    if (template == null) {
      final file = File(p.join(_basePath, '$templateName.html'));
      if (!await file.exists()) {
        throw Exception('Template not found: $templateName.html');
      }
      final content = await file.readAsString();
      template = Template(content, htmlEscapeValues: false);
      _templateCache[templateName] = template;
    }

    return template.renderString(data);
  }
}