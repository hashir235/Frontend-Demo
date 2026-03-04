import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../settings/state/app_settings.dart';
import '../state/estimate_session_store.dart';
import 'window_navigation_screen.dart';

class EstimationMenuScreen extends StatelessWidget {
  const EstimationMenuScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  Future<_ProjectDraft?> _showProjectDialog(BuildContext context) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController projectNameController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    final _ProjectDraft? result = await showDialog<_ProjectDraft>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        String? requiredValidator(String? value) {
          if ((value ?? '').trim().isEmpty) {
            return 'Required';
          }
          return null;
        }

        InputDecoration decoration(String label) {
          return InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          );
        }

        return AlertDialog(
          title: const Text('Create Project'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: projectNameController,
                  autofocus: true,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(100),
                  ],
                  decoration: decoration('Project Name *'),
                  validator: requiredValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(100),
                  ],
                  decoration: decoration('Location *'),
                  validator: requiredValidator,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final FormState? form = formKey.currentState;
                if (form == null || !form.validate()) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _ProjectDraft(
                    projectName: projectNameController.text.trim(),
                    projectLocation: locationController.text.trim(),
                  ),
                );
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    projectNameController.dispose();
    locationController.dispose();
    return result;
  }

  Future<void> _handleCreateProject(BuildContext context) async {
    final _ProjectDraft? draft = await _showProjectDialog(context);
    if (draft == null || !context.mounted) {
      return;
    }

    final EstimateSessionStore session = EstimateSessionStore(
      projectName: draft.projectName,
      projectLocation: draft.projectLocation,
      numberingMode: AppSettings.instance.numberingMode,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WindowNavigationScreen.root(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Estimation'), centerTitle: true),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.ice, AppTheme.mist],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const _GlowCircle(
              alignment: Alignment(-1.2, -1.0),
              size: 200,
              color: AppTheme.violet,
            ),
            const _GlowCircle(
              alignment: Alignment(1.1, 0.8),
              size: 240,
              color: AppTheme.sky,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimation tools',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start a new window estimate or review history',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          PrimaryCardButton(
                            icon: Icons.add_box_outlined,
                            title: 'Create Project',
                            subtitle: 'Set project details and browse windows',
                            onTap: () => _handleCreateProject(context),
                          ),
                          const SizedBox(height: 18),
                          PrimaryCardButton(
                            icon: Icons.history_rounded,
                            title: 'History',
                            subtitle: 'See saved estimates and status',
                            accent: AppTheme.sky,
                            onTap: () => _showComingSoon(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDraft {
  final String projectName;
  final String projectLocation;

  const _ProjectDraft({
    required this.projectName,
    required this.projectLocation,
  });
}

class _GlowCircle extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _GlowCircle({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
