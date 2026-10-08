import 'package:flutter/material.dart';
import '../data/children_store.dart';
import '../data/document_printing.dart';
import '../data/formatters.dart';
import '../data/print_queue.dart';
import '../data/sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

/// Desktop only: signed registration forms that came in from the phone and
/// still need their first print. Printing hands the stored bytes to the OS
/// print dialog; a successful print marks the document printed and the row
/// disappears.
class PrintQueueScreen extends StatefulWidget {
  const PrintQueueScreen({super.key});

  @override
  State<PrintQueueScreen> createState() => _PrintQueueScreenState();
}

class _PrintQueueScreenState extends State<PrintQueueScreen> {
  final Set<String> _printing = {};

  @override
  void initState() {
    super.initState();
    ChildrenStore.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    ChildrenStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _print(PrintQueueItem item) async {
    final docId = item.document.id;
    if (_printing.contains(docId)) return;
    setState(() => _printing.add(docId));
    try {
      final printed = await printStoredDocument(
        item.document,
        name: 'Registration_${item.child.firstName}_${item.child.lastName}.pdf',
      );
      // Cancelling the print dialog leaves the row in the queue.
      if (printed) await SyncService.instance.markDocumentPrinted(docId);
    } on DocumentUnavailableException catch (e) {
      if (mounted) {
        showAppFeedback(context, message: e.message, kind: AppFeedbackKind.info);
      }
    } catch (e) {
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Could not print: $e',
          kind: AppFeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _printing.remove(docId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = buildPrintQueue(ChildrenStore.instance.children);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Print Queue', style: AppText.pageTitle),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'Nothing waiting to print',
                    style: AppText.bodyMedium,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Container(
                      decoration: cardDecoration(),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            _row(items[i], isLast: i == items.length - 1),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(PrintQueueItem item, {required bool isLast}) {
    final busy = _printing.contains(item.document.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: Text(
              item.child.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.child.fullName,
                  style: AppText.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('Signed registration form', style: AppText.caption),
                Text(
                  'Signed ${formatDate(item.document.uploadedAt)}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: busy ? null : () => _print(item),
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }
}
