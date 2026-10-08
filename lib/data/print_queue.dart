import '../models/child.dart';

/// One signed registration form waiting for its first print.
class PrintQueueItem {
  final Child child;
  final ChildDocument document;

  const PrintQueueItem({required this.child, required this.document});
}

/// The print queue is derived, not stored: it's every `registration`
/// document with `printed == false`, oldest signature first. Because it's
/// computed from [ChildrenStore] data, the queue screen and the sidebar
/// badge always agree and update the moment a sync or a print changes a
/// row.
///
/// It means "needs a first print", not "has been printed exactly once" —
/// reprinting from the child's profile never touches it.
List<PrintQueueItem> buildPrintQueue(Iterable<Child> children) {
  final items = <PrintQueueItem>[
    for (final child in children)
      for (final doc in child.documents)
        if (doc.type == DocumentType.registration && !doc.printed)
          PrintQueueItem(child: child, document: doc),
  ];
  items.sort(
    (a, b) => a.document.uploadedAt.compareTo(b.document.uploadedAt),
  );
  return items;
}
