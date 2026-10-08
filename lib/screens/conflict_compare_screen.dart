import 'package:flutter/material.dart';
import '../data/children_store.dart';
import '../data/formatters.dart';
import '../data/settings_store.dart';
import '../data/sync/sync_models.dart';
import '../data/sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

/// Which of a conflict's two versions came from the phone and which from
/// the desktop. A conflict is recorded on whichever device received the
/// other's row, so "local" is mobile on one and desktop on the other.
({Map<String, dynamic> mobile, Map<String, dynamic> desktop}) _sides(
  SyncConflict conflict,
) {
  final onDesktop = SettingsStore.instance.isDesktop;
  return (
    mobile: onDesktop ? conflict.remoteData : conflict.localData,
    desktop: onDesktop ? conflict.localData : conflict.remoteData,
  );
}

String _childNameFor(SyncConflict conflict) {
  final childId = (conflict.localData['child_id'] ??
      conflict.remoteData['child_id']) as String?;
  if (childId == null) return 'Unknown record';
  return ChildrenStore.instance.byId(childId)?.fullName ?? 'Unknown child';
}

/// When more than one conflict is waiting, the banner opens this list.
class ConflictListScreen extends StatefulWidget {
  const ConflictListScreen({super.key});

  @override
  State<ConflictListScreen> createState() => _ConflictListScreenState();
}

class _ConflictListScreenState extends State<ConflictListScreen> {
  @override
  void initState() {
    super.initState();
    SyncService.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (SyncService.instance.conflicts.isEmpty) {
      // Only close if this list is what's on screen; if the compare screen
      // is on top it will pop itself and we close in its `.then` below.
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = SyncService.instance.conflicts;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Needs review', style: AppText.sectionTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < conflicts.length; i++)
                  InkWell(
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator
                          .push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ConflictCompareScreen(conflict: conflicts[i]),
                            ),
                          )
                          .then((_) {
                        if (!mounted) return;
                        if (SyncService.instance.conflicts.isEmpty) {
                          if (navigator.canPop()) {
                            navigator.pop();
                          }
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        border: i == conflicts.length - 1
                            ? null
                            : const Border(
                                bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_childNameFor(conflicts[i]),
                                    style: AppText.bodyMedium),
                                Text(
                                  '${conflicts[i].remoteData['fee_type_name'] ?? conflicts[i].tableName}'
                                  ' · ${conflicts[i].remoteData['description'] ?? ''}',
                                  style: AppText.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 18, color: AppColors.mutedForeground),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Side-by-side compare: mobile's version on the left, desktop's on the
/// right, differing fields highlighted, and a button to keep either one.
/// Nothing is resolved automatically and nothing times out.
class ConflictCompareScreen extends StatefulWidget {
  final SyncConflict conflict;

  const ConflictCompareScreen({super.key, required this.conflict});

  @override
  State<ConflictCompareScreen> createState() => _ConflictCompareScreenState();
}

class _ConflictCompareScreenState extends State<ConflictCompareScreen> {
  bool _busy = false;

  static const _paymentFields = <(String, String)>[
    ('fee_type_name', 'Fee'),
    ('description', 'Description'),
    ('amount', 'Amount'),
    ('status', 'Status'),
    ('due_date', 'Due date'),
    ('paid_at', 'Paid on'),
    ('cycle_label', 'Billing cycle'),
  ];

  List<(String, String)> _fields() {
    if (widget.conflict.tableName == 'payments') return _paymentFields;
    final keys = {
      ...widget.conflict.localData.keys,
      ...widget.conflict.remoteData.keys,
    }..removeAll(const ['id', 'updated_at', 'child_id']);
    return [for (final k in keys) (k, k.replaceAll('_', ' '))];
  }

  String _display(String key, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) return '—';
    switch (key) {
      case 'amount':
        return value is num ? formatEtb(value.toDouble()) : '$value';
      case 'due_date':
      case 'paid_at':
        final date = DateTime.tryParse('$value');
        return date == null ? '$value' : formatDate(date);
      case 'status':
        final s = '$value';
        return s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
      default:
        return '$value';
    }
  }

  String _editedAt(Map<String, dynamic> row) {
    final at = DateTime.tryParse('${row['updated_at'] ?? ''}');
    return at == null ? '—' : formatDateTime(at);
  }

  Future<void> _resolve({required bool keepMobile}) async {
    if (_busy) return;
    setState(() => _busy = true);
    // "Local" is whichever side this device is.
    final keepLocal = keepMobile != SettingsStore.instance.isDesktop;
    try {
      await SyncService.instance.resolveConflict(
        widget.conflict,
        keepLocal: keepLocal,
      );
      if (!mounted) return;
      showAppFeedback(
        context,
        message: keepMobile ? 'Kept the mobile version.' : 'Kept the desktop version.',
        kind: AppFeedbackKind.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppFeedback(
        context,
        message: 'Could not save your choice. $e',
        kind: AppFeedbackKind.error,
      );
    }
  }

  Widget _cell(String text, {required bool differs, bool bold = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: differs ? AppColors.pendingSoft : AppColors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: differs ? AppColors.pendingBorder : Colors.transparent,
        ),
      ),
      child: Text(
        text,
        style: AppText.bodyRegular.copyWith(
          fontWeight: differs || bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sides = _sides(widget.conflict);
    final fields = _fields();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Review payment', style: AppText.sectionTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_childNameFor(widget.conflict), style: AppText.pageTitle),
          const SizedBox(height: 4),
          Text(
            'This was changed on both the phone and the desktop. '
            'Highlighted fields are different. Choose which version to keep.',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('MOBILE', style: AppText.monoLabel)),
              const SizedBox(width: 10),
              Expanded(child: Text('DESKTOP', style: AppText.monoLabel)),
            ],
          ),
          const SizedBox(height: 8),
          for (final (key, label) in fields) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 6),
              child: Text(label, style: AppText.caption),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _cell(
                    _display(key, sides.mobile[key]),
                    differs: sides.mobile[key] != sides.desktop[key],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _cell(
                    _display(key, sides.desktop[key]),
                    differs: sides.mobile[key] != sides.desktop[key],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Edited ${_editedAt(sides.mobile)}',
                    style: AppText.caption),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Edited ${_editedAt(sides.desktop)}',
                    style: AppText.caption),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _resolve(keepMobile: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.foreground,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Keep mobile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _resolve(keepMobile: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Keep desktop'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
