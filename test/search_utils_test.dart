import 'package:flutter_test/flutter_test.dart';

import 'package:adey/data/search_utils.dart';

void main() {
  group('levenshteinDistance', () {
    test('measures exact matches, single edits and empty strings', () {
      expect(levenshteinDistance('abebe', 'abebe'), 0);
      expect(levenshteinDistance('abebe', 'abeb'), 1);
      expect(levenshteinDistance('abebe', 'ebebe'), 1);
      expect(levenshteinDistance('', 'abc'), 3);
      expect(levenshteinDistance('abc', ''), 3);
      expect(levenshteinDistance('kitten', 'sitting'), 3);
      expect(levenshteinDistance('flaw', 'lawn'), 2);
    });

    test('does not throw on unrelated strings', () {
      expect(levenshteinDistance('zzzzzz', 'abebe kebede'), greaterThan(1));
    });
  });

  group('matchesAllTokens', () {
    test('returns false for a query that matches nothing', () {
      expect(
        matchesAllTokens(
          haystacks: ['abebe kebede'],
          normalizedQuery: 'zzzzzz',
        ),
        isFalse,
      );
    });

    test('matches a single-character typo', () {
      expect(
        matchesAllTokens(haystacks: ['abebe'], normalizedQuery: 'akebe'),
        isTrue,
      );
    });

    test('empty query matches everything', () {
      expect(
        matchesAllTokens(haystacks: ['abebe'], normalizedQuery: ''),
        isTrue,
      );
    });
  });
}
