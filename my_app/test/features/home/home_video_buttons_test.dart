import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:my_app/features/help_videos/tutorial_videos.dart';
import 'package:my_app/features/help_videos/video_links_store.dart';
import 'package:my_app/features/home/presentation/home_screen.dart';
import 'package:my_app/features/subscription/data/subscription_api_client.dart';
import 'package:my_app/features/tutorial/tutorial_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every module card on Home carries the red "Watch" button for its whole
/// start-to-finish video, above the card's title.
void main() {
  const List<(String, String)> cards = <(String, String)>[
    (TutorialVideos.homeEstimation, 'Aluminium Estimation'),
    (TutorialVideos.homeFabrication, 'Aluminium Fabrication'),
    (TutorialVideos.homeGlass, 'Glass Fabrication'),
    (TutorialVideos.homeSettings, 'Settings'),
  ];

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final MockClient offline = MockClient(
      (http.Request request) async => http.Response('offline', 503),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          authClient: AuthHttpClient(offline),
          subscriptionClient: SubscriptionApiClient(
            baseUrl: 'http://test',
            httpClient: offline,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TutorialController.instance.markSeen();
    VideoLinksStore.instance.setLinksForTest(<String, String>{});
  });

  testWidgets('each module card has its Watch button, above its title', (
    WidgetTester tester,
  ) async {
    await openHome(tester);

    for (final (String key, String title) in cards) {
      final Finder button = find.byKey(Key('help_video_$key'));
      expect(button, findsOneWidget, reason: '$title has a Watch button');
      expect(
        tester.getTopLeft(button).dy,
        lessThan(tester.getTopLeft(find.text(title)).dy),
        reason: 'the button sits above "$title"',
      );
    }
  });

  testWidgets('a video not made yet says so, and does not open the module', (
    WidgetTester tester,
  ) async {
    await openHome(tester);

    await tester.tap(find.byKey(const Key('help_video_home.settings')));
    await tester.pump();

    expect(find.text('Is step ki video jald aa rahi hai.'), findsOneWidget);
    // Still on Home: the Watch button answered the tap, not the card.
    expect(find.text('Aluminium Estimation'), findsOneWidget);
  });
}
