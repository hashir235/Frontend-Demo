import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'tutorial_videos.dart';

/// The "watch how this works" button that sits in a screen's header.
///
/// Small, because it must not compete with the screen itself — but
/// unmistakably YouTube: the red rounded rectangle with a white triangle is a
/// shape people recognise without reading, which is the whole point for users
/// who would rather be shown than told.
class HelpVideoButton extends StatelessWidget {
  /// A key from [TutorialVideos].
  final String videoKey;

  const HelpVideoButton({super.key, required this.videoKey});

  Future<void> _open(BuildContext context) async {
    final String link = TutorialVideos.linkFor(videoKey);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (link.trim().isEmpty) {
      // Says so rather than opening nothing. A button that appears to do
      // nothing reads as a broken app.
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Is step ki video jald aa rahi hai.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final Uri uri = Uri.parse(link);
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Video nahi khul saki.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Watch the video for this step',
      child: Tooltip(
        message: 'Watch how this works',
        child: InkWell(
          key: Key('help_video_$videoKey'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _YouTubeGlyph(),
                const SizedBox(width: 6),
                Text(
                  'Watch',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// YouTube's mark, drawn rather than shipped as an image.
///
/// Keeps it crisp at any size and adds nothing to the download — and the shape
/// is what carries the meaning, so it has to be the right one.
class _YouTubeGlyph extends StatelessWidget {
  const _YouTubeGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Center(
        child: Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
      ),
    );
  }
}
