import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The subscription screen shows these two logos so a JazzCash or EasyPaisa
/// user spots the option they are going to use. A missing pubspec entry does
/// not fail the build -- it fails at runtime, on the paywall, for a user who
/// is trying to pay. This catches it here instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<String> paymentMarks = <String>[
    'assets/images/jazzcash_logo.png',
    'assets/images/easypaisa_logo.png',
  ];

  for (final String asset in paymentMarks) {
    test('$asset is bundled and is a PNG', () async {
      final ByteData data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: '$asset is empty');

      // PNG magic number, so a truncated or wrong-format file is caught too.
      final Uint8List head = data.buffer.asUint8List(0, 8);
      expect(
        head,
        equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        reason: '$asset is not a PNG',
      );
    });
  }
}
