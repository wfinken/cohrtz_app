import 'package:sql_crdt/sql_crdt.dart';

/// Parses HLC strings while tolerating node IDs that contain ':'.
///
/// Older code paths may persist HLCs like
/// `2026-02-23T02:58:09.544865Z-0000-user:abc-123`, which can fail in
/// upstream `Hlc.parse` because it searches using the last `:`.
Hlc parseHlcCompat(String raw) {
  final input = raw.trim();
  try {
    return Hlc.parse(input);
  } catch (_) {
    final marker = input.indexOf('Z-');
    if (marker <= 0 || input.length < marker + 7) {
      rethrow;
    }

    final datePart = input.substring(0, marker + 1);
    final counterPart = input.substring(marker + 2, marker + 6);
    final separator = input.substring(marker + 6, marker + 7);
    if (separator != '-') {
      rethrow;
    }

    final nodeId = input.substring(marker + 7);
    final parsedDate = DateTime.parse(datePart);
    final parsedCounter = int.parse(counterPart, radix: 16);
    return Hlc(parsedDate, parsedCounter, nodeId);
  }
}

Hlc? tryParseHlcCompat(String raw) {
  try {
    return parseHlcCompat(raw);
  } catch (_) {
    return null;
  }
}

String sanitizeCrdtNodeId(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'node';
  return value.replaceAll(':', '_').replaceAll(RegExp(r'\s+'), '_');
}
