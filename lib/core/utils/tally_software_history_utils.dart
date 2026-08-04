import '../models/tally_software_entry.dart';

List<TallySoftwareEntry> parseTallySoftwareHistory(dynamic value) {
  if (value == null) return [const TallySoftwareEntry()];

  if (value is List<TallySoftwareEntry>) {
    return value.isEmpty ? [const TallySoftwareEntry()] : value;
  }

  if (value is List) {
    final parsed = value
        .map((item) {
          if (item is TallySoftwareEntry) return item;
          if (item is Map<String, dynamic>) {
            return TallySoftwareEntry.fromJson(item);
          }
          return null;
        })
        .whereType<TallySoftwareEntry>()
        .toList();

    return parsed.isEmpty ? [const TallySoftwareEntry()] : parsed;
  }

  return [const TallySoftwareEntry()];
}

List<Map<String, dynamic>> encodeTallySoftwareHistory(
  List<TallySoftwareEntry> entries,
) {
  return entries
      .where((entry) => entry.hasName)
      .map((entry) => entry.toJson())
      .toList();
}
