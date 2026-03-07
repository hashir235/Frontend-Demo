import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/primary_card_button.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../estimation/presentation/estimation_menu_screen.dart';
import '../../fabrication/presentation/fabrication_menu_screen.dart';
import '../../settings/presentation/settings_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Quick Aluminium')),
      body: AppScreenShell(
        child: ListView(
          children: <Widget>[
            AppHeroHeader(
              eyebrow: 'QUICK ALUMINIUM',
              title: 'Premium estimation and fabrication workspace',
              subtitle:
                  'A refined business tool for aluminium windows, fabrication operations, and project settings.',
              trailing: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            SectionSurfaceCard(
              title: 'Workspace',
              subtitle:
                  'Choose the module that matches the current project phase.',
              child: Column(
                children: <Widget>[
                  PrimaryCardButton(
                    icon: Icons.calculate_rounded,
                    title: 'Estimation',
                    subtitle:
                        'Window selection, review flow, optimization, rates, material table, and billing.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EstimationMenuScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  PrimaryCardButton(
                    icon: Icons.construction_rounded,
                    title: 'Fabrication',
                    subtitle:
                        'Production-ready windows, cutting workflow, glass reporting, and fabrication outputs.',
                    accent: AppTheme.tealAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FabricationMenuScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space5),
                  PrimaryCardButton(
                    icon: Icons.settings_suggest_rounded,
                    title: 'Settings',
                    subtitle:
                        'General, estimation, and fabrication configuration with structured controls.',
                    accent: AppTheme.amberAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    label: 'Modern visual system',
                    value: '2026',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: MetricCard(
                    label: 'Modules',
                    value: '3',
                    icon: Icons.dashboard_customize_rounded,
                    accent: AppTheme.tealAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
