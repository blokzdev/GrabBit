import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/presentation/ai_summary.dart';

void main() {
  group('buildSummaryPrompt (P13a)', () {
    test('wraps the source with the summarize instruction', () {
      final p = buildSummaryPrompt('Hello world.');
      expect(p.systemPrompt, kSummarySystemPrompt);
      expect(p.prompt, contains('Summarize the following:'));
      expect(p.prompt, contains('Hello world.'));
    });

    test('trims surrounding whitespace from the source', () {
      final p = buildSummaryPrompt('   padded text   ');
      expect(p.prompt.endsWith('padded text'), isTrue);
      expect(p.prompt, isNot(contains('padded text   ')));
    });

    test('truncates long input to the char budget (head)', () {
      final long = List.filled(5000, 'a').join();
      final p = buildSummaryPrompt(long, maxChars: 100);
      // The source slice is at most maxChars; the prompt is prefix + slice.
      final slice = p.prompt.split('\n\n').last;
      expect(slice.length, lessThanOrEqualTo(100));
    });

    test('short input is passed through untruncated', () {
      final p = buildSummaryPrompt('A short note.', maxChars: 100);
      expect(p.prompt, contains('A short note.'));
    });
  });

  group('aiSummaryAction (P13a)', () {
    test('ineligible device → unavailable (extractive floor only)', () {
      expect(
        aiSummaryAction(eligible: false, enabled: false, modelReady: false),
        AiSummaryAction.unavailable,
      );
      // Eligibility wins even if somehow enabled/ready.
      expect(
        aiSummaryAction(eligible: false, enabled: true, modelReady: true),
        AiSummaryAction.unavailable,
      );
    });

    test('eligible + disabled → offer setup (enable + pick a model)', () {
      expect(
        aiSummaryAction(eligible: true, enabled: false, modelReady: false),
        AiSummaryAction.offerSetup,
      );
    });

    test('eligible + enabled + no model → offer download', () {
      expect(
        aiSummaryAction(eligible: true, enabled: true, modelReady: false),
        AiSummaryAction.offerDownload,
      );
    });

    test('eligible + enabled + model ready → summarize now', () {
      expect(
        aiSummaryAction(eligible: true, enabled: true, modelReady: true),
        AiSummaryAction.summarizeNow,
      );
    });
  });
}
