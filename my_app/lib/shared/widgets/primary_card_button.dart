import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/help_videos/help_video_button.dart';

class PrimaryCardButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? accent;

  /// A key from `TutorialVideos`. When set, the red "Watch" button sits above
  /// the title, and tapping it opens the video rather than the card.
  final String? videoKey;

  const PrimaryCardButton({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.accent,
    this.videoKey,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = accent ?? AppTheme.royalBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFEFFFF), Color(0xFFF4F8FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.line),
            boxShadow: AppTheme.softShadow(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 32),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (videoKey != null) ...<Widget>[
                        HelpVideoButton(videoKey: videoKey!),
                        const SizedBox(height: AppTheme.space2),
                      ],
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
