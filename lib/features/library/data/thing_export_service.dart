import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/features/library/data/thing_exporters.dart';
import 'package:path_provider/path_provider.dart';

/// Performs the on-device export for a Thing (P16c): formatted text via the share
/// sheet (Recipe/Article/Product), a `.ics` file (Event), or a `geo:` maps deep
/// link (Place). Pure formatting lives in `thing_exporters.dart`; this service
/// only wires it to the OS via [ExternalShareService] — injectable + testable.
class ThingExportService {
  ThingExportService(
    this._share, {
    Future<Directory> Function()? tempDir,
    DateTime Function()? now,
  }) : _tempDir = tempDir ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  final ExternalShareService _share;
  final Future<Directory> Function() _tempDir;
  final DateTime Function() _now;

  Future<void> export(Thing thing) async {
    final doc = ThingDoc.fromJsonString(thing.jsonld);
    switch (exportKindFor(thing.type)) {
      case ThingExportKind.text:
        final text = switch (thing.type) {
          'Recipe' => recipeToText(doc),
          'Article' => articleToText(doc),
          'Product' => productToText(doc),
          _ => '',
        };
        await _share.shareText(text, subject: doc.name);
      case ThingExportKind.geoUri:
        final uri = placeToGeoUri(doc);
        if (uri != null) await _share.openUrl(uri);
      case ThingExportKind.icsFile:
        final ics = eventToIcs(doc, uid: thing.id, now: _now);
        final dir = await _tempDir();
        final stem = (doc.name ?? 'event').replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );
        final path = '${dir.path}/$stem.ics';
        await File(path).writeAsString(ics);
        await _share.shareFiles([path]);
      case null:
        break;
    }
  }
}

final thingExportServiceProvider = Provider<ThingExportService>(
  (ref) => ThingExportService(ref.watch(externalShareServiceProvider)),
);
