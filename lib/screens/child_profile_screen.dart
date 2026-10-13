import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:uuid/uuid.dart';
import '../data/children_store.dart';
import '../data/document_storage.dart';
import '../data/formatters.dart';
import '../data/document_printing.dart';
import '../data/settings_store.dart';
import '../data/sync/sync_service.dart';
import '../models/authorized_pickup.dart';
import '../models/child.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/immunization_gallery.dart';
import '../widgets/log_payment_sheet.dart';
import 'child_profile_editors.dart';

enum _Tab { info, guardians, documents, attendance, payments }

class ChildProfileScreen extends StatefulWidget {
  final Child child;

  const ChildProfileScreen({super.key, required this.child});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Child _child = widget.child;
  bool _isUpdatingEnrollmentStatus = false;

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
    _tabController = TabController(length: _tabs.length, vsync: this);
    ChildrenStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    ChildrenStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  Widget _tabScrollable(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  void _onStoreChanged() {
    final updated = ChildrenStore.instance.byId(widget.child.id);
    if (updated != null && mounted) {
      setState(() => _child = updated);
    }
  }

  Widget _profileAvatar(Child child) {
    final photoPath = child.photoPath;
    Widget initials() => Center(
          child: Text(
            child.initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: photoPath == null
            ? ColoredBox(color: AppColors.primary, child: initials())
            : Image.file(
                File(photoPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: AppColors.primary, child: initials()),
              ),
      ),
    );
  }

  Future<void> _changeEnrollmentStatus(EnrollmentStatus status) async {
    if (_isUpdatingEnrollmentStatus || status == _child.enrollmentStatus) {
      return;
    }
    final nextLabel = status == EnrollmentStatus.enrolled
        ? 'enrolled'
        : 'withdrawn';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change enrollment status?'),
        content: Text('Set ${_child.fullName} as $nextLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(status == EnrollmentStatus.enrolled
                ? 'Enroll child'
                : 'Withdraw child'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingEnrollmentStatus = true);
    try {
      await ChildrenStore.instance.updateChild(
        _child.copyWith(enrollmentStatus: status),
      );
      if (!mounted) return;
      showAppFeedback(
        context,
        message: '${_child.fullName} is now $nextLabel.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not update enrollment status. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _changeEnrollmentStatus(status),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingEnrollmentStatus = false);
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
                  if (nameController.text.trim().isEmpty) {
                    showAppFeedback(
                      sheetContext,
                      message: 'Enter a name before adding a pickup contact.',
                      kind: AppFeedbackKind.error,
                    );
                    return;
                  }
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

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    nameController.dispose();
    phoneController.dispose();
    if (added != true) return;

    await _savePickupPerson(name, phone);
  }

  Future<void> _savePickupPerson(String name, String phone) async {
    final newPerson = AuthorizedPickup(name: name, phone: phone);
    try {
      await ChildrenStore.instance.updateChild(
        _child.copyWith(
          additionalPickupPeople: [..._child.additionalPickupPeople, newPerson],
        ),
      );
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Authorized pickup added.',
          kind: AppFeedbackKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Could not add this pickup contact. Try again. $error',
          kind: AppFeedbackKind.error,
          actionLabel: 'Retry',
          onAction: () => _savePickupPerson(name, phone),
        );
      }
    }
  }

  Future<void> _removePickupPerson(AuthorizedPickup person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove pickup contact?'),
        content: Text('Remove ${person.name} from authorized pickup?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final updated = List<AuthorizedPickup>.from(_child.additionalPickupPeople)
      ..remove(person);
    try {
      await ChildrenStore.instance.updateChild(
        _child.copyWith(additionalPickupPeople: updated),
      );
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Pickup contact removed.',
          kind: AppFeedbackKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Could not remove this pickup contact. Try again. $error',
          kind: AppFeedbackKind.error,
        );
      }
    }
  }

  Future<void> _editChildInfo() async {
    final updated = await showEditChildSheet(context, _child);
    if (updated == null || !mounted) return;
    await _persist(updated, 'Child details updated.');
  }

  Future<void> _addGuardian() async {
    final guardian = await showGuardianEditorSheet(context);
    if (guardian == null || !mounted) return;
    await _persist(
      _child.copyWith(guardians: [..._child.guardians, guardian]),
      'Guardian added.',
    );
  }

  Future<void> _editGuardian(Guardian guardian) async {
    final updated = await showGuardianEditorSheet(context, guardian: guardian);
    if (updated == null || !mounted) return;
    final list = _child.guardians
        .map((g) => g.id == guardian.id ? updated : g)
        .toList();
    await _persist(_child.copyWith(guardians: list), 'Guardian updated.');
  }

  Future<void> _addDocument() async {
    final document = await showDocumentEditorSheet(context);
    if (document == null || !mounted) return;
    await _persist(
      _child.copyWith(documents: [..._child.documents, document]),
      'Document added.',
    );
  }

  Future<void> _editDocument(ChildDocument document) async {
    final updated = await showDocumentEditorSheet(context, document: document);
    if (updated == null || !mounted) return;
    final list = _child.documents
        .map((d) => d.id == document.id ? updated : d)
        .toList();
    await _persist(_child.copyWith(documents: list), 'Document updated.');
  }

  Future<void> _editImmunizationPages() async {
    final existing = _child.documents
        .where((d) =>
            d.type == DocumentType.immunization &&
            (d.filePath ?? '').isNotEmpty)
        .toList();
    final pages = await showImmunizationGallery(
      context,
      initialPages: [
        for (final doc in existing)
          ImmunizationPage(id: doc.id, path: doc.filePath!, sha256: doc.sha256),
      ],
    );
    if (pages == null || !mounted) return;

    final keptIds = <String>{
      for (final page in pages)
        if (page.id != null) page.id!,
    };

    // Keep every non-immunization document and the immunization pages the
    // user left in the gallery; anything else is dropped.
    final documents = _child.documents.where((doc) {
      if (doc.type != DocumentType.immunization) return true;
      return keptIds.contains(doc.id);
    }).toList();

    final now = DateTime.now();
    const uuid = Uuid();
    var saved = 0;
    for (final page in pages) {
      if (page.id != null) continue;
      try {
        final bytes = await File(page.path).readAsBytes();
        final (path, hash) = await DocumentStorage.save(
          bytes: bytes,
          filename: 'immunization_${now.millisecondsSinceEpoch}.jpg',
        );
        documents.add(ChildDocument(
          id: uuid.v4(),
          label: 'Immunization record',
          type: DocumentType.immunization,
          uploadedAt: now,
          status: DocumentStatus.onFile,
          filePath: path,
          sha256: hash,
        ));
        saved++;
      } catch (error) {
        if (mounted) {
          showAppFeedback(
            context,
            message: 'Could not save an immunization page. $error',
            kind: AppFeedbackKind.error,
          );
        }
      }
    }

    await _persist(
      _child.copyWith(documents: documents),
      saved == 0 ? 'Immunization records updated.' : 'Immunization pages saved.',
    );
  }

  Future<void> _addPayment() async {
    await showLogPaymentSheet(context, initialChildId: _child.id);
  }

  Future<void> _persist(Child updated, String message) async {
    try {
      await ChildrenStore.instance.updateChild(updated);
      if (mounted) {
        showAppFeedback(context, message: message,
            kind: AppFeedbackKind.success);
      }
    } catch (error) {
      if (mounted) {
        showAppFeedback(
          context,
          message: 'Could not save the change. Try again. $error',
          kind: AppFeedbackKind.error,
          actionLabel: 'Retry',
          onAction: () => _persist(updated, message),
        );
      }
    }
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _profileAvatar(child),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.fullName,
                              style: AppText.sectionTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(child.ageLabel, style: AppText.caption),
                                const SizedBox(width: 8),
                                Text('·', style: AppText.caption),
                                const SizedBox(width: 8),
                                PopupMenuButton<EnrollmentStatus>(
                                tooltip: 'Change enrollment status',
                                enabled: !_isUpdatingEnrollmentStatus,
                                onSelected: _changeEnrollmentStatus,
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: EnrollmentStatus.enrolled,
                                    child: Text('Enrolled'),
                                  ),
                                  const PopupMenuItem(
                                    value: EnrollmentStatus.withdrawn,
                                    child: Text('Withdrawn'),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: child.enrollmentStatus ==
                                            EnrollmentStatus.enrolled
                                        ? AppColors.syncSoft
                                        : AppColors.muted,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
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
                                      if (_isUpdatingEnrollmentStatus) ...[
                                        const SizedBox(width: 6),
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ] else
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.foreground,
                    unselectedLabelColor: AppColors.mutedForeground,
                    indicatorColor: AppColors.foreground,
                    indicatorWeight: 2,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    labelStyle: AppText.bodyMedium,
                    tabs: [for (final t in _tabs) Tab(text: t.$2)],
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _tabScrollable(
                    _InfoTab(child: child, onEdit: _editChildInfo),
                  ),
                  _tabScrollable(
                    _GuardiansTab(
                      child: child,
                      onAddPickup: _addPickupPerson,
                      onRemovePickup: _removePickupPerson,
                      onAddGuardian: _addGuardian,
                      onEditGuardian: _editGuardian,
                    ),
                  ),
                  _tabScrollable(
                    _DocumentsTab(
                      child: child,
                      onAdd: _addDocument,
                      onEdit: _editDocument,
                      onEditImmunization: _editImmunizationPages,
                    ),
                  ),
                  _tabScrollable(_AttendanceTab(child: child)),
                  _tabScrollable(
                    _PaymentsTab(
                      child: child,
                      onAdd: _addPayment,
                    ),
                  ),
                ],
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
  final VoidCallback onEdit;
  const _InfoTab({required this.child, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PERSONAL', style: AppText.monoLabel),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row('Full name', child.fullName),
              _Row('Gender', child.gender == Gender.male ? 'Male' : 'Female'),
              _Row('Date of birth', formatDate(child.dob)),
              _Row('Age', child.ageLabel),
              _Row('Enrolled since', formatDate(child.enrolledSince),
                  isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _responsiveCards(
          context,
          [
            _allergiesCard(),
            _notesCard('HEALTH CONDITION', child.healthCondition),
            _notesCard('DIETARY CONDITION', child.dietaryNotes),
            _notesCard('SPECIAL CHARACTERISTICS', child.specialCharacteristics),
          ],
        ),
      ],
    );
  }

  Widget _allergiesCard() {
    return Container(
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
    );
  }

  /// Lays the info cards out in a responsive grid: stacked on narrow
  /// screens, then 2 or 4 columns as the available width grows.
  Widget _responsiveCards(BuildContext context, List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 4
            : width >= 680
                ? 2
                : 1;
        const gap = 20.0;
        const rowsGap = 20.0;

        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: rowsGap),
                cards[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var start = 0; start < cards.length; start += columns) {
          final end =
              start + columns < cards.length ? start + columns : cards.length;
          final rowCards = cards.sublist(start, end);
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(
                      child: j < rowCards.length
                          ? rowCards[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: rowsGap),
              rows[i],
            ],
          ],
        );
      },
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
  final VoidCallback onAddGuardian;
  final ValueChanged<Guardian> onEditGuardian;

  const _GuardiansTab({
    required this.child,
    required this.onAddPickup,
    required this.onRemovePickup,
    required this.onAddGuardian,
    required this.onEditGuardian,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GUARDIANS', style: AppText.monoLabel),
            TextButton.icon(
              onPressed: onAddGuardian,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: AppColors.sync,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pickup',
                              style: AppText.monoCaption
                                  .copyWith(color: AppColors.sync),
                            ),
                          ],
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.mutedForeground),
                      tooltip: 'Edit guardian',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onEditGuardian(g),
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
  final VoidCallback onAdd;
  final ValueChanged<ChildDocument> onEdit;
  final VoidCallback onEditImmunization;
  const _DocumentsTab({
    required this.child,
    required this.onAdd,
    required this.onEdit,
    required this.onEditImmunization,
  });

  static const _icons = <DocumentType, IconData>{
    DocumentType.id: Icons.badge_outlined,
    DocumentType.photo: Icons.photo_outlined,
    DocumentType.immunization: Icons.medical_services_outlined,
    DocumentType.registration: Icons.assignment_outlined,
    DocumentType.other: Icons.description_outlined,
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
    final isDesktop = SettingsStore.instance.isDesktop;
    final immunizationCount = child.documents
        .where((d) =>
            d.type == DocumentType.immunization &&
            (d.filePath ?? '').isNotEmpty)
        .length;
    final otherDocuments = child.documents
        .where((d) => d.type != DocumentType.immunization)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('DOCUMENTS', style: AppText.monoLabel),
            TextButton.icon(
              onPressed: onAdd,
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
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onEditImmunization,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Immunization pages', style: AppText.bodyMedium),
                        const SizedBox(height: 2),
                        Text(
                          immunizationCount == 0
                              ? 'Not captured tap to add'
                              : '$immunizationCount page(s) tap to change',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (otherDocuments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No other documents on file yet. Tap Add to attach IDs, '
              'registration forms, or photos.',
              style: AppText.caption,
            ),
          )
        else
          Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(otherDocuments.length, (i) {
          final doc = otherDocuments[i];
          final isLast = i == otherDocuments.length - 1;
          final (bg, fg) = _statusColors(doc.status);
          final canOpen = doc.filePath != null && doc.filePath!.isNotEmpty;
          return InkWell(
            onTap: () => _openDocument(context, doc, onEdit),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      _icons[doc.type] ?? Icons.description_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.label, style: AppText.bodyMedium),
                        Text(formatDate(doc.uploadedAt),
                            style: AppText.caption),
                        // Mobile can't print, so for the registration form it
                        // just reports whether the office copy got done.
                        if (!isDesktop && doc.type == DocumentType.registration)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _PrintStatusChip(printed: doc.printed),
                          ),
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
                  // Reprinting stays available whatever `printed` says: a lost
                  // copy never needs anything un-queued first.
                  if (isDesktop && (canOpen || (doc.sha256 ?? '').isNotEmpty))
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 20),
                      tooltip: 'Print',
                      onPressed: () => _printDocument(context, doc),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Document actions',
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: AppColors.mutedForeground),
                    onSelected: (value) {
                      if (value == 'edit') onEdit(doc);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                    ],
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
    ),
      ],
    );
  }

  Future<void> _printDocument(BuildContext context, ChildDocument doc) async {
    try {
      final printed = await printStoredDocument(
        doc,
        name: '${doc.label} - ${child.fullName}.pdf',
      );
      // A form still waiting in the print queue is done once it has been
      // printed from here too; otherwise it would get printed twice.
      if (printed && doc.type == DocumentType.registration && !doc.printed) {
        await SyncService.instance.markDocumentPrinted(doc.id);
      }
    } on DocumentUnavailableException catch (e) {
      if (!context.mounted) return;
      showAppFeedback(context, message: e.message, kind: AppFeedbackKind.info);
    } catch (e) {
      if (!context.mounted) return;
      showAppFeedback(
        context,
        message: 'Could not print: $e',
        kind: AppFeedbackKind.error,
      );
    }
  }

  Future<void> _openDocument(
    BuildContext context,
    ChildDocument doc,
    ValueChanged<ChildDocument> onEdit,
  ) async {
    final path = doc.filePath;
    if (path == null || path.isEmpty) {
      // Nothing on disk yet offer to attach the file right here instead
      // of bouncing the user back to the registration flow.
      onEdit(doc);
      return;
    }

    final result = await OpenFile.open(path);
    if (result.type == ResultType.done) return;
    if (!context.mounted) return;

    final message = switch (result.type) {
      ResultType.fileNotFound =>
        'That file is missing from this device it may need to be re-captured or re-synced.',
      ResultType.noAppToOpen =>
        'No app on this device can open this file type.',
      ResultType.permissionDenied =>
        'Permission denied trying to open this file.',
      _ => 'Could not open this document (${result.message}).',
    };
    showAppFeedback(
      context,
      message: message,
      kind: AppFeedbackKind.error,
      actionLabel: result.type == ResultType.fileNotFound ? null : 'Retry',
      onAction: result.type == ResultType.fileNotFound
          ? null
          : () => _openDocument(context, doc, onEdit),
    );
  }
}

/// Read-only "did the office copy get done" indicator shown on mobile.
class _PrintStatusChip extends StatelessWidget {
  final bool printed;
  const _PrintStatusChip({required this.printed});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = printed
        ? (AppColors.syncSoft, AppColors.sync, 'Printed', Icons.check)
        : (
            AppColors.pendingSoft,
            AppColors.pendingTextDark,
            'Queued for printing',
            Icons.print_outlined,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
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

class _AttendanceTab extends StatelessWidget {
  final Child child;
  const _AttendanceTab({required this.child});

  (Color, String) _statusInfo(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => (AppColors.sync, 'Present'),
        AttendanceStatus.absent => (AppColors.danger, 'Absent'),
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
                      Text(formatDateShort(record.date),
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
  final VoidCallback onAdd;
  const _PaymentsTab({
    required this.child,
    required this.onAdd,
  });

  (Color, Color, String) _statusDisplay(PaymentRecord p) {
    if (p.status == PaymentStatus.paid) {
      return (AppColors.syncSoft, AppColors.sync, 'Paid');
    }
    if (p.status == PaymentStatus.cancelled) {
      return (AppColors.muted, AppColors.mutedForeground, 'Cancelled');
    }
    if (p.isOverdue) {
      return (AppColors.dangerSoft, AppColors.danger, 'Overdue');
    }
    return (AppColors.pendingSoft, AppColors.pendingTextDark, 'Pending');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PAYMENTS', style: AppText.monoLabel),
            TextButton.icon(
              onPressed: onAdd,
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
          'Edit or remove payments from the Billing screen.',
          style: AppText.caption,
        ),
        const SizedBox(height: 12),
        if (child.payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No payments recorded yet. Tap Add to log one.',
              style: AppText.caption,
            ),
          )
        else
          Container(
            decoration: cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(child.payments.length, (i) {
                final p = child.payments[i];
                final isLast = i == child.payments.length - 1;
                final (bg, fg, label) = _statusDisplay(p);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: isLast
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
                            Text(p.description, style: AppText.bodyMedium),
                            Text(formatDate(p.dueDate), style: AppText.caption),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatEtb(p.amount),
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
                              label,
                              style: AppText.monoCaption.copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11),
                            ),
                          ),
                        ],
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
