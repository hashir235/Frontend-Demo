import 'window_review_item.dart';

class SavedProjectSummary {
  final String id;
  final String context;
  final String projectName;
  final String projectLocation;
  final String status;
  final int windowCount;
  final DateTime? updatedAt;

  /// The shop's own notes on the job, written on its history card.
  final String notes;

  /// What the job's last bill said. Only the full history list asks for it,
  /// and it is null for a job never billed -- or billed and then changed,
  /// which clears the bill until it is made again.
  final ProjectBillSummary? bill;

  const SavedProjectSummary({
    required this.id,
    required this.context,
    required this.projectName,
    required this.projectLocation,
    required this.status,
    required this.windowCount,
    required this.updatedAt,
    this.notes = '',
    this.bill,
  });

  /// Glass jobs are typed in as glass sizes and have no windows, so they open
  /// and read differently from an aluminium job.
  bool get isGlass => context == 'glass';

  /// Short label for the badge in history.
  String get kindLabel => isGlass ? 'Glass' : 'Aluminium';

  SavedProjectSummary copyWith({String? notes}) => SavedProjectSummary(
    id: id,
    context: context,
    projectName: projectName,
    projectLocation: projectLocation,
    status: status,
    windowCount: windowCount,
    updatedAt: updatedAt,
    notes: notes ?? this.notes,
    bill: bill,
  );

  factory SavedProjectSummary.fromJson(Map<String, dynamic> json) {
    return SavedProjectSummary(
      id: (json['id'] as String? ?? '').trim(),
      context: (json['context'] as String? ?? '').trim(),
      projectName: (json['projectName'] as String? ?? '').trim(),
      projectLocation: (json['projectLocation'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      windowCount: _asInt(json['windowCount']),
      updatedAt: _tryParseDate(json['updatedAt'] as String?),
      notes: json['notes'] is String ? json['notes'] as String : '',
      bill: json['bill'] is Map<String, dynamic>
          ? ProjectBillSummary.fromJson(json['bill'] as Map<String, dynamic>)
          : null,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

/// A job's last bill, as its history card shows it: who it is for and what
/// it comes to.
class ProjectBillSummary {
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double grandTotal;
  final double advancePaid;
  final double remainingDue;
  final int totalWindows;
  final double totalArea;

  /// "running" for a bill made in running feet, '' for square feet.
  final String areaMethod;

  const ProjectBillSummary({
    this.customerName = '',
    this.customerPhone = '',
    this.customerAddress = '',
    this.grandTotal = 0,
    this.advancePaid = 0,
    this.remainingDue = 0,
    this.totalWindows = 0,
    this.totalArea = 0,
    this.areaMethod = '',
  });

  /// Nothing left to pay on it -- the whole amount came in advance.
  bool get isPaid => grandTotal > 0 && remainingDue <= 0;

  factory ProjectBillSummary.fromJson(Map<String, dynamic> json) {
    double number(Object? value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    String text(Object? value) => value is String ? value.trim() : '';
    return ProjectBillSummary(
      customerName: text(json['customerName']),
      customerPhone: text(json['customerPhone']),
      customerAddress: text(json['customerAddress']),
      grandTotal: number(json['grandTotal']),
      advancePaid: number(json['advancePaid']),
      remainingDue: number(json['remainingDue']),
      totalWindows: number(json['totalWindows']).round(),
      totalArea: number(json['totalArea']),
      areaMethod: text(json['areaMethod']),
    );
  }
}

class SavedProjectDetail extends SavedProjectSummary {
  final List<WindowReviewItem> windows;
  final Map<String, dynamic>? outputs;

  const SavedProjectDetail({
    required super.id,
    required super.context,
    required super.projectName,
    required super.projectLocation,
    required super.status,
    required super.windowCount,
    required super.updatedAt,
    super.notes,
    required this.windows,
    required this.outputs,
  });

  factory SavedProjectDetail.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawWindows = json['windows'] is List<dynamic>
        ? json['windows'] as List<dynamic>
        : <dynamic>[];
    return SavedProjectDetail(
      id: (json['id'] as String? ?? '').trim(),
      context: (json['context'] as String? ?? '').trim(),
      projectName: (json['projectName'] as String? ?? '').trim(),
      projectLocation: (json['projectLocation'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      windowCount: SavedProjectSummary._asInt(json['windowCount']),
      updatedAt: SavedProjectSummary._tryParseDate(
        json['updatedAt'] as String?,
      ),
      notes: json['notes'] is String ? json['notes'] as String : '',
      windows: rawWindows
          .whereType<Map<String, dynamic>>()
          .map(WindowReviewItem.fromJson)
          .toList(growable: false),
      outputs: json['outputs'] is Map<String, dynamic>
          ? json['outputs'] as Map<String, dynamic>
          : null,
    );
  }
}
