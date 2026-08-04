class TallySoftwareEntry {
  final String name;
  final DateTime? fromDate;
  final DateTime? toDate;

  const TallySoftwareEntry({this.name = '', this.fromDate, this.toDate});

  factory TallySoftwareEntry.fromJson(Map<String, dynamic> json) {
    return TallySoftwareEntry(
      name: (json['name'] as String?)?.trim() ?? '',
      fromDate: _parseDate(json['from_date']),
      toDate: _parseDate(json['to_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'from_date': fromDate?.toIso8601String(),
      'to_date': toDate?.toIso8601String(),
    };
  }

  bool get hasName => name.trim().isNotEmpty;

  TallySoftwareEntry copyWith({
    String? name,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return TallySoftwareEntry(
      name: name ?? this.name,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
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
