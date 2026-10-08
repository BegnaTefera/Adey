import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/children_store.dart';
import '../data/fee_types_store.dart';
import '../data/formatters.dart';
import '../data/search_utils.dart';
import '../models/child.dart';
import '../models/fee_type.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';

class BillingScreen extends StatefulWidget {
  final String? registeredChildId;

  const BillingScreen({super.key, this.registeredChildId});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool _showOverdueOnly = false;

  @override
  void initState() {
    super.initState();
    ChildrenStore.instance.addListener(_onStoreChanged);
    FeeTypesStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ChildrenStore.instance.removeListener(_onStoreChanged);
    FeeTypesStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final feeTypes = FeeTypesStore.instance.feeTypes;
    final registeredChild = widget.registeredChildId == null
        ? null
        : ChildrenStore.instance.byId(widget.registeredChildId!);
    final children = _showOverdueOnly
        ? ChildrenStore.instance.children.where((child) => child.payments.any((p) => p.isOverdue)).toList()
        : ChildrenStore.instance.children;

    final totalOutstanding = children.fold<double>(0, (sum, child) {
      return sum + child.payments.where((p) => p.isOverdue).fold<double>(0, (inner, p) => inner + p.amount);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Billing', style: AppText.sectionTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logPayment(
          initialChildId: widget.registeredChildId,
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log payment', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (registeredChild != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.syncSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sync.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.sync),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Registration complete', style: AppText.bodyMedium),
                        Text(
                          '${registeredChild.fullName} is enrolled.',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Log a payment for ${registeredChild.fullName}',
                    onPressed: () => _logPayment(
                      initialChildId: registeredChild.id,
                    ),
                    icon: const Icon(Icons.add_card_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Outstanding', style: AppText.caption),
                Text(
                  formatEtb(totalOutstanding),
                  style: AppText.pageTitle.copyWith(color: AppColors.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Fee types', style: AppText.monoLabel)),
              TextButton.icon(
                onPressed: () => _editFeeType(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add fee type'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (feeTypes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(),
              child: Text(
                'No fee types yet. Add at least one before registering a child or logging a payment.',
                style: AppText.caption,
              ),
            )
          else
            ...feeTypes.map(
            (fee) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(fee.name, style: AppText.bodyMedium),
                      ),
                      Text(
                        fee.chargeOnRegistration
                            ? 'At registration'
                            : fee.recurring
                                ? 'Recurring'
                                : 'One-off',
                        style: AppText.caption,
                      ),
                      IconButton(
                        tooltip: 'Delete ${fee.name}',
                        onPressed: () => _deleteFeeType(fee),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit ${fee.name}',
                        onPressed: () => _editFeeType(fee),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...fee.rates.map(
                    (bracket) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(bracket.label, style: AppText.caption),
                          Text(
                            formatEtb(bracket.rate),
                            style: AppText.bodyMedium.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (feeTypes.isNotEmpty) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Child balances', style: AppText.monoLabel)),
              Switch(
                value: _showOverdueOnly,
                onChanged: (value) => setState(() => _showOverdueOnly = value),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No overdue balances', style: AppText.caption),
              ),
            ),
          ...children.map(
            (child) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          child.initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(child.fullName, style: AppText.bodyMedium),
                      ),
                      Text(
                        formatEtb(child.payments.where((p) => p.isOverdue).fold<double>(0, (sum, p) => sum + p.amount)),
                        style: AppText.bodyMedium.copyWith(color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...child.payments
                      .where((p) => !_showOverdueOnly || p.isOverdue)
                      .map(
                        (payment) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(payment.description, style: AppText.caption),
                              Text(
                                formatEtb(payment.amount),
                                style: AppText.caption.copyWith(
                                  color: payment.isOverdue ? AppColors.danger : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editFeeType([FeeType? feeType]) async {
    final editedFee = await showModalBottomSheet<FeeType>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FeeTypeEditor(
        feeType: feeType,
        existingFees: FeeTypesStore.instance.feeTypes,
      ),
    );
    if (editedFee == null || !mounted) return;

    try {
      await FeeTypesStore.instance.save(
        editedFee,
        previousName: feeType?.name,
      );
      if (!mounted) return;
      showAppFeedback(
        context,
        message: feeType == null
            ? 'Fee type added.'
            : 'Fee type updated. Existing payments retain their amounts.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not save this fee type. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _saveFeeType(editedFee, previousName: feeType?.name),
      );
    }
  }

  Future<void> _saveFeeType(FeeType feeType, {String? previousName}) async {
    try {
      await FeeTypesStore.instance.save(feeType, previousName: previousName);
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Fee type saved.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not save this fee type. $error',
        kind: AppFeedbackKind.error,
      );
    }
  }

  Future<void> _deleteFeeType(FeeType feeType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete fee type?'),
        content: Text(
          '${feeType.name} will no longer be offered for new registrations '
          'or payments. Existing payments keep their amounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FeeTypesStore.instance.delete(feeType);
      if (!mounted) return;
      showAppFeedback(
        context,
        message: '${feeType.name} deleted.',
        kind: AppFeedbackKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not delete this fee type. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _deleteFeeType(feeType),
      );
    }
  }

  void _logPayment({String? initialChildId}) {
    final allEnrolledChildren = ChildrenStore.instance.children
        .where((c) => c.enrollmentStatus == EnrollmentStatus.enrolled)
        .toList();

    final feeTypes = FeeTypesStore.instance.feeTypes;
    if (allEnrolledChildren.isEmpty) {
      showAppFeedback(
        context,
        message: 'Enroll a child before logging a payment.',
        kind: AppFeedbackKind.info,
      );
      return;
    }
    if (feeTypes.isEmpty) {
      showAppFeedback(
        context,
        message: 'Add a fee type before logging a payment.',
        kind: AppFeedbackKind.info,
      );
      return;
    }

    Child selectedChild = allEnrolledChildren.firstWhere(
      (child) => child.id == initialChildId,
      orElse: () => allEnrolledChildren.first,
    );
    final lines = [_PaymentLineDraft(feeTypes.first, selectedChild)];
    final descriptionController = TextEditingController();
    final guardianSearchController = TextEditingController();
    var isSaving = false;
    String? validationError;

    List<Child> matchingChildren(String query) {
      final normalizedQuery = normalizeForSearch(query);
      if (normalizedQuery.isEmpty) return allEnrolledChildren;
      return allEnrolledChildren.where((c) {
        final haystacks = <String>[
          normalizeForSearch(c.fullName),
          ...c.guardians.map((g) => normalizeForSearch(g.name)),
          ...c.guardians.map((g) => normalizeForSearch(g.phone)),
        ];
        return matchesAllTokens(
          haystacks: haystacks,
          normalizedQuery: normalizedQuery,
        );
      }).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void applySuggestedRatesForChild() {
            for (final line in lines) {
              line.applySuggestedAmount(selectedChild);
            }
          }

          var filteredChildren = matchingChildren(guardianSearchController.text);
          if (filteredChildren.isEmpty) filteredChildren = allEnrolledChildren;
          if (!filteredChildren.contains(selectedChild)) {
            selectedChild = filteredChildren.first;
            applySuggestedRatesForChild();
          }

          double lineTotal() {
            var sum = 0.0;
            for (final line in lines) {
              sum += double.tryParse(line.amount.text.trim()) ?? 0;
            }
            return sum;
          }

          FeeType defaultFeeForNewLine() {
            final used = lines.map((l) => l.feeType.id).toSet();
            for (final fee in feeTypes) {
              if (!used.contains(fee.id)) return fee;
            }
            return feeTypes.first;
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log payment', style: AppText.sectionTitle),
                  const SizedBox(height: 16),
                  Text('Find by guardian name or phone', style: AppText.caption),
                  const SizedBox(height: 6),
                  _SheetField(
                    controller: guardianSearchController,
                    hint: 'e.g. the name shown on the bank transfer',
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Matches by child or guardian name — handles small '
                    'spelling differences and works in Amharic too.',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 12),
                  Text('Child', style: AppText.caption),
                  const SizedBox(height: 6),
                  _Dropdown<Child>(
                    value: selectedChild,
                    items: filteredChildren,
                    labelBuilder: (c) => c.guardians.isNotEmpty
                        ? '${c.fullName} (${c.guardians.first.name})'
                        : c.fullName,
                    onChanged: (c) {
                      setSheetState(() {
                        selectedChild = c;
                        applySuggestedRatesForChild();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Text('Fees in this payment', style: AppText.caption)),
                      TextButton.icon(
                        onPressed: lines.length >= feeTypes.length
                            ? null
                            : () => setSheetState(() {
                                  lines.add(
                                    _PaymentLineDraft(defaultFeeForNewLine(), selectedChild),
                                  );
                                }),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add fee'),
                      ),
                    ],
                  ),
                  for (var i = 0; i < lines.length; i++) ...[
                    _PaymentLineRow(
                      line: lines[i],
                      feeTypes: feeTypes,
                      selectedChild: selectedChild,
                      canRemove: lines.length > 1,
                      onRemove: () => setSheetState(() {
                        lines.removeAt(i).dispose();
                      }),
                      onChanged: () => setSheetState(() {}),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total logged', style: AppText.bodyMedium),
                        Text(
                          formatEtb(lineTotal()),
                          style: AppText.sectionTitle.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Note (optional)', style: AppText.caption),
                  const SizedBox(height: 6),
                  _SheetField(
                    controller: descriptionController,
                    hint: 'Bank reference or receipt note',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Records money already received — one paid row per fee, '
                    'total above is the combined amount.',
                    style: AppText.caption,
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationError!,
                      style: AppText.caption.copyWith(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              var total = 0.0;
                              final newPayments = <PaymentRecord>[];
                              final now = DateTime.now();
                              final note = descriptionController.text.trim();
                              const uuid = Uuid();

                              for (final line in lines) {
                                final amount =
                                    double.tryParse(line.amount.text.trim()) ?? 0;
                                if (amount <= 0) {
                                  setSheetState(() {
                                    validationError =
                                        'Each fee needs an amount greater than zero.';
                                  });
                                  return;
                                }
                                total += amount;
                                final feeName = line.feeType.name;
                                newPayments.add(
                                  PaymentRecord(
                                    id: uuid.v4(),
                                    feeTypeName: feeName,
                                    description: note.isEmpty
                                        ? feeName
                                        : '$feeName · $note',
                                    amount: amount,
                                    status: PaymentStatus.paid,
                                    dueDate: now,
                                    paidAt: now,
                                  ),
                                );
                              }

                              setSheetState(() {
                                isSaving = true;
                                validationError = null;
                              });

                              try {
                                await ChildrenStore.instance.updateChild(
                                  selectedChild.copyWith(
                                    payments: [
                                      ...selectedChild.payments,
                                      ...newPayments,
                                    ],
                                  ),
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                                if (mounted) {
                                  showAppFeedback(
                                    context,
                                    message:
                                        '${formatEtb(total)} logged for ${selectedChild.fullName}.',
                                    kind: AppFeedbackKind.success,
                                  );
                                }
                              } catch (error) {
                                if (!sheetContext.mounted) return;
                                setSheetState(() => isSaving = false);
                                setSheetState(() {
                                  validationError =
                                      'Could not save the payment. Your entry is still here.';
                                });
                                showAppFeedback(
                                  sheetContext,
                                  message: '$error',
                                  kind: AppFeedbackKind.error,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save payment'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      for (final line in lines) {
        line.dispose();
      }
      descriptionController.dispose();
      guardianSearchController.dispose();
    });
  }
}

class _PaymentLineDraft {
  FeeType feeType;
  final TextEditingController amount;

  _PaymentLineDraft(this.feeType, Child child)
      : amount = TextEditingController(
          text: feeType.rateForAge(child.ageInMonths).toStringAsFixed(0),
        );

  void applySuggestedAmount(Child child) {
    amount.text = feeType.rateForAge(child.ageInMonths).toStringAsFixed(0);
  }

  void dispose() => amount.dispose();
}

class _PaymentLineRow extends StatelessWidget {
  final _PaymentLineDraft line;
  final List<FeeType> feeTypes;
  final Child selectedChild;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _PaymentLineRow({
    required this.line,
    required this.feeTypes,
    required this.selectedChild,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Dropdown<FeeType>(
                  value: line.feeType,
                  items: feeTypes,
                  labelBuilder: (fee) =>
                      '${fee.name} · ${formatEtb(fee.rateForAge(selectedChild.ageInMonths))}',
                  onChanged: (f) {
                    line.feeType = f;
                    line.applySuggestedAmount(selectedChild);
                    onChanged();
                  },
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove fee line',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _SheetField(
            controller: line.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(labelBuilder(item), style: AppText.bodyRegular),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const _SheetField({
    required this.controller,
    this.keyboardType,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: AppText.bodyRegular,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.caption,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

enum _FeeKind { recurring, oneOff, registration }

class _RateDraft {
  final String? id;
  final TextEditingController label;
  final TextEditingController minMonths;
  final TextEditingController maxMonths;
  final TextEditingController rate;

  _RateDraft({
    this.id,
    String label = '',
    String minMonths = '0',
    String maxMonths = '',
    String rate = '',
  })  : label = TextEditingController(text: label),
        minMonths = TextEditingController(text: minMonths),
        maxMonths = TextEditingController(text: maxMonths),
        rate = TextEditingController(text: rate);

  void dispose() {
    label.dispose();
    minMonths.dispose();
    maxMonths.dispose();
    rate.dispose();
  }
}

class _FeeTypeEditor extends StatefulWidget {
  final FeeType? feeType;
  final List<FeeType> existingFees;

  const _FeeTypeEditor({required this.feeType, required this.existingFees});

  @override
  State<_FeeTypeEditor> createState() => _FeeTypeEditorState();
}

class _FeeTypeEditorState extends State<_FeeTypeEditor> {
  late final TextEditingController _nameController;
  late final List<_RateDraft> _rules;
  late _FeeKind _kind;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fee = widget.feeType;
    _nameController = TextEditingController(text: fee?.name ?? '');
    _kind = fee == null
        ? _FeeKind.oneOff
        : fee.chargeOnRegistration
            ? _FeeKind.registration
            : fee.recurring
                ? _FeeKind.recurring
                : _FeeKind.oneOff;
    _rules = fee == null || fee.rates.isEmpty
        ? [_RateDraft(label: 'All ages')]
        : fee.rates
            .map(
              (rate) => _RateDraft(
                id: rate.id,
                label: rate.label,
                minMonths: '${rate.minMonths}',
                maxMonths: rate.maxMonths?.toString() ?? '',
                rate: rate.rate.toStringAsFixed(0),
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final rule in _rules) {
      rule.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a fee type name.');
      return;
    }
    final duplicate = widget.existingFees.any(
      (fee) =>
          fee.id != widget.feeType?.id &&
          fee.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      setState(() => _error = 'A fee type with this name already exists.');
      return;
    }

    final rates = <AgeBracket>[];
    for (var i = 0; i < _rules.length; i++) {
      final draft = _rules[i];
      final minMonths = int.tryParse(draft.minMonths.text.trim());
      final maxText = draft.maxMonths.text.trim();
      final maxMonths = maxText.isEmpty ? null : int.tryParse(maxText);
      final rate = double.tryParse(draft.rate.text.trim());
      if (draft.label.text.trim().isEmpty ||
          minMonths == null ||
          minMonths < 0 ||
          (maxText.isNotEmpty && maxMonths == null) ||
          (maxMonths != null && maxMonths < minMonths) ||
          rate == null ||
          rate <= 0) {
        setState(() => _error = 'Check each rule label, age range, and positive amount.');
        return;
      }
      rates.add(
        AgeBracket(
          id: draft.id ?? const Uuid().v4(),
          label: draft.label.text.trim(),
          minMonths: minMonths,
          maxMonths: maxMonths,
          rate: rate,
        ),
      );
    }

    rates.sort((a, b) => a.minMonths.compareTo(b.minMonths));
    if (rates.first.minMonths != 0) {
      setState(() => _error = 'Age rules must start at 0 months.');
      return;
    }
    for (var i = 1; i < rates.length; i++) {
      final previousMax = rates[i - 1].maxMonths;
      if (previousMax == null || rates[i].minMonths != previousMax + 1) {
        setState(() => _error = 'Age rules must be continuous and cannot overlap.');
        return;
      }
    }
    if (rates.last.maxMonths != null) {
      setState(() => _error = 'Leave the final age limit blank for older children.');
      return;
    }

    Navigator.of(context).pop(
      FeeType(
        id: widget.feeType?.id ?? const Uuid().v4(),
        name: name,
        recurring: _kind == _FeeKind.recurring,
        chargeOnRegistration: _kind == _FeeKind.registration,
        rates: rates,
      ),
    );
  }

  void _addRule() {
    final lastMax = _rules.last.maxMonths.text.trim();
    final nextMin = lastMax.isEmpty
        ? '0'
        : ((int.tryParse(lastMax) ?? -1) + 1).toString();
    setState(() {
      _rules.add(_RateDraft(minMonths: nextMin));
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.feeType == null ? 'Add fee type' : 'Edit fee type',
                    style: AppText.sectionTitle,
                  ),
                ),
                IconButton(
                  tooltip: 'Close fee editor',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Fee name'),
                  ),
                  const SizedBox(height: 16),
                  Text('Fee behavior', style: AppText.caption),
                  const SizedBox(height: 8),
                  SegmentedButton<_FeeKind>(
                    segments: const [
                      ButtonSegment(
                        value: _FeeKind.recurring,
                        label: Text('Recurring'),
                      ),
                      ButtonSegment(
                        value: _FeeKind.oneOff,
                        label: Text('One-off'),
                      ),
                      ButtonSegment(
                        value: _FeeKind.registration,
                        label: Text('Registration'),
                      ),
                    ],
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _kind = selection.first),
                  ),
                  const SizedBox(height: 20),
                  Text('Age-based amount rules', style: AppText.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Use months. Leave the final upper age blank to cover older children.',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _rules.length; i++)
                    _buildRule(i),
                  OutlinedButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add),
                    label: const Text('Add age rule'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: AppText.bodyRegular.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save fee type'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRule(int index) {
    final rule = _rules[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Rule ${index + 1}', style: AppText.bodyMedium),
              ),
              if (_rules.length > 1)
                IconButton(
                  tooltip: 'Remove rule ${index + 1}',
                  onPressed: () => setState(() {
                    _rules.removeAt(index).dispose();
                    _error = null;
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: rule.label,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: rule.minMonths,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'From mo.'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: rule.maxMonths,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'To mo.'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: rule.rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (ETB)'),
          ),
        ],
      ),
    );
  }
}

