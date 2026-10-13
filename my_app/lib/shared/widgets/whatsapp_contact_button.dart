import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/support/support_contact.dart';
import '../../features/auth/models/auth_user.dart';
import '../../features/auth/state/auth_controller.dart';

/// A small "Contact" button with the WhatsApp logo: one tap and the shop is
/// in a WhatsApp chat with the Quick AL office (Hashir, Oct 2026).
///
/// Kept small -- it sits in Home's top bar beside the bell, where it is seen
/// on every visit without taking room from the work -- and in WhatsApp's own
/// green, so it reads as WhatsApp before the word is read.
class WhatsAppContactButton extends StatelessWidget {
  const WhatsAppContactButton({super.key, this.openChat});

  /// Opens the chat. Injected in tests; the app hands it to WhatsApp.
  final Future<bool> Function(Uri chat)? openChat;

  /// WhatsApp's green, a shade deeper than the logo's so the white word on
  /// it stays readable.
  static const Color green = Color(0xFF1DA851);

  /// What the chat opens with, ready to send or change: a greeting, and who
  /// is writing, so the office can find the account without asking.
  static String draftMessage(AuthUser? user) {
    final String name = user?.fullName.trim() ?? '';
    final String email = user?.email.trim() ?? '';
    return <String>[
      'Assalam o Alaikum, Quick AL team.',
      if (name.isNotEmpty) 'Naam: $name',
      if (email.isNotEmpty) 'Email: $email',
    ].join('\n');
  }

  static Future<bool> _openInWhatsApp(Uri chat) async {
    try {
      return await launchUrl(chat, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _open(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Uri chat = SupportContact.whatsAppChat(
      draftMessage(AuthController.instance.currentUser),
    );
    final bool opened = await (openChat ?? _openInWhatsApp)(chat);
    if (!opened) {
      // No WhatsApp on this phone: the number is still what they need.
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'WhatsApp could not be opened. Call or WhatsApp '
            '${SupportContact.local}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const StadiumBorder shape = StadiumBorder();
    return Center(
      child: Tooltip(
        message: 'Contact us on WhatsApp',
        child: Material(
          color: green,
          shape: shape,
          elevation: 1,
          child: InkWell(
            key: const Key('whatsapp_contact_button'),
            customBorder: shape,
            onTap: () => _open(context),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(10, 6, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
