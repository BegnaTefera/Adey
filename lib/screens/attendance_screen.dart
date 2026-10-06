import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/children_store.dart';
import '../models/child.dart';
import '../theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final child = children[index];
            final now = DateTime.now();
            final todayRecord = child.attendance.cast<AttendanceRecord?>().firstWhere(
              (record) =>
                record != null &&
                record.date.year == now.year &&
                record.date.month == now.month &&
                record.date.day == now.day,
              orElse: () => null,
              );

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    child.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.fullName, style: AppText.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        child.ageLabel,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _StatusPill(status: todayRecord?.status ?? AttendanceStatus.absent),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _markChild(child, AttendanceStatus.present),
                          child: const Text('In'),
                        ),
                        TextButton(
                          onPressed: () => _markChild(child, AttendanceStatus.late),
                          child: const Text('Late'),
                        ),
                      ],
                    ),
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
    final today = DateTime.now();
    final record = AttendanceRecord(
      id: const Uuid().v4(),
      date: today,
        checkIn: status == AttendanceStatus.absent
          ? null
          : DateFormat('HH:mm').format(today),
      checkOut: null,
      status: status,
    );

    final updatedAttendance =
        List<AttendanceRecord>.from(child.attendance)..insert(0, record);

    await ChildrenStore.instance.updateChild(
      child.copyWith(attendance: updatedAttendance),
    );
    // No local setState needed — the store's notifyListeners triggers
    // _onStoreChanged, which rebuilds this screen from the live list.
  }
}

class _StatusPill extends StatelessWidget {
  final AttendanceStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final info = switch (status) {
      AttendanceStatus.present => (AppColors.syncSoft, AppColors.sync, 'Present'),
      AttendanceStatus.absent => (AppColors.dangerSoft, AppColors.danger, 'Absent'),
      AttendanceStatus.late => (AppColors.pendingSoft, AppColors.pendingTextDark, 'Late'),
      AttendanceStatus.excused => (AppColors.muted, AppColors.mutedForeground, 'Excused'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: info.$1,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        info.$3,
        style: AppText.monoCaption.copyWith(
          color: info.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
