/// Shared text search helpers for fuzzy, typo-tolerant matching across
/// child and guardian names — used by the Children list search and the
/// guardian-search-for-payments feature on Billing.
///
/// Normalization strips punctuation but keeps any Unicode *letter*, not
/// just a-z — this matters because a plain `[^a-z0-9\s]` regex would
/// silently strip every Amharic (Ge'ez script) character, breaking
/// search for any name entered in Amharic. `\p{L}` (with `unicode:
/// true`) matches a letter in any script.
String normalizeForSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Classic Levenshtein edit distance between two strings. Works
/// correctly on Amharic text too, since every Ethiopic character sits
/// in the Basic Multilingual Plane (no surrogate pairs), so indexing by
/// UTF-16 code unit is the same as indexing by character here.
int levenshteinDistance(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final previous = List<int>.filled(b.length + 1, 0);
  final current = List<int>.filled(b.length + 1, 0);

  for (var j = 0; j <= b.length; j++) {
    previous[j] = j;
  }

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final swap = previous;
    previous
      ..clear()
      ..addAll(current);
    current
      ..clear()
      ..addAll(swap);
  }

  return previous[b.length];
}

/// True if every whitespace-separated token in [query] finds either a
/// direct substring match or a close (edit-distance-1) fuzzy match
/// among [haystacks]. Both query and haystacks should already be run
/// through [normalizeForSearch].
bool matchesAllTokens({
  required List<String> haystacks,
  required String normalizedQuery,
}) {
  if (normalizedQuery.isEmpty) return true;

  final queryTokens =
      normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
  if (queryTokens.isEmpty) return true;

  for (final token in queryTokens) {
    final hasDirectMatch = haystacks.any((entry) =>
        entry == token ||
        entry.startsWith(token) ||
        token.startsWith(entry) ||
        entry.contains(token));
    if (hasDirectMatch) continue;

    final hasFuzzyMatch = haystacks.any((entry) {
      if (entry.length < 3) return false;
      return levenshteinDistance(entry, token) <= 1 ||
          levenshteinDistance(token, entry) <= 1;
    });

    if (!hasFuzzyMatch) return false;
  }

  return true;
}
