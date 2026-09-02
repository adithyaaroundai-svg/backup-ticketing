/// Small helpers for tolerantly parsing values coming back from Postgres
/// via the API (numeric-strings, 0/1 "booleans", nullable fields, etc.)
/// per the "Data conventions" section of API.md.
library;

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

int asInt(dynamic v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;

num? asNumOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

num asNum(dynamic v, [num fallback = 0]) => asNumOrNull(v) ?? fallback;

/// Treats 0/1, "0"/"1", true/false, null as booleans (per API.md, most
/// SMALLINT booleans are raw 0/1 unless explicitly coerced by the route).
bool asBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

String? asStringOrNull(dynamic v) => v?.toString();

String asString(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
