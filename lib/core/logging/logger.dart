import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger.g.dart';

/// App-wide structured logger. Verbose in debug, warnings-and-up in release.
@Riverpod(keepAlive: true)
Logger appLogger(Ref ref) {
  return Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true),
  );
}
