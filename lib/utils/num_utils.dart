/// Reads a number from JSON that may arrive as a num or a string
/// (Laravel decimal casts serialize as strings, e.g. "1100.00").
double asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

/// Like [asDouble] but keeps null/empty as null.
double? asDoubleOrNull(dynamic value) {
  if (value == null || value == '') return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
