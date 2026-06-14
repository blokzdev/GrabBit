import 'dart:convert';

/// Pretty-prints a Thing's canonical [jsonld] for the Advanced "View as Thing"
/// diagnostic (P14f) — 2-space indented for readability. Returns the raw string
/// unchanged when it isn't valid JSON (defensive; never throws).
String prettyThingJsonld(String jsonld) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(jsonld));
  } on FormatException {
    return jsonld;
  }
}
