import 'extra_charge.dart';

class BillRequest {
  final String? projectId;
  final double glassRatePerSqFt;
  final double laborRatePerSqFt;
  final double hardwareRatePerWindow;

  /// Hardware rate per window type, keyed by the window name the bill groups
  /// by. Empty when the job holds only one type, or for anything the engine
  /// should price at [hardwareRatePerWindow] instead.
  final Map<String, double> hardwareRateByType;

  /// Glazing rate per glass, keyed by the glass name the windows carry.
  ///
  /// Empty when the job is glazed in one glass throughout, or for anything the
  /// engine should price at [glassRatePerSqFt] instead.
  final Map<String, double> glassRateByColor;

  final double aluminiumDiscountPercent;
  final double aluminiumTotal;
  final double extraCharges;

  /// What [extraCharges] is made of, line by line, each saying what it is
  /// for. They add up to [extraCharges]. Empty when there are none, and for
  /// a bill whose charges came as one figure.
  final List<ExtraCharge> extraChargeItems;

  final double advancePaid;

  /// One gauge for the job, as the engine has always been sent. The bill
  /// prints [gauges].
  final String gauge;

  /// Every gauge the job's windows are made in, thinnest first; the bill and
  /// its PDF list them all, or the one.
  final List<String> gauges;

  final String aluminiumColor;
  final String glassColor;
  final String aluminiumCompany;
  final String projectName;
  final String projectLocation;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  const BillRequest({
    required this.projectId,
    required this.glassRatePerSqFt,
    required this.laborRatePerSqFt,
    required this.hardwareRatePerWindow,
    this.hardwareRateByType = const <String, double>{},
    this.glassRateByColor = const <String, double>{},
    required this.aluminiumDiscountPercent,
    required this.aluminiumTotal,
    required this.extraCharges,
    this.extraChargeItems = const <ExtraCharge>[],
    required this.advancePaid,
    required this.gauge,
    this.gauges = const <String>[],
    required this.aluminiumColor,
    required this.glassColor,
    this.aluminiumCompany = '',
    required this.projectName,
    required this.projectLocation,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'projectId': projectId,
      'glassRatePerSqFt': glassRatePerSqFt,
      'laborRatePerSqFt': laborRatePerSqFt,
      'hardwareRatePerWindow': hardwareRatePerWindow,
      // Left out entirely when empty rather than sent as {}, so an unchanged
      // single-rate bill goes over the wire exactly as it always did.
      if (hardwareRateByType.isNotEmpty)
        'hardwareRateByType': hardwareRateByType,
      if (glassRateByColor.isNotEmpty) 'glassRateByColor': glassRateByColor,
      'aluminiumDiscountPercent': aluminiumDiscountPercent,
      'aluminiumTotal': aluminiumTotal,
      'extraCharges': extraCharges,
      // The engine works with the total; the server keeps these with the
      // bill, for the screen and the PDF.
      if (extraChargeItems.isNotEmpty)
        'extraChargeItems': <Map<String, Object?>>[
          for (final ExtraCharge item in extraChargeItems) item.toJson(),
        ],
      'advancePaid': advancePaid,
      'gauge': gauge,
      if (gauges.isNotEmpty) 'gauges': gauges,
      'aluminiumColor': aluminiumColor,
      'glassColor': glassColor,
      'aluminiumCompany': aluminiumCompany,
      'projectName': projectName,
      'projectLocation': projectLocation,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
    };
  }
}
