import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../data/children_store.dart';
import '../models/authorized_pickup.dart';
import '../models/child.dart';
import '../theme/app_theme.dart';

enum _Tab { info, guardians, documents, attendance, payments }

class ChildProfileScreen extends StatefulWidget {
  final Child child;

  const ChildProfileScreen({super.key, required this.child});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  _Tab _activeTab = _Tab.info;
  late Child _child = widget.child;

  static const _tabs = [
    (_Tab.info, 'Info'),
    (_Tab.guardians, 'Guardians'),
    (_Tab.documents, 'Documents'),
    (_Tab.attendance, 'Attendance'),
    (_Tab.payments, 'Payments'),
  ];

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
    final updated = ChildrenStore.instance.byId(widget.child.id);
    if (updated != null && mounted) {
      setState(() => _child = updated);
    }
  }

  Future<void> _addPickupPerson() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add authorized pickup', style: AppText.sectionTitle),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.of(sheetContext).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );

    if (added != true) return;

    final newPerson = AuthorizedPickup(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
    );

    await ChildrenStore.instance.updateChild(
      _child.copyWith(
        additionalPickupPeople: [..._child.additionalPickupPeople, newPerson],
      ),
    );
  }

  Future<void> _removePickupPerson(AuthorizedPickup person) async {
    final updated = List<AuthorizedPickup>.from(_child.additionalPickupPeople)
      ..remove(person);
    await ChildrenStore.instance.updateChild(
      _child.copyWith(additionalPickupPeople: updated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.card,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chevron_left,
                              size: 18, color: AppColors.primary),
                          Text('Children',
                              style: AppText.bodyRegular
                                  .copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          child.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(child.fullName, style: AppText.sectionTitle),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(child.ageLabel, style: AppText.caption),
                              const SizedBox(width: 8),
                              Text('·', style: AppText.caption),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: child.enrollmentStatus ==
                                          EnrollmentStatus.enrolled
                                      ? AppColors.syncSoft
                                      : AppColors.muted,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  child.enrollmentStatus ==
                                          EnrollmentStatus.enrolled
                                      ? 'Enrolled'
                                      : 'Withdrawn',
                                  style: AppText.monoCaption.copyWith(
                                    color: child.enrollmentStatus ==
                                            EnrollmentStatus.enrolled
                                        ? AppColors.sync
                                        : AppColors.mutedForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _tabs.map((t) {
                        final selected = _activeTab == t.$1;
                        return GestureDetector(
                          onTap: () => setState(() => _activeTab = t.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 2,
                                  color: selected
                                      ? AppColors.foreground
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(
                              t.$2,
                              style: AppText.bodyMedium.copyWith(
                                color: selected
                                    ? AppColors.foreground
                                    : AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: switch (_activeTab) {
                  _Tab.info => _InfoTab(child: child),
                  _Tab.guardians => _GuardiansTab(
                      child: child,
                      onAddPickup: _addPickupPerson,
                      onRemovePickup: _removePickupPerson,
                    ),
                  _Tab.documents => _DocumentsTab(child: child),
                  _Tab.attendance => _AttendanceTab(child: child),
                  _Tab.payments => _PaymentsTab(child: child),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Child child;
  const _InfoTab({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('PERSONAL', style: AppText.monoLabel),
              ),
              _Row('Full name', child.fullName),
              _Row('Gender', child.gender == Gender.male ? 'Male' : 'Female'),
              _Row('Date of birth',
                  DateFormat('MMM d, yyyy').format(child.dob)),
              _Row('Age', child.ageLabel),
              _Row('Enrolled since',
                  DateFormat('MMMM d, yyyy').format(child.enrolledSince),
                  isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('ALLERGIES', style: AppText.monoLabel),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: child.allergies.isEmpty
                    ? Text('No known allergies', style: AppText.caption)
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: child.allergies
                            .map((a) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    a,
                                    style: AppText.caption.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                  ),
                                ))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _notesCard('HEALTH CONDITION', child.healthCondition),
        const SizedBox(height: 20),
        _notesCard('DIETARY CONDITION', child.dietaryNotes),
        const SizedBox(height: 20),
        _notesCard('SPECIAL CHARACTERISTICS', child.specialCharacteristics),
      ],
    );
  }

  Widget _notesCard(String title, String value) {
    return Container(
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(title, style: AppText.monoLabel),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Text(
              value.isEmpty ? 'None recorded.' : value,
              style: AppText.bodyRegular.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _Row(this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.caption),
          Flexible(
              child: Text(value,
                  style: AppText.bodyRegular, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

List<Widget> _guardianDetailRows(Guardian g) {
  final rows = <(String, String)>[
    ('Phone', g.phone),
    if (g.addressSummary.isNotEmpty) ('Address', g.addressSummary),
    if (g.email.isNotEmpty) ('Email', g.email),
  ];
  return List.generate(
    rows.length,
    (i) => _Row(rows[i].$1, rows[i].$2, isLast: i == rows.length - 1),
  );
}

class _GuardiansTab extends StatelessWidget {
  final Child child;
  final VoidCallback onAddPickup;
  final ValueChanged<AuthorizedPickup> onRemovePickup;

  const _GuardiansTab({
    required this.child,
    required this.onAddPickup,
    required this.onRemovePickup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...child.guardians.map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary,
                      child: Text(g.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name,
                              style: AppText.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            g.relationship +
                                (g.isPrimary ? ' · Primary contact' : ''),
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    if (g.authorizedPickup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.syncSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('Pickup ✓',
                            style: AppText.monoCaption
                                .copyWith(color: AppColors.sync)),
                      ),
                  ],
                ),
              ),
              ..._guardianDetailRows(g),
            ],
          ),
        );
      }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('AUTHORIZED PICKUPS', style: AppText.monoLabel),
            TextButton.icon(
              onPressed: onAddPickup,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Guardians above are already authorized to pick up this child. '
          'Anyone else who may do so is listed here.',
          style: AppText.caption,
        ),
        const SizedBox(height: 12),
        if (child.additionalPickupPeople.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No additional pickup people added yet.',
                style: AppText.caption),
          )
        else
          Container(
            decoration: cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(child.additionalPickupPeople.length, (i) {
                final person = child.additionalPickupPeople[i];
                final isLast = i == child.additionalPickupPeople.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(person.name, style: AppText.bodyMedium),
                            if (person.phone.isNotEmpty)
                              Text(person.phone, style: AppText.caption),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onRemovePickup(person),
                        child: const Icon(Icons.close,
                            size: 18, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final Child child;
  const _DocumentsTab({required this.child});

  static const _icons = {
    DocumentType.id: '🪪',
    DocumentType.photo: '🖼️',
    DocumentType.immunization: '💉',
    DocumentType.registration: '📋',
    DocumentType.other: '📄',
  };

  (Color, Color) _statusColors(DocumentStatus s) {
    return switch (s) {
      DocumentStatus.onFile => (AppColors.syncSoft, AppColors.sync),
      DocumentStatus.pending =>
        (AppColors.pendingSoft, AppColors.pendingTextDark),
      DocumentStatus.expired => (AppColors.dangerSoft, AppColors.danger),
    };
  }

  String _statusLabel(DocumentStatus s) => switch (s) {
        DocumentStatus.onFile => 'On file',
        DocumentStatus.pending => 'Pending',
        DocumentStatus.expired => 'Expired',
      };

  @override
  Widget build(BuildContext context) {
    if (child.documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text('No documents on file yet', style: AppText.caption),
        ),
      );
    }
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(child.documents.length, (i) {
          final doc = child.documents[i];
          final isLast = i == child.documents.length - 1;
          final (bg, fg) = _statusColors(doc.status);
          final canOpen = doc.filePath != null && doc.filePath!.isNotEmpty;
          return InkWell(
            onTap: () => _openDocument(context, doc),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(_icons[doc.type] ?? '📄',
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.label, style: AppText.bodyMedium),
                        Text(DateFormat('MMM d, yyyy').format(doc.uploadedAt),
                            style: AppText.caption),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(_statusLabel(doc.status),
                        style: AppText.monoCaption
                            .copyWith(color: fg, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    canOpen ? Icons.chevron_right : Icons.hourglass_empty,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, ChildDocument doc) async {
    final path = doc.filePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This document hasn't been captured yet."),
        ),
      );
      return;
    }

    final result = await OpenFile.open(path);
    if (result.type == ResultType.done) return;
    if (!context.mounted) return;

    final message = switch (result.type) {
      ResultType.fileNotFound =>
        'That file is missing from this device — it may need to be re-captured or re-synced.',
      ResultType.noAppToOpen =>
        'No app on this device can open this file type.',
      ResultType.permissionDenied =>
        'Permission denied trying to open this file.',
      _ => 'Could not open this document (${result.message}).',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AttendanceTab extends StatelessWidget {
  final Child child;
  const _AttendanceTab({required this.child});

  (Color, String) _statusInfo(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => (AppColors.sync, 'Present'),
        AttendanceStatus.absent => (AppColors.danger, 'Absent'),
        AttendanceStatus.late => (AppColors.accent, 'Late'),
        AttendanceStatus.excused => (AppColors.mutedForeground, 'Excused'),
      };

  @override
  Widget build(BuildContext context) {
    if (child.attendance.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text('No attendance recorded yet', style: AppText.caption),
        ),
      );
    }
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(child.attendance.length, (i) {
          final record = child.attendance[i];
          final isLast = i == child.attendance.length - 1;
          final (dot, label) = _statusInfo(record.status);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEE, MMM d').format(record.date),
                          style: AppText.bodyMedium),
                      if (record.checkIn != null)
                        Text(
                          record.checkOut != null
                              ? '${record.checkIn} → ${record.checkOut}'
                              : '${record.checkIn} · still in',
                          style: AppText.monoCaption,
                        ),
                    ],
                  ),
                ),
                Text(label, style: AppText.caption),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final Child child;
  const _PaymentsTab({required this.child});

  (Color, Color) _statusColors(PaymentStatus s) => switch (s) {
        PaymentStatus.paid => (AppColors.syncSoft, AppColors.sync),
        PaymentStatus.overdue => (AppColors.dangerSoft, AppColors.danger),
        PaymentStatus.pending =>
          (AppColors.pendingSoft, AppColors.pendingTextDark),
      };

  @override
  Widget build(BuildContext context) {
    if (child.payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text('No payments recorded yet', style: AppText.caption),
        ),
      );
    }
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(child.payments.length, (i) {
          final p = child.payments[i];
          final isLast = i == child.payments.length - 1;
          final (bg, fg) = _statusColors(p.status);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.description, style: AppText.bodyMedium),
                      Text(DateFormat('MMM d, yyyy').format(p.date),
                          style: AppText.caption),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${p.amount.toStringAsFixed(0)}',
                        style: AppText.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        p.status.name[0].toUpperCase() +
                            p.status.name.substring(1),
                        style: AppText.monoCaption.copyWith(
                            color: fg, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
