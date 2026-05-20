import 'package:go_router/go_router.dart';
import 'package:grabbit/features/downloader/presentation/add_download_screen.dart';
import 'package:grabbit/features/library/presentation/item_detail_screen.dart';
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
      GoRoute(
        path: '/add',
        name: 'add',
        builder: (context, state) => const AddDownloadScreen(),
      ),
      GoRoute(
        path: '/item/:id',
        name: 'item',
        builder: (context, state) =>
            ItemDetailScreen(itemId: state.pathParameters['id']!),
      ),
    ],
  );
}
