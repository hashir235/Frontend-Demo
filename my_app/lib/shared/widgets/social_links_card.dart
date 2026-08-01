import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'section_surface_card.dart';

/// "Learn & Connect" card — the YouTube how-to playlist + Facebook page, shown
/// on both the sign-in screen and Home so every user (even before they take a
/// plan) can reach the guides and follow the social pages.
class SocialLinksCard extends StatelessWidget {
  const SocialLinksCard({super.key});

  // Same links that live on the Quick AL website.
  static const String _youtubeUrl =
      'https://www.youtube.com/playlist?list=PLHV3ATsOdETE';
  static const String _facebookUrl =
      'https://www.facebook.com/profile.php?id=61590000736332';

  Future<void> _launch(BuildContext context, String url) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the link. Please try again.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the link. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionSurfaceCard(
      title: 'Learn & Connect',
      subtitle: 'Watch step-by-step guides and follow Quick AL for updates.',
      child: Column(
        children: <Widget>[
          _SocialTile(
            icon: Icons.smart_display_rounded,
            iconColor: const Color(0xFFFF0000),
            title: 'How to Use',
            subtitle: 'Step-by-step video guides on YouTube',
            onTap: () => _launch(context, _youtubeUrl),
          ),
          const SizedBox(height: AppTheme.space4),
          _SocialTile(
            icon: Icons.facebook,
            iconColor: const Color(0xFF1877F2),
            title: 'Follow us on Facebook',
            subtitle: 'Updates, tips, and announcements',
            onTap: () => _launch(context, _facebookUrl),
          ),
        ],
      ),
    );
  }
}

/// "How to pay the bill" — shown on the paywall and in Settings > Payment &
/// Renewal, so a user who is stuck at the payment step can watch the walkthrough
/// without leaving the app to go looking for it.
class PaymentHelpCard extends StatelessWidget {
  const PaymentHelpCard({super.key});

  // TODO: swap these for the specific "how to pay the bill" video links once
  // they are recorded. Until then they open the general channel and page, so
  // the buttons still lead somewhere useful.
  static const String _youtubeUrl =
      'https://www.youtube.com/playlist?list=PLHV3ATsOdETE';
  static const String _facebookUrl =
      'https://www.facebook.com/profile.php?id=61590000736332';

  @override
  Widget build(BuildContext context) {
    return SectionSurfaceCard(
      title: 'How to pay the bill',
      subtitle: 'Watch the payment walkthrough if you get stuck.',
      child: Column(
        children: <Widget>[
          _SocialTile(
            icon: Icons.smart_display_rounded,
            iconColor: const Color(0xFFFF0000),
            title: 'Watch on YouTube',
            subtitle: 'Step-by-step payment guide',
            onTap: () => _launchExternal(context, _youtubeUrl),
          ),
          const SizedBox(height: AppTheme.space4),
          _SocialTile(
            icon: Icons.facebook,
            iconColor: const Color(0xFF1877F2),
            title: 'Watch on Facebook',
            subtitle: 'Same guide on our Facebook page',
            onTap: () => _launchExternal(context, _facebookUrl),
          ),
        ],
      ),
    );
  }
}

/// Opens [url] outside the app, telling the user if nothing could handle it.
Future<void> _launchExternal(BuildContext context, String url) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final bool opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the link. Please try again.')),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the link. Please try again.')),
    );
  }
}

class _SocialTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SocialTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: AppTheme.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
