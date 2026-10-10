import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/support/support_contact.dart';
import 'package:my_app/features/auth/models/auth_user.dart';
import 'package:my_app/features/auth/presentation/account_blocked_screen.dart';

/// A switched-off shop gets one tap to the office on WhatsApp, the message
/// already written for them.
void main() {
  group('the message', () {
    test('says who is writing and what they want', () {
      final String draft = AccountBlockedScreen.draftMessage(
        const AuthUser(
          id: 'u1',
          fullName: 'Ahmed Glass',
          email: 'ahmed@shop.pk',
        ),
      );
      expect(draft, contains('Quick AL account band (paused) hai'));
      expect(draft, contains('dobara chalu'));
      expect(draft, contains('Naam: Ahmed Glass'));
      expect(draft, contains('Email: ahmed@shop.pk'));
    });

    test('refused at sign-in, with no session: no account lines', () {
      final String draft = AccountBlockedScreen.draftMessage(null);
      expect(draft, contains('Quick AL account band (paused) hai'));
      expect(draft, isNot(contains('Naam:')));
      expect(draft, isNot(contains('Email:')));
    });

    test('goes to the office number, typed in, spaces as %20', () {
      final Uri chat = SupportContact.whatsAppChat('Salam\nAccount: x y');
      expect(chat.host, 'wa.me');
      expect(chat.path, '/923297590468');
      expect(chat.toString(), contains('text=Salam%0AAccount%3A%20x%20y'));
      expect(chat.queryParameters['text'], 'Salam\nAccount: x y');
    });
  });

  group('the screen', () {
    Future<List<Uri>> open(WidgetTester tester, {bool opens = true}) async {
      final List<Uri> opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AccountBlockedScreen(
            message: 'Your invoice is due.',
            openChat: (Uri chat) async {
              opened.add(chat);
              return opens;
            },
          ),
        ),
      );
      return opened;
    }

    testWidgets('shows the owner message, the WhatsApp button and sign out', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('Your invoice is due.'), findsOneWidget);
      expect(find.text('Chat on WhatsApp'), findsOneWidget);
      expect(find.text(SupportContact.local), findsOneWidget);
      expect(find.byKey(const Key('blocked_sign_out_button')), findsOneWidget);
    });

    testWidgets('the button opens the chat with the message typed in', (
      WidgetTester tester,
    ) async {
      final List<Uri> opened = await open(tester);
      await tester.tap(find.byKey(const Key('blocked_whatsapp_button')));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single.path, '/923297590468');
      expect(
        opened.single.queryParameters['text'],
        contains('Quick AL account band (paused) hai'),
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('no WhatsApp on the phone: the number is given instead', (
      WidgetTester tester,
    ) async {
      await open(tester, opens: false);
      await tester.tap(find.byKey(const Key('blocked_whatsapp_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining(SupportContact.local), findsNWidgets(2));
      expect(
        find.textContaining('WhatsApp could not be opened'),
        findsOneWidget,
      );
    });
  });
}
