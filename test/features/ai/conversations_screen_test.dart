import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/ai/data/chat_repository.dart';
import 'package:grabbit/features/ai/presentation/conversations_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<ChatListItem> chats) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeChatsProvider.overrideWith((ref) => Stream.value(chats)),
        ],
        child: const MaterialApp(home: ConversationsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty list shows the start-a-chat CTA', (tester) async {
    await pump(tester, const []);
    expect(find.text('Start a chat'), findsOneWidget);
  });

  testWidgets('renders a row per conversation with title + preview', (
    tester,
  ) async {
    await pump(tester, [
      ChatListItem(
        id: 'chat_1',
        title: 'Concert clips',
        updatedAt: DateTime.now(),
        preview: 'It was great',
        archived: false,
      ),
    ]);
    expect(find.text('Concert clips'), findsOneWidget);
    expect(find.textContaining('It was great'), findsOneWidget);
    expect(find.text('Start a chat'), findsNothing);
  });

  testWidgets('an active row offers rename / archive / delete', (tester) async {
    await pump(tester, [
      ChatListItem(
        id: 'chat_1',
        title: 'Concert clips',
        updatedAt: DateTime.now(),
        preview: 'hi',
        archived: false,
      ),
    ]);

    // The row's overflow menu (the AppBar also has one, for "Archived chats").
    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
