import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_card_button.dart';
import 'estimation_menu_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Dashboard'), centerTitle: true),
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
              alignment: Alignment(-1.1, -1.2),
              size: 220,
              color: AppTheme.sky,
            ),
            const _GlowCircle(
              alignment: Alignment(1.1, -0.6),
              size: 180,
              color: AppTheme.violet,
            ),
            const _GlowCircle(
              alignment: Alignment(0.8, 1.1),
              size: 240,
              color: AppTheme.ice,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a module to continue',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          PrimaryCardButton(
                            icon: Icons.calculate_outlined,
                            title: 'Estimation',
                            subtitle: 'Create cost & material estimates',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EstimationMenuScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          PrimaryCardButton(
                            icon: Icons.construction_outlined,
                            title: 'Fabrication',
                            subtitle: 'Production & cutting details',
                            accent: AppTheme.sky,
                            onTap: () => _showComingSoon(context),
                          ),
                          const SizedBox(height: 18),
                          PrimaryCardButton(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            subtitle: 'App & system configuration',
                            accent: AppTheme.slate,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
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
