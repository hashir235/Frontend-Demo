import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../tutorial/urdu_text.dart';

/// Which language the payment instructions are shown in.
///
/// Three, because the people paying are not one kind of reader: some are
/// comfortable in English, plenty read Roman Urdu fastest, and some want
/// proper Urdu script. Money instructions are the worst place to make someone
/// guess, so they pick.
enum PaymentLanguage { romanUrdu, english, urdu }

extension PaymentLanguageLabel on PaymentLanguage {
  String get label => switch (this) {
    PaymentLanguage.romanUrdu => 'Roman Urdu',
    PaymentLanguage.english => 'English',
    PaymentLanguage.urdu => 'اردو',
  };

  bool get isUrduScript => this == PaymentLanguage.urdu;
}

/// The account money is sent to. Kept here rather than fetched so the details
/// cannot go blank if the network is down mid-payment -- the one moment a user
/// must not be left staring at an empty card.
class BankAccountDetails {
  static const String bankName = 'Allied Bank';
  static const String accountTitle = 'MMH tech';
  static const String accountNumber = '0010055500520050';
  static const String iban = 'PK44ABPA0010055500520050';

  /// Shown in full international form so it works from any phone, including
  /// one roaming abroad. 92 is Pakistan; the same number the website uses.
  static const String whatsApp = '+92 329 7590468';

  /// wa.me wants digits only, no plus and no spaces.
  static const String whatsAppUrl = 'https://wa.me/923297590468';
}

/// Everything the local-payment section says, per language.
class _PaymentCopy {
  final String sectionTitle;
  final String sectionIntro;
  final String bankHeading;
  final String bankLabel;
  final String titleLabel;
  final String accountLabel;
  final String ibanLabel;
  final String howHeading;
  final List<String> steps;
  final String warningHeading;
  final String warningBody;
  final String mustFillHeading;
  final String mustFillBody;
  final String formHeading;
  final String methodLabel;
  final String referenceLabel;
  final String nameLabel;
  final String phoneLabel;
  final String notesLabel;
  final String copied;
  final String whatsAppLabel;

  const _PaymentCopy({
    required this.sectionTitle,
    required this.sectionIntro,
    required this.bankHeading,
    required this.bankLabel,
    required this.titleLabel,
    required this.accountLabel,
    required this.ibanLabel,
    required this.howHeading,
    required this.steps,
    required this.warningHeading,
    required this.warningBody,
    required this.mustFillHeading,
    required this.mustFillBody,
    required this.formHeading,
    required this.methodLabel,
    required this.referenceLabel,
    required this.nameLabel,
    required this.phoneLabel,
    required this.notesLabel,
    required this.copied,
    required this.whatsAppLabel,
  });
}

const _PaymentCopy _romanUrdu = _PaymentCopy(
  sectionTitle: 'Local payment (Bank / JazzCash / EasyPaisa)',
  sectionIntro:
      'Apni bank app ya wallet se paise bhejein, phir neeche details bhar kar '
      'Submit dabayein.',
  bankHeading: 'Paise yahan bhejein',
  bankLabel: 'Bank',
  titleLabel: 'Account ka naam',
  accountLabel: 'Account number',
  ibanLabel: 'IBAN',
  howHeading: 'Kaise bhejein',
  steps: <String>[
    'Apni bank ki application ya wallet kholein — jaise JazzCash ya EasyPaisa.',
    'Bank mein "Allied Bank" select karein.',
    'Upar wala account number likhein. Account ka naam "MMH tech" apne aap '
        'show ho jayega — yehi tasdeeq hai ke sahi jagah ja raha hai.',
    'Aap ne jo plan chuna hai, bilkul wohi amount khud likh kar bhejein.',
    'Paise bhejne ke baad neeche transfer ki details bharein.',
    'Screenshot le kar WhatsApp par bhej dein: ${BankAccountDetails.whatsApp}',
    'Submit ka button dabayein aur intezar karein.',
    '24 ghante ke andar payment confirm hote hi app ka access mil jayega.',
  ],
  warningHeading: 'Khabardar',
  warningBody:
      'Ghalat amount bhejne par aap ki request zaya ho sakti hai. Amount dhyan '
      'se dekh kar bhejein.',
  mustFillHeading: 'Ye zaroori hai',
  mustFillBody:
      'Sirf paise bhej dena kaafi nahi. Neeche wali details bharna zaroori hai '
      '— warna hamein pata hi nahi chalega ke paise kis ne bheje.',
  formHeading: 'Transfer ki details',
  methodLabel: 'Kis se bheja',
  referenceLabel: 'Transfer ID / reference',
  nameLabel: 'Bhejne wale ka naam',
  phoneLabel: 'Phone number',
  notesLabel: 'Koi aur baat (optional)',
  copied: 'Copy ho gaya',
  whatsAppLabel: 'WhatsApp',
);

const _PaymentCopy _english = _PaymentCopy(
  sectionTitle: 'Local payment (Bank / JazzCash / EasyPaisa)',
  sectionIntro:
      'Send the money from your bank app or wallet, then fill in the details '
      'below and press Submit.',
  bankHeading: 'Send the money here',
  bankLabel: 'Bank',
  titleLabel: 'Account title',
  accountLabel: 'Account number',
  ibanLabel: 'IBAN',
  howHeading: 'How to send it',
  steps: <String>[
    'Open your bank application or a wallet such as JazzCash or EasyPaisa.',
    'Choose "Allied Bank" as the bank.',
    'Enter the account number above. The name "MMH tech" will appear by '
        'itself — that is your confirmation it is going to the right place.',
    'Type the exact amount of the plan you selected.',
    'Once the money is sent, fill in the transfer details below.',
    'Take a screenshot and send it on WhatsApp: ${BankAccountDetails.whatsApp}',
    'Press Submit and wait.',
    'Your access opens as soon as the payment is confirmed, within 24 hours.',
  ],
  warningHeading: 'Warning',
  warningBody:
      'Sending the wrong amount can waste your request. Check the amount '
      'carefully before you send it.',
  mustFillHeading: 'This part is required',
  mustFillBody:
      'Sending the money is not enough on its own. You must fill in the details '
      'below, otherwise we have no way of knowing the payment was yours.',
  formHeading: 'Transfer details',
  methodLabel: 'Sent from',
  referenceLabel: 'Transfer ID / reference',
  nameLabel: 'Payer name',
  phoneLabel: 'Phone number',
  notesLabel: 'Anything else (optional)',
  copied: 'Copied',
  whatsAppLabel: 'WhatsApp',
);

const _PaymentCopy _urdu = _PaymentCopy(
  sectionTitle: 'مقامی ادائیگی (بینک / جاز کیش / ایزی پیسہ)',
  sectionIntro:
      'اپنی بینک ایپ یا والٹ سے رقم بھیجیں، پھر نیچے تفصیل بھر کر "جمع کریں" '
      'دبائیں۔',
  bankHeading: 'رقم یہاں بھیجیں',
  bankLabel: 'بینک',
  titleLabel: 'اکاؤنٹ کا نام',
  accountLabel: 'اکاؤنٹ نمبر',
  ibanLabel: 'آئی بین',
  howHeading: 'کیسے بھیجیں',
  steps: <String>[
    'اپنی بینک کی ایپلیکیشن یا والٹ کھولیں — جیسے جاز کیش یا ایزی پیسہ۔',
    'بینک میں "Allied Bank" چنیں۔',
    'اوپر لکھا اکاؤنٹ نمبر درج کریں۔ اکاؤنٹ کا نام "MMH tech" خود بخود آ جائے '
        'گا — یہی آپ کی تصدیق ہے کہ رقم صحیح جگہ جا رہی ہے۔',
    'آپ نے جو پلان چنا ہے، بالکل وہی رقم خود لکھ کر بھیجیں۔',
    'رقم بھیجنے کے بعد نیچے ٹرانسفر کی تفصیل بھریں۔',
    'اسکرین شاٹ لے کر واٹس ایپ پر بھیج دیں: ${BankAccountDetails.whatsApp}',
    '"جمع کریں" کا بٹن دبائیں اور انتظار کریں۔',
    '24 گھنٹے کے اندر ادائیگی کی تصدیق ہوتے ہی ایپ کھل جائے گی۔',
  ],
  warningHeading: 'خبردار',
  warningBody:
      'غلط رقم بھیجنے پر آپ کی درخواست ضائع ہو سکتی ہے۔ رقم غور سے دیکھ کر '
      'بھیجیں۔',
  mustFillHeading: 'یہ ضروری ہے',
  mustFillBody:
      'صرف رقم بھیج دینا کافی نہیں۔ نیچے والی تفصیل بھرنا ضروری ہے — ورنہ ہمیں '
      'پتہ ہی نہیں چلے گا کہ رقم کس نے بھیجی۔',
  formHeading: 'ٹرانسفر کی تفصیل',
  methodLabel: 'کس سے بھیجا',
  referenceLabel: 'ٹرانسفر آئی ڈی',
  nameLabel: 'بھیجنے والے کا نام',
  phoneLabel: 'فون نمبر',
  notesLabel: 'کوئی اور بات (اختیاری)',
  copied: 'کاپی ہو گیا',
  whatsAppLabel: 'واٹس ایپ',
);

_PaymentCopy _copyFor(PaymentLanguage language) => switch (language) {
  PaymentLanguage.romanUrdu => _romanUrdu,
  PaymentLanguage.english => _english,
  PaymentLanguage.urdu => _urdu,
};

/// The whole local-payment block: language switch, account details, the steps,
/// the warning, and the form that has to be filled before Submit turns on.
class LocalPaymentSection extends StatelessWidget {
  final PaymentLanguage language;
  final ValueChanged<PaymentLanguage> onLanguageChanged;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final TextEditingController referenceController;
  final TextEditingController payerNameController;
  final TextEditingController payerPhoneController;
  final TextEditingController notesController;

  const LocalPaymentSection({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.referenceController,
    required this.payerNameController,
    required this.payerPhoneController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    final _PaymentCopy copy = _copyFor(language);
    final bool rtl = language.isUrduScript;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, copy.sectionTitle, rtl),
        const SizedBox(height: AppTheme.space2),
        _body(context, copy.sectionIntro, rtl),
        const SizedBox(height: AppTheme.space5),
        _LanguagePicker(selected: language, onChanged: onLanguageChanged),
        const SizedBox(height: AppTheme.space5),
        _BankCard(copy: copy, rtl: rtl),
        const SizedBox(height: AppTheme.space5),
        _StepsCard(copy: copy, rtl: rtl),
        const SizedBox(height: AppTheme.space5),
        _CalloutCard(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.warning,
          heading: copy.warningHeading,
          body: copy.warningBody,
          rtl: rtl,
        ),
        const SizedBox(height: AppTheme.space4),
        _CalloutCard(
          icon: Icons.assignment_turned_in_rounded,
          color: AppTheme.royalBlue,
          heading: copy.mustFillHeading,
          body: copy.mustFillBody,
          rtl: rtl,
        ),
        const SizedBox(height: AppTheme.space5),
        _heading(context, copy.formHeading, rtl, size: 17),
        const SizedBox(height: AppTheme.space4),
        // The form itself stays left-to-right whatever the chosen language:
        // transfer ids, names and phone numbers are typed in Latin digits, and
        // an RTL field would put the cursor on the wrong side of them.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: InputDecoration(labelText: copy.methodLabel),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'bank_transfer',
                    child: _MethodOption(
                      icon: Icons.account_balance_rounded,
                      label: 'Bank transfer',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'jazzcash',
                    child: _MethodOption(
                      asset: 'assets/images/jazzcash_logo.png',
                      label: 'JazzCash',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'easypaisa',
                    child: _MethodOption(
                      asset: 'assets/images/easypaisa_logo.png',
                      label: 'EasyPaisa',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'other_wallet',
                    child: _MethodOption(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Other wallet',
                    ),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) onPaymentMethodChanged(value);
                },
              ),
              const SizedBox(height: AppTheme.space4),
              TextField(
                controller: referenceController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '${copy.referenceLabel} *',
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              TextField(
                controller: payerNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '${copy.nameLabel} *',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              TextField(
                controller: payerPhoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '${copy.phoneLabel} *',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(labelText: copy.notesLabel),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: AppTheme.softPanelDecoration(radius: AppTheme.radiusLg),
      child: rtl
          ? Directionality(textDirection: TextDirection.rtl, child: content)
          : content,
    );
  }

  Widget _heading(
    BuildContext context,
    String text,
    bool rtl, {
    double size = 19,
  }) {
    if (rtl) {
      return Text(text, style: UrduText.heading(fontSize: size));
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        fontSize: size,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _body(BuildContext context, String text, bool rtl) {
    if (rtl) {
      return Text(text, style: UrduText.body(fontSize: 16));
    }
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _LanguagePicker extends StatelessWidget {
  final PaymentLanguage selected;
  final ValueChanged<PaymentLanguage> onChanged;

  const _LanguagePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Always laid out left-to-right so the buttons do not jump around when the
    // user switches into Urdu.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.translate_rounded,
            size: 19,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: SegmentedButton<PaymentLanguage>(
              segments: PaymentLanguage.values
                  .map(
                    (PaymentLanguage value) => ButtonSegment<PaymentLanguage>(
                      value: value,
                      label: Text(
                        value.label,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  )
                  .toList(growable: false),
              selected: <PaymentLanguage>{selected},
              showSelectedIcon: false,
              onSelectionChanged: (Set<PaymentLanguage> picked) =>
                  onChanged(picked.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// The account details, deliberately the loudest thing on the screen: these are
/// the numbers someone is about to type into a banking app, and a misread digit
/// costs them real money.
/// One entry in the method picker. JazzCash and EasyPaisa carry their own
/// logos so the list is scannable at a glance rather than four lines of text.
class _MethodOption extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final String label;

  const _MethodOption({this.asset, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 34,
          height: 22,
          child: asset != null
              ? Image.asset(asset!, fit: BoxFit.contain, semanticLabel: label)
              : Icon(icon, size: 19, color: AppTheme.royalBlue),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _BankCard extends StatelessWidget {
  final _PaymentCopy copy;
  final bool rtl;

  const _BankCard({required this.copy, required this.rtl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: AppTheme.royalBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.royalBlue.withValues(alpha: 0.28),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.account_balance_rounded,
                color: AppTheme.royalBlue,
                size: 22,
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: rtl
                    ? Text(
                        copy.bankHeading,
                        style: UrduText.heading(fontSize: 18),
                      )
                    : Text(
                        copy.bankHeading,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.royalBlue,
                            ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          _Field(
            label: copy.bankLabel,
            value: BankAccountDetails.bankName,
            copiedLabel: copy.copied,
            rtl: rtl,
          ),
          _Field(
            label: copy.titleLabel,
            value: BankAccountDetails.accountTitle,
            copiedLabel: copy.copied,
            rtl: rtl,
          ),
          _Field(
            label: copy.accountLabel,
            value: BankAccountDetails.accountNumber,
            copiedLabel: copy.copied,
            rtl: rtl,
            emphasise: true,
          ),
          _Field(
            label: copy.ibanLabel,
            value: BankAccountDetails.iban,
            copiedLabel: copy.copied,
            rtl: rtl,
            emphasise: true,
          ),
          const Divider(height: AppTheme.space6),
          // The screenshot step sends people here, so it opens the chat
          // directly rather than making them copy digits into another app.
          _Field(
            label: copy.whatsAppLabel,
            value: BankAccountDetails.whatsApp,
            copiedLabel: copy.copied,
            rtl: rtl,
            openUrl: BankAccountDetails.whatsAppUrl,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final String copiedLabel;
  final bool rtl;
  final bool emphasise;

  /// When set, the value gets a button that opens this instead of only copying.
  final String? openUrl;

  const _Field({
    required this.label,
    required this.value,
    required this.copiedLabel,
    required this.rtl,
    this.emphasise = false,
    this.openUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          rtl
              ? Text(label, style: UrduText.caption())
              : Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
          const SizedBox(height: 3),
          // The value itself is always left-to-right: account numbers and IBANs
          // read the same in every language, and flipping them would be a
          // genuine hazard.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: emphasise ? 21 : 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      letterSpacing: emphasise ? 0.8 : 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 19),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$copiedLabel: $value'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                if (openUrl != null)
                  IconButton(
                    tooltip: 'Open',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: 19,
                      color: AppTheme.royalBlue,
                    ),
                    onPressed: () async {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      bool opened = false;
                      try {
                        opened = await launchUrl(
                          Uri.parse(openUrl!),
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {
                        opened = false;
                      }
                      if (!opened) {
                        // No WhatsApp installed -- the number is right there to
                        // copy, so say so rather than failing silently.
                        messenger.showSnackBar(
                          SnackBar(content: Text('WhatsApp: $value')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  final _PaymentCopy copy;
  final bool rtl;

  const _StepsCard({required this.copy, required this.rtl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        rtl
            ? Text(copy.howHeading, style: UrduText.heading(fontSize: 18))
            : Text(
                copy.howHeading,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
        const SizedBox(height: AppTheme.space4),
        ...List<Widget>.generate(copy.steps.length, (int index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.royalBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: rtl
                      ? Text(
                          copy.steps[index],
                          style: UrduText.body(fontSize: 16),
                        )
                      : Text(
                          copy.steps[index],
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CalloutCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String heading;
  final String body;
  final bool rtl;

  const _CalloutCard({
    required this.icon,
    required this.color,
    required this.heading,
    required this.body,
    required this.rtl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.34), width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                rtl
                    ? Text(heading, style: UrduText.heading(fontSize: 17))
                    : Text(
                        heading,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                const SizedBox(height: 4),
                rtl
                    ? Text(body, style: UrduText.body(fontSize: 15))
                    : Text(
                        body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
