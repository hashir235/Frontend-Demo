import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/auth_http_client.dart';

/// A glass job that has just been created on the server.
class NewGlassProject {
  final String projectId;
  final String projectName;
  final String projectLocation;

  const NewGlassProject({
    required this.projectId,
    required this.projectName,
    required this.projectLocation,
  });
}

/// Asks for a name and a site, then creates the glass project.
///
/// Deliberately smaller than the aluminium one: a glass job has no window
/// catalogue and no session to reset behind it, so there is nothing else to
/// ask before the sizes start going in.
Future<NewGlassProject?> showNewGlassProjectDialog(BuildContext context) {
  return showDialog<NewGlassProject>(
    context: context,
    builder: (BuildContext ctx) => const _NewGlassProjectDialog(),
  );
}

class _NewGlassProjectDialog extends StatefulWidget {
  const _NewGlassProjectDialog();

  @override
  State<_NewGlassProjectDialog> createState() => _NewGlassProjectDialogState();
}

class _NewGlassProjectDialogState extends State<_NewGlassProjectDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _location = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final http.Response response = await AuthHttpClient()
          .post(
            ApiConfig.buildUri('/api/projects'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, Object?>{
              'context': 'glass',
              'projectName': _name.text.trim(),
              'projectLocation': _location.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final Object? decoded = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic>) {
        throw Exception('create failed');
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        NewGlassProject(
          projectId: decoded['id'] as String? ?? '',
          projectName: _name.text.trim(),
          projectLocation: _location.text.trim(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not create the project. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New glass project'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Project name'),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a project name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Location'),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a location' : null,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
