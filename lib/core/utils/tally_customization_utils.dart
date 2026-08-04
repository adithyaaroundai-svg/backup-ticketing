import '../models/tally_customization_entry.dart';

List<TallyCustomizationEntry> parseTallyCustomizations(dynamic value) {
  if (value == null) return [const TallyCustomizationEntry()];

  if (value is List<TallyCustomizationEntry>) {
    return value.isEmpty ? [const TallyCustomizationEntry()] : value;
  }

  if (value is List) {
    final parsed = value
        .map((item) {
          if (item is TallyCustomizationEntry) return item;
          if (item is Map<String, dynamic>) {
            return TallyCustomizationEntry.fromJson(item);
          }
          return null;
        })
        .whereType<TallyCustomizationEntry>()
        .toList();
    return parsed.isEmpty ? [const TallyCustomizationEntry()] : parsed;
  }

  if (value is Map<String, dynamic>) {
    if (value['modules'] is List) {
      return parseTallyCustomizations(value['modules']);
    }
    final legacyText = value['description'] ?? value['text'];
    if (legacyText is String && legacyText.trim().isNotEmpty) {
      return [TallyCustomizationEntry(moduleName: legacyText.trim())];
    }
  }

  return [const TallyCustomizationEntry()];
}

List<Map<String, dynamic>> encodeTallyCustomizations(
  List<TallyCustomizationEntry> entries,
) {
  final modules = entries
      .where((entry) => entry.hasModule)
      .map((entry) => entry.toJson())
      .toList();

  return modules;
}
