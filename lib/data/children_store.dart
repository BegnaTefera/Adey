import 'package:flutter/foundation.dart';
import '../models/child.dart';
import 'children_repository.dart';

/// Reactive cache over the real SQLite-backed children data.
///
/// Screens read `ChildrenStore.instance.children` and listen via
/// [ChangeNotifier]. The cache exists so the UI doesn't have to re-query
/// SQLite on every rebuild.
class ChildrenStore extends ChangeNotifier {
  ChildrenStore._internal();

  static final ChildrenStore instance = ChildrenStore._internal();

  List<Child> _children = [];
  bool _initialized = false;

  List<Child> get children => List.unmodifiable(_children);

  bool get isInitialized => _initialized;

  /// Loads all children from SQLite into the cache. Call once at app
  /// startup, before anything tries to read `children`.
  Future<void> init() async {
    if (_initialized) return;

    _children = await ChildrenRepository.instance.fetchAll();
    _initialized = true;
    notifyListeners();
  }

  /// Persists a newly registered child (with its guardians, documents,
  /// etc. already attached) and refreshes the cache.
  Future<void> addChild(Child child) async {
    await ChildrenRepository.instance.insert(child);
    await _refresh();
  }

  /// Persists changes to an existing child (e.g. a new attendance mark
  /// or payment) and refreshes the cache. Matches by id.
  Future<void> updateChild(Child updated) async {
    await ChildrenRepository.instance.update(updated);
    await _refresh();
  }

  Child? byId(String id) {
    for (final c in _children) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Re-reads everything from SQLite. Sync calls this after merging rows
  /// from the other device ([init] is a no-op once initialized).
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    _children = await ChildrenRepository.instance.fetchAll();
    _initialized = true;
    notifyListeners();
  }
}
