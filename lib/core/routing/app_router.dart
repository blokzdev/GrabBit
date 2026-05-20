import 'package:go_router/go_router.dart';
import 'package:grabbit/core/routing/router_refresh.dart';
import 'package:grabbit/features/downloader/presentation/add_download_screen.dart';
import 'package:grabbit/features/downloader/presentation/selection_screen.dart';
import 'package:grabbit/features/library/presentation/collections_screen.dart';
import 'package:grabbit/features/library/presentation/item_detail_screen.dart';
import 'package:grabbit/features/library/presentation/library_screen.dart';
import 'package:grabbit/features/library/presentation/metadata_edit_screen.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/lock/lock_screen.dart';
import 'package:grabbit/features/queue/presentation/queue_screen.dart';
import 'package:grabbit/features/settings/presentation/settings_screen.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// App navigation graph. Routes are added per feature as they land
/// (see docs/ARCHITECTURE.md §3).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) => lockRedirect(
      enabled:
          ref.read(settingsControllerProvider).asData?.value.appLock.enabled ??
          false,
      locked: ref.read(lockControllerProvider) == LockState.locked,
      atLock: state.matchedLocation == '/lock',
    ),
    routes: [
      GoRoute(
        path: '/lock',
        name: 'lock',
        builder: (context, state) => const LockScreen(),
      ),
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
        path: '/select',
        name: 'select',
        builder: (context, state) => const SelectionScreen(),
      ),
      GoRoute(
        path: '/item/:id',
        name: 'item',
        builder: (context, state) =>
            ItemDetailScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id/edit',
        name: 'item-edit',
        builder: (context, state) =>
            MetadataEditScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/collections',
        name: 'collections',
        builder: (context, state) => const CollectionsScreen(),
      ),
      GoRoute(
        path: '/collection/:id',
        name: 'collection',
        builder: (context, state) => CollectionDetailScreen(
          collectionId: int.parse(state.pathParameters['id']!),
          name: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/queue',
        name: 'queue',
        builder: (context, state) => const QueueScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
