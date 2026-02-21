import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primary_card_button.dart';
import 'window_navigation_screen.dart';

class EstimationMenuScreen extends StatelessWidget {
  const EstimationMenuScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon')));
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
                            title: 'Add Windows',
                            subtitle: 'Browse and select window categories',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WindowNavigationScreen.root(),
                                ),
                              );
                            },
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
