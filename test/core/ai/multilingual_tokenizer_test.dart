import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/multilingual_tokenizer.dart';

/// XLM-R special token ids (paraphrase-multilingual-MiniLM-L12-v2).
const _bos = 0; // <s>
const _eos = 2; // </s>
const _pad = 1; // <pad>

void main() {
  late MultilingualEmbedderTokenizer tokenizer;
  late List<dynamic> goldenCases;

  setUpAll(() {
    const dir = 'test/fixtures/multilingual_tokenizer';
    // The real tokenizer.json (~9 MB) is committed gzipped to keep the repo lean.
    final gz = File('$dir/tokenizer.json.gz').readAsBytesSync();
    final json = utf8.decode(gzip.decode(gz));
    tokenizer = MultilingualEmbedderTokenizer.fromJson(json);
    final golden =
        jsonDecode(File('$dir/golden_tokenization.json').readAsStringSync())
            as Map<String, dynamic>;
    goldenCases = golden['cases'] as List<dynamic>;
  });

  group('XLM-R fidelity (golden vectors from HuggingFace tokenizers)', () {
    test('reproduces HuggingFace token ids exactly for every golden case', () {
      for (final c in goldenCases) {
        final case_ = c as Map<String, dynamic>;
        final text = case_['text'] as String;
        final maxTokens = case_['maxTokens'] as int?;
        final expected = (case_['ids'] as List).cast<int>();

        // Full cases use a window larger than any of them (no truncation);
        // truncated cases pass the fixture's maxTokens.
        final out = tokenizer.encode(text, maxTokens: maxTokens ?? 512);

        expect(
          out.inputIds,
          expected,
          reason: 'ids mismatch for ${jsonEncode(text)} (maxTokens=$maxTokens)',
        );
      }
    });
  });

  group('mechanics', () {
    test('wraps a single input in <s> … </s> with an all-ones mask', () {
      final out = tokenizer.encode('GrabBit', maxTokens: 64);
      expect(out.inputIds.first, _bos);
      expect(out.inputIds.last, _eos);
      expect(out.attentionMask.length, out.inputIds.length);
      expect(out.attentionMask.every((m) => m == 1), isTrue);
    });

    test('an empty string is just the two specials', () {
      final out = tokenizer.encode('', maxTokens: 64);
      expect(out.inputIds, [_bos, _eos]);
    });

    test('truncates to maxTokens total (specials included)', () {
      final long = 'The quick brown fox jumps over the lazy dog. ' * 10;
      final out = tokenizer.encode(long, maxTokens: 16);
      expect(out.inputIds.length, 16);
      expect(out.inputIds.first, _bos);
      expect(out.inputIds.last, _eos);
    });

    test('encodeBatch right-pads to the longest row with masked <pad>', () {
      final batch = tokenizer.encodeBatch(const [
        'short',
        'a noticeably longer multilingual sentence 你好',
      ], maxTokens: 128);
      expect(batch.length, 2);
      final len = batch.first.inputIds.length;
      // Every row padded to the same length.
      expect(batch.every((r) => r.inputIds.length == len), isTrue);
      expect(batch.every((r) => r.attentionMask.length == len), isTrue);
      // The shorter row ends in padding: mask 0 where id is <pad>.
      final short = batch.first;
      for (var i = 0; i < len; i++) {
        if (short.attentionMask[i] == 0) {
          expect(short.inputIds[i], _pad);
        }
      }
      expect(short.attentionMask.any((m) => m == 0), isTrue);
    });

    test('encodeBatch([]) is empty', () {
      expect(tokenizer.encodeBatch(const [], maxTokens: 128), isEmpty);
    });
  });
}
