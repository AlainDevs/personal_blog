import 'dart:io';

import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;

/// Loads and renders Mustache templates from disk.
class TemplateManager {
  /// Creates a template manager rooted at [basePath].
  TemplateManager(String basePath) : _basePath = basePath;

  final String _basePath;
  final Map<String, Template> _templateCache = {};

  /// Renders a template with the provided data.
  Future<String> render(String templateName, Map<String, dynamic> data) async {
    var template = _templateCache[templateName];

    if (template == null) {
      final file = File(p.join(_basePath, '$templateName.html'));
      if (!await file.exists()) {
        throw StateError('Template not found: $templateName.html');
      }
      final content = await file.readAsString();
      template = Template(content);
      _templateCache[templateName] = template;
    }

    return template.renderString(data);
  }
}
