// lib/screens/billing_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/children_store.dart';
import '../data/fee_types_store.dart';
import '../data/formatters.dart';
import '../models/child.dart';
import '../models/fee_type.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/child_avatar.dart';
import '../widgets/empty_illustration.dart';
import '../widgets/log_payment_sheet.dart';
import 'child_profile_editors.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool _showOverdueOnly = false;
  final Set<String> _expandedFeeTypes = {};

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
    final children = _showOverdueOnly
        ? ChildrenStore.instance.children.where((child) => child.payments.any((p) => p.isOverdue)).toList()
        : ChildrenStore.instance.children;

    final totalOverdue = children.fold<double>(0, (sum, child) {
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
        heroTag: null,
        onPressed: () => showLogPaymentSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log payment', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _TotalCard(label: 'Overdue total', amount: totalOverdue),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Fee types',
            action: TextButton.icon(
              onPressed: () => _editFeeType(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add fee type'),
            ),
          ),
          const SizedBox(height: 12),
          if (feeTypes.isEmpty)
            EmptyIllustration(
              icon: Icons.receipt_long_outlined,
              title: 'No fee types yet',
              message: 'Add at least one fee type before registering a child '
                  'or recording a payment.',
              actionLabel: 'Add fee type',
              onAction: () => _editFeeType(),
            )
          else
            for (final fee in feeTypes) ...[
              _FeeTypeCard(
                key: ValueKey('fee-${fee.id}'),
                fee: fee,
                expanded: _expandedFeeTypes.contains(fee.id),
                onToggle: () => setState(() {
                  if (_expandedFeeTypes.contains(fee.id)) {
                    _expandedFeeTypes.remove(fee.id);
                  } else {
                    _expandedFeeTypes.add(fee.id);
                  }
                }),
                onEdit: () => _editFeeType(fee),
                onDelete: () => _deleteFeeType(fee),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 12),
          _SectionHeader(
            title: 'Child balances',
            action: _OverdueToggle(
              value: _showOverdueOnly,
              onChanged: (value) => setState(() => _showOverdueOnly = value),
            ),
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            EmptyIllustration(
              icon: _showOverdueOnly
                  ? Icons.check_circle_outline
                  : Icons.child_care_outlined,
              title: _showOverdueOnly
                  ? 'No overdue balances'
                  : 'No children to bill yet',
              message: _showOverdueOnly
                  ? 'There are no overdue balances for the selected children.'
                  : 'Enrolled children will appear here when they have '
                      'balances to review.',
            )
          else
            for (final child in children) ...[
              _ChildBalanceCard(
                key: ValueKey('child-${child.id}'),
                child: child,
                overdueOnly: _showOverdueOnly,
                onEditPayment: (payment) => _editPayment(child, payment),
              ),
              const SizedBox(height: 12),
            ],
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
      await FeeTypesStore.instance.save(editedFee, previousName: feeType?.name);
      if (!mounted) return;
      showAppFeedback(
        context,
        message: feeType == null ? 'Fee type added.' : 'Fee type updated. Existing payments retain their amounts.',
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
      showAppFeedback(context, message: 'Fee type saved.', kind: AppFeedbackKind.success);
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(context, message: 'Could not save this fee type. $error', kind: AppFeedbackKind.error);
    }
  }

  Future<void> _deleteFeeType(FeeType feeType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete fee type?'),
        content: Text('${feeType.name} will no longer be offered for new registrations or payments. Existing payments keep their amounts.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
      showAppFeedback(context, message: '${feeType.name} deleted.', kind: AppFeedbackKind.success);
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

  Future<void> _editPayment(Child child, PaymentRecord payment) async {
    final result = await showPaymentEditorSheet(context, payment: payment);
    if (result == null || !mounted) return;
    if (result.deleteRequested) {
      await _deletePayment(child, payment);
      return;
    }
    final updated = result.payment!;
    final payments = child.payments.map((p) => p.id == payment.id ? updated : p).toList();
    await _persistChild(child.copyWith(payments: payments), 'Payment updated.');
  }

  Future<void> _deletePayment(Child child, PaymentRecord payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove payment?'),
        content: Text('Remove "${payment.description}" (${formatEtb(payment.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final payments = child.payments.where((p) => p.id != payment.id).toList();
    await _persistChild(child.copyWith(payments: payments), 'Payment removed.');
  }

  Future<void> _persistChild(Child child, String message) async {
    try {
      await ChildrenStore.instance.updateChild(child);
      if (!mounted) return;
      showAppFeedback(context, message: message, kind: AppFeedbackKind.success);
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        message: 'Could not save the change. Try again. $error',
        kind: AppFeedbackKind.error,
        actionLabel: 'Retry',
        onAction: () => _persistChild(child, message),
      );
    }
  }
}

enum _FeeAction { edit, delete }

String _feeSummary(FeeType fee) {
  final rates = fee.rates;
  if (rates.isEmpty) return 'No rates';
  if (rates.length == 1) return '${rates.single.label} · ${formatEtb(rates.single.rate)}';
  final cheapest = rates.map((r) => r.rate).reduce((a, b) => a < b ? a : b);
  return '${rates.length} age rules · from ${formatEtb(cheapest)}';
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _MenuRow({required this.icon, required this.label, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : null;
    return Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 12), Text(label, style: TextStyle(color: color))]);
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double amount;

  const _TotalCard({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: AppText.caption), Text(formatEtb(amount), style: AppText.pageTitle.copyWith(color: AppColors.danger))]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(title, style: AppText.monoLabel)), if (action != null) action!]);
  }
}

class _OverdueToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OverdueToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Show overdue only',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Overdue only', style: AppText.caption),
          const SizedBox(width: 4),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _OverdueChip extends StatelessWidget {
  const _OverdueChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 12, color: AppColors.danger),
          const SizedBox(width: 4),
          Text(
            'Overdue',
            style: AppText.caption.copyWith(
              color: AppColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeTypeCard extends StatelessWidget {
  final FeeType fee;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FeeTypeCard({super.key, required this.fee, required this.expanded, required this.onToggle, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final kindLabel = fee.chargeOnRegistration ? 'At registration' : fee.recurring ? 'Recurring' : 'One-off';
    return Container(
      decoration: cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: InkWell(onTap: onToggle, child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 10), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fee.name, style: AppText.bodyMedium), const SizedBox(height: 2), Text('$kindLabel · ${_feeSummary(fee)}', style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)])),
            Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.mutedForeground),
          ]))),
          ),
          PopupMenuButton<_FeeAction>(tooltip: 'Actions for ${fee.name}', onSelected: (action) => switch (action) { _FeeAction.edit => onEdit(), _FeeAction.delete => onDelete(), }, itemBuilder: (context) => const [PopupMenuItem(value: _FeeAction.edit, child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit')), PopupMenuItem(value: _FeeAction.delete, child: _MenuRow(icon: Icons.delete_outline, label: 'Delete', destructive: true))]),
        ]),
        if (expanded) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(children: fee.rates.map((bracket) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(bracket.label, style: AppText.caption), Text(formatEtb(bracket.rate), style: AppText.bodyMedium.copyWith(color: AppColors.primary))]))).toList())),
      ]),
    );
  }
}

class _ChildBalanceCard extends StatelessWidget {
  final Child child;
  final bool overdueOnly;
  final ValueChanged<PaymentRecord> onEditPayment;

  const _ChildBalanceCard({super.key, required this.child, required this.overdueOnly, required this.onEditPayment});

  @override
  Widget build(BuildContext context) {
    final visiblePayments = overdueOnly ? child.payments.where((p) => p.isOverdue).toList() : child.payments;
    final overdueTotal = child.payments.where((p) => p.isOverdue).fold<double>(0, (sum, p) => sum + p.amount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ChildAvatar(child: child, radius: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(child.fullName, style: AppText.bodyMedium)),
          if (overdueTotal > 0) ...[const _OverdueChip(), const SizedBox(width: 8), Text(formatEtb(overdueTotal), style: AppText.bodyMedium.copyWith(color: AppColors.danger))] else Text('No overdue', style: AppText.caption),
        ]),
        for (final payment in visiblePayments) InkWell(
          key: ValueKey('payment-${payment.id}'),
          onTap: () => onEditPayment(payment),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Row(children: [
            Expanded(child: Text(payment.description, style: AppText.caption)),
            if (payment.isOverdue) ...[const Tooltip(message: 'Overdue', child: Icon(Icons.error_outline, size: 16, color: AppColors.danger)), const SizedBox(width: 8)],
            Text(formatEtb(payment.amount), style: AppText.caption.copyWith(color: payment.isOverdue ? AppColors.danger : AppColors.primary)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedForeground),
          ]))),
        ),
      ]),
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

  _RateDraft({this.id, String label = '', String minMonths = '0', String maxMonths = '', String rate = ''})
      : label = TextEditingController(text: label),
        minMonths = TextEditingController(text: minMonths),
        maxMonths = TextEditingController(text: maxMonths),
        rate = TextEditingController(text: rate);

  void dispose() {label.dispose(); minMonths.dispose(); maxMonths.dispose(); rate.dispose();}
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
        setState(
          () => _error = 'Check each rule label, age range, and positive amount.',
        );
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
        setState(
          () => _error = 'Age rules must be continuous and cannot overlap.',
        );
        return;
      }
    }
    if (rates.last.maxMonths != null) {
      setState(
        () => _error = 'Leave the final age limit blank for older children.',
      );
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
                  for (var i = 0; i < _rules.length; i++) _buildRule(i),
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
