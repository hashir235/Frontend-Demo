import 'package:flutter/material.dart';
import 'app.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the saved theme before the first frame. Doing it later would show
  // everyone a flash of light before dark takes over.
  await ThemeController.instance.load();
  runApp(const MyApp());
}
