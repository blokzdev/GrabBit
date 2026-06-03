import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/ai/data/rag_context.dart';

RagSource _src(int i, String title, String snippet) =>
    RagSource(index: i, itemId: 'id$i', title: title, snippet: snippet);

void main() {
  group('buildRagPrompt (P13d-1)', () {
    test('numbers sources and includes the question', () {
      final prompt = buildRagPrompt('what live shows do I have?', [
        _src(1, 'Concert A', 'by Band · tags: live'),
        _src(2, 'Concert B', 'by Other'),
      ]);
      expect(prompt, contains('[1] Concert A — by Band · tags: live'));
      expect(prompt, contains('[2] Concert B — by Other'));
      expect(prompt, contains('Question: what live shows do I have?'));
      expect(prompt, isNot(contains('Conversation so far')));
    });

    test('folds in bounded history, oldest dropped first', () {
      final history = [
        const RagChatTurn(question: 'old q', answer: 'old a'),
        const RagChatTurn(question: 'recent q', answer: 'recent a'),
      ];
      final prompt = buildRagPrompt(
        'follow up',
        [_src(1, 'X', 'y')],
        history: history,
        historyCharBudget: 20, // only the most recent turn fits
      );
      expect(prompt, contains('Conversation so far'));
      expect(prompt, contains('recent q'));
      expect(prompt, isNot(contains('old q')));
    });
  });

  group('fitHistory (P13d-1)', () {
    test('keeps the most recent turns within budget, chronological', () {
      final turns = [
        const RagChatTurn(question: 'a', answer: '1'), // cost 2
        const RagChatTurn(question: 'b', answer: '2'), // cost 2
        const RagChatTurn(question: 'c', answer: '3'), // cost 2
      ];
      final kept = fitHistory(turns, 4);
      expect(kept.map((t) => t.question), ['b', 'c']);
    });

    test('always keeps at least the latest turn even if over budget', () {
      final kept = fitHistory(const [
        RagChatTurn(question: 'long question', answer: 'long answer'),
      ], 1);
      expect(kept, hasLength(1));
    });

    test('empty history → empty', () {
      expect(fitHistory(const [], 100), isEmpty);
    });
  });

  group('selectRagSources (P13d-1)', () {
    test('dedupes preserving order and caps to max', () {
      expect(selectRagSources(['a', 'b', 'a', 'c', 'd'], max: 3), [
        'a',
        'b',
        'c',
      ]);
    });
  });

  group('buildSourceSnippet (P13d-1)', () {
    test('prefers aiSummary over description and includes tags/uploader', () {
      final s = buildSourceSnippet(
        uploader: 'Chef',
        tags: ['food', 'pasta'],
        description: 'raw description',
        aiSummary: 'a tidy summary',
      );
      expect(s, contains('by Chef'));
      expect(s, contains('tags: food, pasta'));
      expect(s, contains('a tidy summary'));
      expect(s, isNot(contains('raw description')));
    });

    test('falls back to description when no summary, and caps length', () {
      final long = List.filled(2000, 'x').join();
      final s = buildSourceSnippet(description: long, maxChars: 100);
      expect(s, contains('x'));
      expect(s.length, lessThanOrEqualTo(100));
    });

    test('empty when there is nothing to say', () {
      expect(buildSourceSnippet(), isEmpty);
    });
  });
}
