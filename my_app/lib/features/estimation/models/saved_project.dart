import 'window_review_item.dart';

class SavedProjectSummary {
  final String id;
  final String context;
  final String projectName;
  final String projectLocation;
  final String status;
  final int windowCount;
  final DateTime? updatedAt;

  const SavedProjectSummary({
    required this.id,
    required this.context,
    required this.projectName,
    required this.projectLocation,
    required this.status,
    required this.windowCount,
    required this.updatedAt,
  });

  factory SavedProjectSummary.fromJson(Map<String, dynamic> json) {
    return SavedProjectSummary(
      id: (json['id'] as String? ?? '').trim(),
      context: (json['context'] as String? ?? '').trim(),
      projectName: (json['projectName'] as String? ?? '').trim(),
      projectLocation: (json['projectLocation'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      windowCount: _asInt(json['windowCount']),
      updatedAt: _tryParseDate(json['updatedAt'] as String?),
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
    required this.windows,
    required this.outputs,
  });

  factory SavedProjectDetail.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawWindows =
        json['windows'] is List<dynamic> ? json['windows'] as List<dynamic> : <dynamic>[];
    return SavedProjectDetail(
      id: (json['id'] as String? ?? '').trim(),
      context: (json['context'] as String? ?? '').trim(),
      projectName: (json['projectName'] as String? ?? '').trim(),
      projectLocation: (json['projectLocation'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      windowCount: SavedProjectSummary._asInt(json['windowCount']),
      updatedAt: SavedProjectSummary._tryParseDate(json['updatedAt'] as String?),
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
