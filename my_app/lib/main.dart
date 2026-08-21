import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'features/help_videos/video_links_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the saved theme before the first frame. Doing it later would show
  // everyone a flash of light before dark takes over.
  await ThemeController.instance.load();

  // Deliberately not awaited. The help links are read from what was saved last
  // time and then refreshed in the background, so a slow connection delays a
  // help button rather than the whole app opening.
  unawaited(VideoLinksStore.instance.load());

  runApp(const MyApp());
}
