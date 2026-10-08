import 'package:flutter/material.dart';
import '../data/sync/sync_service.dart';
import '../screens/conflict_compare_screen.dart';
import '../theme/app_theme.dart';

/// Slim red banner shown under the top of both apps whenever
/// `sync_conflicts` has rows. One identical component on mobile and
/// desktop, because either side could be the one that has to choose.
class ConflictBanner extends StatefulWidget {
  const ConflictBanner({super.key});

  @override
  State<ConflictBanner> createState() => _ConflictBannerState();
}

class _ConflictBannerState extends State<ConflictBanner> {
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
    if (mounted) setState(() {});
  }

  String _message(int count, bool allPayments) {
    if (allPayments) {
      return count == 1 ? '1 payment needs review' : '$count payments need review';
    }
    return count == 1 ? '1 item needs review' : '$count items need review';
  }

  void _open() {
    final conflicts = SyncService.instance.conflicts;
    if (conflicts.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => conflicts.length == 1
            ? ConflictCompareScreen(conflict: conflicts.first)
            : const ConflictListScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = SyncService.instance.conflicts;
    if (conflicts.isEmpty) return const SizedBox.shrink();
    final allPayments = conflicts.every((c) => c.tableName == 'payments');

    return Material(
      color: AppColors.danger,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _message(conflicts.length, allPayments),
                  style: AppText.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
