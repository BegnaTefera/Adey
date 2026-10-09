import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/children_store.dart';
import '../models/child.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/child_avatar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final Set<String> _savingChildIds = {};

  @override
  void initState() {
    super.initState();
    ChildrenStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ChildrenStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  AttendanceRecord? _todayRecord(Child child) {
    final now = DateTime.now();
    for (final record in child.attendance) {
      if (record.date.year == now.year &&
          record.date.month == now.month &&
          record.date.day == now.day) {
        return record;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final children = ChildrenStore.instance.children
        .where((c) => c.enrollmentStatus == EnrollmentStatus.enrolled)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Attendance', style: AppText.sectionTitle),
      ),
      body: children.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      size: 32,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(height: 12),
                    Text('No enrolled children to mark today.',
                        style: AppText.bodyMedium),
                  ],
                ),
              ),
            )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final child = children[index];
          final todayRecord = _todayRecord(child);
          final present = todayRecord?.status == AttendanceStatus.present;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Row(
              children: [
                ChildAvatar(child: child, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.fullName, style: AppText.bodyMedium),
                      const SizedBox(height: 4),
                      Text(child.ageLabel, style: AppText.caption),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: '${child.fullName} attendance',
                      value: present ? 'Present' : 'Absent',
                      child: Switch(
                        value: present,
                        onChanged: _savingChildIds.contains(child.id)
                            ? null
                            : (value) => _markChild(
                                  child,
                                  value
                                      ? AttendanceStatus.present
                                      : AttendanceStatus.absent,
                                ),
                        activeThumbColor: AppColors.primary,
                      ),
                    ),
                    if (_savingChildIds.contains(child.id)) ...[
                      const SizedBox(width: 4),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _markChild(Child child, AttendanceStatus status) async {
    if (_savingChildIds.contains(child.id)) return;
    setState(() => _savingChildIds.add(child.id));
    try {
    final today = DateTime.now();
    final existing = _todayRecord(child);

    final record = AttendanceRecord(
      id: existing?.id ?? const Uuid().v4(),
      date: today,
      checkIn: status == AttendanceStatus.present
          ? (existing?.checkIn ?? DateFormat('HH:mm').format(today))
          : null,
      checkOut: existing?.checkOut,
      status: status,
    );

    // Update today's record in place if one exists, instead of always
    // inserting — otherwise toggling twice in one day leaves two rows
    // for the same date.
    final updatedAttendance = List<AttendanceRecord>.from(child.attendance);
    final existingIndex = existing == null ? -1 : updatedAttendance.indexWhere((r) => r.id == existing.id);
    if (existingIndex >= 0) {
      updatedAttendance[existingIndex] = record;
    } else {
      updatedAttendance.insert(0, record);
    }

    await ChildrenStore.instance.updateChild(
      child.copyWith(attendance: updatedAttendance),
    );
      if (mounted) {
        showAppFeedback(
          context,
          message: '${child.firstName} marked ${status.name}.',
          kind: AppFeedbackKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Could not save attendance. Try again. $error',
          kind: AppFeedbackKind.error,
          actionLabel: 'Retry',
          onAction: () => _markChild(child, status),
        );
      }
    } finally {
      if (mounted) setState(() => _savingChildIds.remove(child.id));
    }
  }
}
