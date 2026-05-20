import 'package:go_router/go_router.dart';
import 'package:grabbit/features/library/presentation/library_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// App navigation graph. Routes are added per feature as they land
/// (see docs/ARCHITECTURE.md §3).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
    ],
  );
}
