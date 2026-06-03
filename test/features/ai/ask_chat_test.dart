import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/ai/data/rag_context.dart';
import 'package:grabbit/features/ai/presentation/ask_chat.dart';

ChatMessage _msg(String role, String content) => ChatMessage(
  id: 0,
  chatId: 'c',
  role: role,
  content: content,
  createdAt: DateTime.utc(2026),
);

void main() {
  group('messagesToHistory', () {
    test('pairs consecutive user→assistant messages into turns', () {
      final turns = messagesToHistory([
        _msg(kRoleUser, 'q1'),
        _msg(kRoleAssistant, 'a1'),
        _msg(kRoleUser, 'q2'),
        _msg(kRoleAssistant, 'a2'),
      ]);
      expect(turns.map((t) => t.question), ['q1', 'q2']);
      expect(turns.map((t) => t.answer), ['a1', 'a2']);
    });

    test('drops a trailing unanswered user message', () {
      final turns = messagesToHistory([
        _msg(kRoleUser, 'q1'),
        _msg(kRoleAssistant, 'a1'),
        _msg(kRoleUser, 'q2'),
      ]);
      expect(turns.length, 1);
      expect(turns.single.question, 'q1');
    });

    test('ignores an assistant message with no preceding question', () {
      final turns = messagesToHistory([
        _msg(kRoleAssistant, 'orphan'),
        _msg(kRoleUser, 'q1'),
        _msg(kRoleAssistant, 'a1'),
      ]);
      expect(turns.length, 1);
      expect(turns.single, isA<RagChatTurn>());
      expect(turns.single.answer, 'a1');
    });
  });

  group('citation codec', () {
    test('encode → decode round-trips index/itemId/title', () {
      final json = encodeCitations(const [
        RagSource(index: 1, itemId: 'a', title: 'Live in Tokyo', snippet: 's1'),
        RagSource(index: 2, itemId: 'b', title: 'Studio', snippet: 's2'),
      ]);
      final decoded = decodeCitations(json);
      expect(decoded.map((c) => c.index), [1, 2]);
      expect(decoded.map((c) => c.itemId), ['a', 'b']);
      expect(decoded.map((c) => c.title), ['Live in Tokyo', 'Studio']);
    });

    test('decode tolerates null, blank, and malformed input', () {
      expect(decodeCitations(null), isEmpty);
      expect(decodeCitations('  '), isEmpty);
      expect(decodeCitations('not json'), isEmpty);
      expect(decodeCitations('{"i":1}'), isEmpty); // not a list
    });
  });

  group('parseCitationSpans', () {
    const citations = [
      Citation(index: 1, itemId: 'a', title: 'A'),
      Citation(index: 2, itemId: 'b', title: 'B'),
    ];

    test('splits prose and tappable [n] markers', () {
      final spans = parseCitationSpans('See [1] and [2].', citations);
      expect(spans.map((s) => s.text), ['See ', '[1]', ' and ', '[2]', '.']);
      expect(spans.map((s) => s.isCitation), [false, true, false, true, false]);
      expect(spans[1].citation!.itemId, 'a');
      expect(spans[3].citation!.itemId, 'b');
    });

    test('leaves an out-of-range [n] as plain text', () {
      final spans = parseCitationSpans('Yes [3] indeed', const [
        Citation(index: 1, itemId: 'a', title: 'A'),
      ]);
      expect(spans.length, 1);
      expect(spans.single.isCitation, isFalse);
      expect(spans.single.text, 'Yes [3] indeed');
    });

    test('plain answer with no markers is a single text span', () {
      final spans = parseCitationSpans('No citations here', citations);
      expect(spans.single.text, 'No citations here');
      expect(spans.single.isCitation, isFalse);
    });
  });
}
