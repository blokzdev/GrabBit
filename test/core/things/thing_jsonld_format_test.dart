import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/thing_jsonld_format.dart';

void main() {
  test('pretty-prints valid JSON-LD with 2-space indentation', () {
    expect(
      prettyThingJsonld('{"@type":"VideoObject","name":"V"}'),
      '{\n  "@type": "VideoObject",\n  "name": "V"\n}',
    );
  });

  test('returns the raw string unchanged when not valid JSON', () {
    expect(prettyThingJsonld('not json at all'), 'not json at all');
  });
}
