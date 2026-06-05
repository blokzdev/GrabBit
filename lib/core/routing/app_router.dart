import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/routing/router_refresh.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/adaptive_navigation_scaffold.dart';
import 'package:grabbit/features/downloader/presentation/add_download_screen.dart';
import 'package:grabbit/features/dashboard/presentation/dashboard_screen.dart';
import 'package:grabbit/features/downloader/presentation/selection_screen.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/collections_screen.dart';
import 'package:grabbit/features/library/presentation/entity_hub_screen.dart';
import 'package:grabbit/features/library/presentation/home_screen.dart';
import 'package:grabbit/features/library/presentation/item_detail_screen.dart';
import 'package:grabbit/features/ai/presentation/ask_screen.dart';
import 'package:grabbit/features/ai/presentation/conversations_screen.dart';
import 'package:grabbit/features/ai/presentation/relevant_items_screen.dart';
import 'package:grabbit/features/ai/presentation/graph_view_screen.dart';
import 'package:grabbit/features/library/presentation/connection_path_screen.dart';
import 'package:grabbit/features/library/presentation/media_studio_screen.dart';
import 'package:grabbit/features/library/presentation/metadata_edit_screen.dart';
import 'package:grabbit/features/library/presentation/duplicates_screen.dart';
import 'package:grabbit/features/library/presentation/smart_album_screen.dart';
import 'package:grabbit/features/library/presentation/storage_screen.dart';
import 'package:grabbit/features/library/presentation/suggested_album_screen.dart';
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/onboarding/presentation/ai_setup_screen.dart';
import 'package:grabbit/features/onboarding/presentation/disclaimer_screen.dart';
import 'package:grabbit/features/lock/lock_screen.dart';
import 'package:grabbit/features/notifications/presentation/inbox_screen.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/presentation/queue_screen.dart';
import 'package:grabbit/features/settings/presentation/about_screen.dart';
import 'package:grabbit/features/settings/presentation/ai_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/captions_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/downloads_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/notifications_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/settings_screen.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App navigation graph. The five top-level destinations (Dashboard, Library,
/// Queue, Collections, Settings) live in a [StatefulShellRoute] so they keep
/// their own state and share the adaptive nav chrome; flow/detail routes push
/// over it on the root navigator (full-screen, with a back button). The
/// Dashboard is the default landing (`/`); the Library lives at `/library`.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final settings = ref.read(settingsControllerProvider).asData?.value;
      return startupRedirect(
        disclaimerAccepted: settings?.disclaimerAccepted ?? true,
        aiSetupSeen: settings?.aiSetupSeen ?? true,
        lockEnabled: settings?.appLock.enabled ?? false,
        locked: ref.read(lockControllerProvider) == LockState.locked,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/disclaimer',
        name: 'disclaimer',
        builder: (context, state) => const DisclaimerScreen(),
      ),
      GoRoute(
        path: '/lock',
        name: 'lock',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/ai-setup',
        name: 'ai-setup',
        builder: (context, state) => const AiSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AdaptiveShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/queue',
                name: 'queue',
                builder: (context, state) => const QueueScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/collections',
                name: 'collections',
                builder: (context, state) => const CollectionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/add',
        name: 'add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddDownloadScreen(),
      ),
      GoRoute(
        path: '/select',
        name: 'select',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SelectionScreen(),
      ),
      GoRoute(
        path: '/item/:id',
        name: 'item',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ItemDetailScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id/edit',
        name: 'item-edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            MetadataEditScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id/studio',
        name: 'item-studio',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            MediaStudioScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id/graph',
        name: 'item-graph',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            GraphViewScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id/path',
        name: 'item-path',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ConnectionPathScreen(
          sourceId: state.pathParameters['id']!,
          targetId: state.uri.queryParameters['to'] ?? '',
        ),
      ),
      GoRoute(
        path: '/collection/:id',
        name: 'collection',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CollectionDetailScreen(
          collectionId: int.parse(state.pathParameters['id']!),
          name: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/album/:kind',
        name: 'album',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SmartAlbumScreen(
          kind: state.pathParameters['kind']!,
          value: state.uri.queryParameters['v'],
        ),
      ),
      GoRoute(
        path: '/hub/:type',
        name: 'hub',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => EntityHubScreen(
          type: state.pathParameters['type']!,
          value: state.uri.queryParameters['v'] ?? '',
          displayName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/suggested-album',
        name: 'suggestedAlbum',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SuggestedAlbumScreen(
          album: state.extra is SuggestedAlbum
              ? state.extra! as SuggestedAlbum
              : null,
        ),
      ),
      GoRoute(
        path: '/storage',
        name: 'storage',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StorageScreen(),
      ),
      GoRoute(
        path: '/duplicates',
        name: 'duplicates',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DuplicatesScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/settings/downloads',
        name: 'settings-downloads',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DownloadsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/captions',
        name: 'settings-captions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CaptionsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/ai',
        name: 'settings-ai',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AiSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        name: 'settings-notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: '/inbox',
        name: 'inbox',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: '/ask',
        name: 'ask',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConversationsScreen(),
      ),
      // Static `/ask/chat` is registered before the `:id` route so a new chat
      // never matches as a conversation id.
      GoRoute(
        path: '/ask/chat',
        name: 'ask-new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AskScreen(),
      ),
      GoRoute(
        path: '/ask/chat/:id',
        name: 'ask-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AskScreen(chatId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/ask/archived',
        name: 'ask-archived',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ArchivedChatsScreen(),
      ),
      GoRoute(
        path: '/ask/relevant',
        name: 'ask-relevant',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RelevantItemsScreen(),
      ),
    ],
  );
}

/// Renders the active branch inside the size-class-aware navigation chrome.
class _AdaptiveShell extends StatelessWidget {
  const _AdaptiveShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigationScaffold(
      selectedIndex: navigationShell.currentIndex,
      onSelect: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const [
        AdaptiveDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        AdaptiveDestination(
          icon: Icon(Icons.video_library_outlined),
          selectedIcon: Icon(Icons.video_library),
          label: 'Library',
        ),
        AdaptiveDestination(icon: _QueueNavIcon(), label: 'Queue'),
        AdaptiveDestination(icon: _CollectionsNavIcon(), label: 'Collections'),
        AdaptiveDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
      child: navigationShell,
    );
  }
}

/// Queue destination icon: a pending-count badge plus an accent dot shown only
/// while a download is actively running.
class _QueueNavIcon extends ConsumerWidget {
  const _QueueNavIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final tasks = ref.watch(queueTasksProvider).asData?.value ?? const [];
    final pending = tasks
        .where(
          (t) => t.status != TaskStatus.done && t.status != TaskStatus.canceled,
        )
        .length;
    final anyRunning = tasks.any((t) => t.status == TaskStatus.running);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Badge(
          isLabelVisible: pending > 0,
          label: Text('$pending'),
          child: const Icon(Icons.download_outlined),
        ),
        if (anyRunning)
          Positioned(
            left: -1,
            top: -1,
            child: Container(
              key: const Key('queueRunningDot'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tokens.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Collections destination icon with a count badge.
class _CollectionsNavIcon extends ConsumerWidget {
  const _CollectionsNavIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(collectionsProvider).asData?.value.length ?? 0;
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: const Icon(Icons.collections_bookmark_outlined),
    );
  }
}
