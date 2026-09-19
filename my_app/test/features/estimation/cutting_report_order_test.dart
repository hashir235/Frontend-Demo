import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/cutting_report.dart';

/// The cutting list shows the longest bars first, the way a cutter works
/// through the rack.
void main() {
  CuttingReportSection section(List<Map<String, dynamic>> groups) =>
      CuttingReportSection.fromJson(<String, dynamic>{
        'name': 'DC30F',
        'summary': <String, dynamic>{
          'usedLengths': <double>[12, 19, 16],
          'totalLength': 47,
        },
        'groups': groups,
      });

  Map<String, dynamic> bar(double length, String wastage) => <String, dynamic>{
    'stockLenFt': length,
    'wastageDisplay': wastage,
    'cuts': <dynamic>[],
  };

  test('bars are listed longest first, equal lengths in their own order', () {
    final CuttingReportSection s = section(<Map<String, dynamic>>[
      bar(16, 'a'),
      bar(19, 'b'),
      bar(12, 'c'),
      bar(19, 'd'),
      bar(16, 'e'),
    ]);

    expect(
      s.groupsLongestFirst.map((CuttingReportGroup g) => g.wastageDisplay),
      <String>['b', 'd', 'a', 'e', 'c'],
    );
  });

  test('the report itself keeps the order the server sent', () {
    final CuttingReportSection s = section(<Map<String, dynamic>>[
      bar(16, 'a'),
      bar(19, 'b'),
    ]);
    s.groupsLongestFirst;
    expect(
      s.groups.map((CuttingReportGroup g) => g.wastageDisplay),
      <String>['a', 'b'],
    );
  });

  test('the summary names the lengths in the same order', () {
    final CuttingReportSection s = section(<Map<String, dynamic>>[]);
    expect(s.summary!.usedLengthsLongestFirst, <double>[19, 16, 12]);
    expect(s.summary!.usedLengths, <double>[12, 19, 16]);
  });
}
