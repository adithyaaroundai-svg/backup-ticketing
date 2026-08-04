class TallyCustomizationEntry {
  final String moduleName;
  final DateTime? lastUpdated;

  const TallyCustomizationEntry({this.moduleName = '', this.lastUpdated});

  factory TallyCustomizationEntry.fromJson(Map<String, dynamic> json) {
    return TallyCustomizationEntry(
      moduleName: (json['module_name'] as String?)?.trim() ?? '',
      lastUpdated: _parseDate(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module_name': moduleName.trim(),
      'last_updated': lastUpdated?.toIso8601String(),
    }..removeWhere(
      (_, value) => value == null || (value is String && value.isEmpty),
    );
  }

  bool get hasModule => moduleName.trim().isNotEmpty;

  TallyCustomizationEntry copyWith({
    String? moduleName,
    DateTime? lastUpdated,
  }) {
    return TallyCustomizationEntry(
      moduleName: moduleName ?? this.moduleName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
