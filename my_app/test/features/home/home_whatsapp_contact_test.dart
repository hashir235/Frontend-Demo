import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:my_app/features/auth/models/auth_user.dart';
import 'package:my_app/features/help_videos/video_links_store.dart';
import 'package:my_app/features/home/presentation/home_screen.dart';
import 'package:my_app/features/subscription/data/subscription_api_client.dart';
import 'package:my_app/shared/widgets/whatsapp_contact_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home's "Contact" button: the WhatsApp logo and the word, small, in the top
/// bar; one tap opens a WhatsApp chat with the office.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    VideoLinksStore.instance.setLinksForTest(<String, String>{});
  });

  testWidgets('in the top bar of Home, small, beside the bell', (
    WidgetTester tester,
  ) async {
    // A small phone.
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
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

    final Finder button = find.byKey(const Key('whatsapp_contact_button'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: button),
      findsOneWidget,
      reason: 'at the top, on every visit',
    );
    expect(find.descendant(of: button, matching: find.text('Contact')), findsOneWidget);
    expect(find.text('Quick AL'), findsOneWidget, reason: 'the title still fits');
    expect(find.byTooltip('Notifications'), findsOneWidget);

    // Seen, but not big: well inside the bar. (The test font draws every
    // letter as a full square, so the width here is wider than on a phone.)
    final Size size = tester.getSize(button);
    expect(size.height, lessThanOrEqualTo(34));
    expect(size.width, lessThan(150));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap opens a WhatsApp chat with the office', (
    WidgetTester tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              WhatsAppContactButton(
                openChat: (Uri chat) async {
                  opened = chat;
                  return true;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('whatsapp_contact_button')));
    await tester.pumpAndSettle();

    expect(opened, isNotNull);
    expect(opened!.host, 'wa.me');
    expect(opened!.path, '/923297590468');
    expect(opened!.queryParameters['text'], 'Assalam o Alaikum, Quick AL team.');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no WhatsApp on the phone: the number instead', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              WhatsAppContactButton(openChat: (Uri chat) async => false),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('whatsapp_contact_button')));
    await tester.pump();
    expect(
      find.text('WhatsApp could not be opened. Call or WhatsApp 0329 7590468.'),
      findsOneWidget,
    );
  });

  test('the message says who is writing, when signed in', () {
    const AuthUser user = AuthUser(
      id: 'u1',
      fullName: 'Ali Raza',
      email: 'ali@example.com',
    );
    expect(
      WhatsAppContactButton.draftMessage(user),
      'Assalam o Alaikum, Quick AL team.\nNaam: Ali Raza\nEmail: ali@example.com',
    );
    expect(
      WhatsAppContactButton.draftMessage(null),
      'Assalam o Alaikum, Quick AL team.',
    );
  });
}
