import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/attendance_schedule.dart';
import '../data/children_store.dart';
import '../data/date_range.dart';
import '../data/formatters.dart';
import '../data/search_utils.dart';
import '../data/settings_store.dart';
import '../models/child.dart';
import '../theme/app_theme.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/child_avatar.dart';
import '../widgets/empty_illustration.dart';
import '../widgets/metric_card.dart';
import '../widgets/range_filter.dart';

enum _HistorySort { rate, name }

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _saving = {};
  final TextEditingController _registerSearch = TextEditingController();
  final TextEditingController _historySearch = TextEditingController();

  late final TabController _tabs;
  int _activeTab = 0;

  DateTime _day = AttendanceSchedule.operatingDay();
  DateRangePreset _rangePreset = DateRangePreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  String? _ageGroup;
  String? _statusFilter;
  _HistorySort _historySort = _HistorySort.rate;

  @override
  void initState() {
    super.initState();
    ChildrenStore.instance.addListener(_onStoreChanged);
    _registerSearch.addListener(_onStoreChanged);
    _historySearch.addListener(_onStoreChanged);
    _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    ChildrenStore.instance.removeListener(_onStoreChanged);
    _registerSearch.removeListener(_onStoreChanged);
    _historySearch.removeListener(_onStoreChanged);
    _registerSearch.dispose();
    _historySearch.dispose();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (_activeTab == _tabs.index) return;
    setState(() => _activeTab = _tabs.index);
  }

  List<Child> get _enrolled {
    final children = ChildrenStore.instance.children
        .where((c) => c.enrollmentStatus == EnrollmentStatus.enrolled)
        .toList();
    children.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return children;
  }

  bool _matchesChild(Child child, String query) {
    return matchesAllTokens(
      haystacks: [
        normalizeForSearch(child.firstName),
        normalizeForSearch(child.lastName),
        normalizeForSearch(child.fullName),
      ],
      normalizedQuery: normalizeForSearch(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = _enrolled;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Attendance', style: AppText.sectionTitle),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _activeTab == 0
                    ? _daySummaryStrip(enrolled)
                    : _rangeSummaryStrip(enrolled),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TabBar(
                  controller: _tabs,
                  labelColor: AppColors.foreground,
                  unselectedLabelColor: AppColors.mutedForeground,
                  indicatorColor: AppColors.primary,
                  labelStyle: const TextStyle(
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Register'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabs,
          children: [
            _registerTab(enrolled),
            _historyTab(enrolled),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------

  Widget _daySummaryStrip(List<Child> enrolled) {
    var present = 0;
    var absent = 0;
    var unmarked = 0;
    for (final child in enrolled) {
      final record = _recordFor(child, _day);
      if (record == null) {
        unmarked++;
      } else if (record.status == AttendanceStatus.present) {
        present++;
      } else {
        absent++;
      }
    }
    final marked = present + absent;
    final rate = marked == 0 ? 0 : (present / marked * 100).round();

    return MetricStrip(
      children: [
        MetricCard(
          label: 'Present',
          value: '$present',
          subtitle: 'checked in',
          icon: Icons.check_circle_outline,
          accent: AppColors.sync,
          valueColor: AppColors.sync,
        ),
        MetricCard(
          label: 'Absent',
          value: '$absent',
          subtitle: 'not in',
          icon: Icons.cancel_outlined,
          accent: AppColors.danger,
          valueColor: AppColors.danger,
        ),
        MetricCard(
          label: 'Unmarked',
          value: '$unmarked',
          subtitle: 'need a tap',
          icon: Icons.radio_button_unchecked,
          accent: AppColors.pendingTextDark,
          valueColor: AppColors.pendingTextDark,
        ),
        MetricCard(
          label: 'Rate',
          value: '$rate%',
          subtitle: 'of marked',
          icon: Icons.insights_outlined,
          accent: AppColors.primary,
        ),
      ],
    );
  }

  Widget _rangeSummaryStrip(List<Child> enrolled) {
    final et = SettingsStore.instance.useEthiopianCalendar;
    final range = _range;
    var present = 0;
    var absent = 0;
    for (final child in enrolled) {
      for (final record in child.attendance) {
        if (!range.contains(record.date, ethiopian: et)) continue;
        if (record.status == AttendanceStatus.present) {
          present++;
        } else {
          absent++;
        }
      }
    }
    final sessions = present + absent;
    final rate = sessions == 0 ? 0 : (present / sessions * 100).round();

    return MetricStrip(
      children: [
        MetricCard(
          label: 'Sessions',
          value: '$sessions',
          subtitle: _rangePreset.label,
          icon: Icons.event_note_outlined,
          accent: AppColors.primary,
        ),
        MetricCard(
          label: 'Present',
          value: '$present',
          subtitle: 'check-ins',
          icon: Icons.check_circle_outline,
          accent: AppColors.sync,
          valueColor: AppColors.sync,
        ),
        MetricCard(
          label: 'Absent',
          value: '$absent',
          subtitle: 'misses',
          icon: Icons.cancel_outlined,
          accent: AppColors.danger,
          valueColor: AppColors.danger,
        ),
        MetricCard(
          label: 'Rate',
          value: '$rate%',
          subtitle: 'attendance',
          icon: Icons.insights_outlined,
          accent: AppColors.accent,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------

  Widget _registerTab(List<Child> enrolled) {
    if (enrolled.isEmpty) return _noChildren();

    var present = 0;
    var absent = 0;
    var unmarked = 0;
    for (final child in enrolled) {
      final record = _recordFor(child, _day);
      if (record == null) {
        unmarked++;
      } else if (record.status == AttendanceStatus.present) {
        present++;
      } else {
        absent++;
      }
    }

    final groups = {for (final child in enrolled) _ageGroupOf(child)};

    final filtered = enrolled.where((child) {
      if (_ageGroup != null && _ageGroupOf(child) != _ageGroup) return false;
      final record = _recordFor(child, _day);
      switch (_statusFilter) {
        case 'present':
          if (record?.status != AttendanceStatus.present) return false;
        case 'absent':
          if (record?.status != AttendanceStatus.absent) return false;
        case 'unmarked':
          if (record != null) return false;
      }
      if (_registerSearch.text.trim().isNotEmpty &&
          !_matchesChild(child, _registerSearch.text)) {
        return false;
      }
      return true;
    }).toList();

    final filtersActive = _registerSearch.text.trim().isNotEmpty ||
        _ageGroup != null ||
        _statusFilter != null;

    return ListView(
      key: const PageStorageKey('attendance-register'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      children: [
        _daySelector(),
        const SizedBox(height: 16),
        if (AttendanceSchedule.isDayOff(_day))
          const EmptyIllustration(
            icon: Icons.weekend_outlined,
            title: 'Sunday day off',
            message: 'The daycare is closed on Sundays, so there is no '
                'register. Pick another day to take attendance.',
          )
        else ...[
          _registerFilters(groups, enrolled.length, present, absent, unmarked),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            EmptyIllustration(
              icon: Icons.search_off_outlined,
              title: 'No children match',
              message: 'Try a different name, age group, or status.',
              actionLabel: 'Clear filters',
              onAction: filtersActive ? _clearRegisterFilters : null,
              actionIcon: Icons.filter_alt_off_outlined,
            )
          else ...[
            _registerHeader(filtered),
            const SizedBox(height: 12),
            for (final child in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AttendanceRow(
                  child: child,
                  record: _recordFor(child, _day),
                  saving: _saving.contains(child.id),
                  onChanged: (status) => _setStatus(child, status),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _daySelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REGISTER FOR', style: AppText.monoLabel),
                const SizedBox(height: 2),
                Text(
                  formatDate(_day),
                  style: AppText.sectionTitle.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          if (!AttendanceSchedule.isCurrentOperatingDay(_day))
            TextButton(
              onPressed: () =>
                  setState(() => _day = AttendanceSchedule.operatingDay()),
              child: const Text('Today'),
            ),
          OutlinedButton.icon(
            onPressed: _pickDay,
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _registerFilters(
    Set<String> groups,
    int total,
    int present,
    int absent,
    int unmarked,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _registerSearch,
            decoration: InputDecoration(
              labelText: 'Search children',
              hintText: 'Name',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _registerSearch.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _registerSearch.clear(),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text('AGE GROUP', style: AppText.monoLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                selected: _ageGroup == null,
                label: 'All',
                onTap: () => setState(() => _ageGroup = null),
              ),
              for (final group in groups)
                _filterChip(
                  selected: _ageGroup == group,
                  label: _ageGroupLabel(group),
                  onTap: () => setState(() => _ageGroup = group),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('STATUS', style: AppText.monoLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                selected: _statusFilter == null,
                label: 'All ($total)',
                onTap: () => setState(() => _statusFilter = null),
              ),
              _filterChip(
                selected: _statusFilter == 'present',
                label: 'Present ($present)',
                onTap: () => setState(() => _statusFilter = 'present'),
              ),
              _filterChip(
                selected: _statusFilter == 'absent',
                label: 'Absent ($absent)',
                onTap: () => setState(() => _statusFilter = 'absent'),
              ),
              _filterChip(
                selected: _statusFilter == 'unmarked',
                label: 'Unmarked ($unmarked)',
                onTap: () => setState(() => _statusFilter = 'unmarked'),
              ),
            ],
          ),
          if (_registerSearch.text.trim().isNotEmpty ||
              _ageGroup != null ||
              _statusFilter != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearRegisterFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return AppFilterChip(
      label: label,
      selected: selected,
      onSelected: onTap,
    );
  }

  // ---------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------

  Widget _historyTab(List<Child> enrolled) {
    if (enrolled.isEmpty) return _noChildren();

    final et = SettingsStore.instance.useEthiopianCalendar;
    final range = _range;

    final rows = <_ChildAttendance>[];
    for (final child in enrolled) {
      var present = 0;
      var absent = 0;
      for (final record in child.attendance) {
        if (!range.contains(record.date, ethiopian: et)) continue;
        if (record.status == AttendanceStatus.present) {
          present++;
        } else {
          absent++;
        }
      }
      if (present + absent > 0) {
        rows.add(_ChildAttendance(child, present, absent));
      }
    }

    final searched = _historySearch.text.trim().isEmpty
        ? rows
        : rows
            .where((r) => _matchesChild(r.child, _historySearch.text))
            .toList();
    final sorted = [...searched]
      ..sort((a, b) => switch (_historySort) {
            _HistorySort.rate => b.rate.compareTo(a.rate),
            _HistorySort.name => a.child.fullName
                .toLowerCase()
                .compareTo(b.child.fullName.toLowerCase()),
          });

    return ListView(
      key: const PageStorageKey('attendance-history'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: RangeFilter(
            preset: _rangePreset,
            customStart: _customStart,
            customEnd: _customEnd,
            onChanged: (preset) => setState(() {
              _rangePreset = preset;
            }),
            onPickStart: () => _pickCustom(start: true),
            onPickEnd: () => _pickCustom(start: false),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _historySearch,
          decoration: InputDecoration(
            labelText: 'Search by child',
            hintText: 'Name',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _historySearch.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _historySearch.clear(),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        _historyHeader(sorted.length, rows.isNotEmpty),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          EmptyIllustration(
            icon: Icons.event_busy_outlined,
            title: 'No attendance in this range',
            message: 'Pick a wider date range, or mark attendance to start '
                'building history.',
            actionLabel: 'Show all time',
            onAction: () => setState(() {
              _rangePreset = DateRangePreset.allTime;
              _customStart = null;
              _customEnd = null;
            }),
            actionIcon: Icons.all_inclusive,
          )
        else if (sorted.isEmpty)
          const EmptyIllustration(
            icon: Icons.search_off_outlined,
            title: 'No children match',
            message: 'Try a different name.',
          )
        else
          _AttendanceTable(rows: sorted),
      ],
    );
  }

  Widget _historyHeader(int count, bool showSort) {
    return Row(
      children: [
        Text('HISTORY', style: AppText.monoLabel),
        const Spacer(),
        Text(
          '$count ${count == 1 ? 'child' : 'children'}',
          style: AppText.caption,
        ),
        if (showSort) ...[
          const SizedBox(width: 12),
          SegmentedButton<_HistorySort>(
            segments: const [
              ButtonSegment(
                value: _HistorySort.rate,
                label: Text('Rate'),
              ),
              ButtonSegment(
                value: _HistorySort.name,
                label: Text('Name'),
              ),
            ],
            selected: {_historySort},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (selection) =>
                setState(() => _historySort = selection.first),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------

  Widget _registerHeader(List<Child> filtered) {
    final canMarkAll = filtered
        .any((c) => _recordFor(c, _day)?.status != AttendanceStatus.present);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('REGISTER', style: AppText.monoLabel),
        Text(
          '${filtered.length} ${filtered.length == 1 ? 'child' : 'children'}',
          style: AppText.caption,
        ),
        TextButton.icon(
          onPressed: canMarkAll ? () => _markAllPresent(filtered) : null,
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('All present'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _noChildren() {
    return const EmptyIllustration(
      icon: Icons.event_available_outlined,
      title: 'No enrolled children',
      message: 'Register and enroll a child to start taking attendance.',
    );
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  AttendanceRecord? _recordFor(Child child, DateTime day) {
    for (final record in child.attendance) {
      if (_sameDay(record.date, day)) return record;
    }
    return null;
  }

  DateRange get _range =>
      DateRange(_rangePreset, start: _customStart, end: _customEnd);

  Future<void> _pickDay() async {
    final picked = await showAppDatePicker(
      context: context,
      title: 'Select day',
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = picked);
  }

  Future<void> _pickCustom({required bool start}) async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      title: start ? 'Start date' : 'End date',
      initialDate: (start ? _customStart : _customEnd) ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _customStart = picked;
        if (_customEnd == null || _customEnd!.isBefore(picked)) {
          _customEnd = picked;
        }
      } else {
        _customEnd = picked;
        if (_customStart == null || _customStart!.isAfter(picked)) {
          _customStart = picked;
        }
      }
      _rangePreset = DateRangePreset.custom;
    });
  }

  void _clearRegisterFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _registerSearch.clear();
      _ageGroup = null;
      _statusFilter = null;
    });
  }

  Child _withStatus(Child child, DateTime day, AttendanceStatus? status) {
    final existing = _recordFor(child, day);
    final updated = List<AttendanceRecord>.from(child.attendance);

    if (status == null) {
      updated.removeWhere((record) => _sameDay(record.date, day));
    } else {
      final record = AttendanceRecord(
        id: existing?.id ?? const Uuid().v4(),
        date: day,
        checkIn: status == AttendanceStatus.present
            ? (existing?.checkIn ??
                (AttendanceSchedule.isCurrentOperatingDay(day)
                    ? DateFormat('HH:mm').format(DateTime.now())
                    : null))
            : null,
        checkOut: existing?.checkOut,
        status: status,
      );
      final index = existing == null
          ? -1
          : updated.indexWhere((r) => r.id == existing.id);
      if (index >= 0) {
        updated[index] = record;
      } else {
        updated.insert(0, record);
      }
    }

    return child.copyWith(attendance: updated);
  }

  Future<void> _setStatus(Child child, AttendanceStatus? status) async {
    if (_saving.contains(child.id)) return;
    if (AttendanceSchedule.isDayOff(_day)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving.add(child.id));
    try {
      await ChildrenStore.instance.updateChild(_withStatus(child, _day, status));
      if (!mounted) return;
      showAppFeedback(
        context,
        message: status == null
            ? '${child.firstName} unmarked.'
            : '${child.firstName} marked ${status.name}.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not save attendance. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _setStatus(child, status),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(child.id));
    }
  }

  Future<void> _markAllPresent(List<Child> children) async {
    if (AttendanceSchedule.isDayOff(_day)) return;
    final targets = children
        .where((c) => _recordFor(c, _day)?.status != AttendanceStatus.present)
        .toList();
    if (targets.isEmpty) return;
    FocusScope.of(context).unfocus();
    final ids = targets.map((c) => c.id).toList();
    setState(() => _saving.addAll(ids));
    try {
      final updates = targets
          .map((c) => _withStatus(c, _day, AttendanceStatus.present));
      await ChildrenStore.instance.updateChildren(updates);
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Marked ${targets.length} '
            '${targets.length == 1 ? 'child' : 'children'} present.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not save attendance. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _markAllPresent(children),
      );
    } finally {
      if (mounted) setState(() => _saving.removeAll(ids));
    }
  }
}

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _ageGroupOf(Child child) {
  final months = child.ageInMonths;
  if (months < 12) return 'infant';
  if (months < 36) return 'toddler';
  return 'preschool';
}

String _ageGroupLabel(String group) => switch (group) {
      'infant' => 'Infant',
      'toddler' => 'Toddler',
      'preschool' => 'Preschool',
      _ => group,
    };

// ---------------------------------------------------------------------
// Register row
// ---------------------------------------------------------------------

class _AttendanceRow extends StatelessWidget {
  final Child child;
  final AttendanceRecord? record;
  final bool saving;
  final ValueChanged<AttendanceStatus?> onChanged;

  const _AttendanceRow({
    required this.child,
    required this.record,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(child.fullName, style: AppText.bodyMedium),
              const SizedBox(height: 4),
              Text(
                '${child.ageLabel} · ${_ageGroupLabel(_ageGroupOf(child))}',
                style: AppText.caption,
              ),
            ],
          );

          if (wide) {
            return Row(
              children: [
                ChildAvatar(child: child, radius: 20),
                const SizedBox(width: 12),
                Expanded(child: identity),
                _StatusPill(status: record?.status),
                const SizedBox(width: 16),
                _MarkToggle(
                  status: record?.status,
                  saving: saving,
                  onChanged: onChanged,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChildAvatar(child: child, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(child: identity),
                  _StatusPill(status: record?.status),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _MarkToggle(
                  status: record?.status,
                  saving: saving,
                  onChanged: onChanged,
                  expand: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MarkToggle extends StatelessWidget {
  final AttendanceStatus? status;
  final bool saving;
  final ValueChanged<AttendanceStatus?> onChanged;
  final bool expand;

  const _MarkToggle({
    required this.status,
    required this.saving,
    required this.onChanged,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AttendanceStatus>(
      segments: const [
        ButtonSegment(
          value: AttendanceStatus.present,
          label: Text('Present'),
          icon: Icon(Icons.check, size: 16),
        ),
        ButtonSegment(
          value: AttendanceStatus.absent,
          label: Text('Absent'),
          icon: Icon(Icons.close, size: 16),
        ),
      ],
      selected: status == null ? const {} : {status!},
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      expandedInsets: expand ? EdgeInsets.zero : null,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelectionChanged: saving
          ? null
          : (selection) => onChanged(selection.isEmpty ? null : selection.first),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final AttendanceStatus? status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (status) {
      AttendanceStatus.present => (
          AppColors.syncSoft,
          AppColors.primary,
          Icons.check_circle_outline,
          'Present',
        ),
      AttendanceStatus.absent => (
          AppColors.dangerSoft,
          AppColors.danger,
          Icons.cancel_outlined,
          'Absent',
        ),
      null => (
          AppColors.pendingSoft,
          AppColors.pendingTextDark,
          Icons.radio_button_unchecked,
          'Unmarked',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.monoCaption.copyWith(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// History table
// ---------------------------------------------------------------------

class _ChildAttendance {
  final Child child;
  final int present;
  final int absent;

  const _ChildAttendance(this.child, this.present, this.absent);

  int get sessions => present + absent;
  int get rate => sessions == 0 ? 0 : (present / sessions * 100).round();
}

class _AttendanceTable extends StatelessWidget {
  final List<_ChildAttendance> rows;

  const _AttendanceTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSessions = constraints.maxWidth >= 520;
        final showBars = constraints.maxWidth >= 680;
        return Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _header(showSessions, showBars),
              for (final row in rows) _row(row, showSessions, showBars),
            ],
          ),
        );
      },
    );
  }

  Widget _header(bool showSessions, bool showBars) {
    final style = AppText.monoLabel.copyWith(fontSize: 10);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.muted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('CHILD', style: style)),
          if (showSessions)
            SizedBox(
              width: 90,
              child: Text('SESSIONS', style: style, textAlign: TextAlign.center),
            ),
          SizedBox(
            width: 84,
            child: Text('PRESENT', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 84,
            child: Text('ABSENT', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: showBars ? 150 : 60,
            child: Text('RATE', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _row(_ChildAttendance row, bool showSessions, bool showBars) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ChildAvatar(child: row.child, radius: 16, fontSize: 11),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.child.fullName,
                    style: AppText.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (showSessions)
            SizedBox(
              width: 90,
              child: Text(
                '${row.sessions}',
                style: AppText.bodyRegular,
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: 84,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${row.present}',
                  style: AppText.bodyRegular.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.close, size: 13, color: AppColors.danger),
                const SizedBox(width: 4),
                Text(
                  '${row.absent}',
                  style: AppText.bodyRegular.copyWith(color: AppColors.danger),
                ),
              ],
            ),
          ),
          SizedBox(
            width: showBars ? 150 : 60,
            child: showBars
                ? Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label:
                              '${row.child.fullName} attendance ${row.rate} percent',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: row.rate / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.muted,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${row.rate}%',
                          style: AppText.monoCaption.copyWith(
                            color: AppColors.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '${row.rate}%',
                    style: AppText.monoCaption.copyWith(
                      color: AppColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }
}
