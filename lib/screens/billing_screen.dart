import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/children_store.dart';
import '../data/fee_types_store.dart';
import '../data/search_utils.dart';
import '../models/child.dart';
import '../models/fee_type.dart';
import '../theme/app_theme.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

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
    final children = _showOverdueOnly
        ? ChildrenStore.instance.children.where((child) => child.payments.any((p) => p.status == PaymentStatus.overdue)).toList()
        : ChildrenStore.instance.children;

    final totalOutstanding = children.fold<double>(0, (sum, child) {
      return sum + child.payments.where((p) => p.status == PaymentStatus.overdue).fold<double>(0, (inner, p) => inner + p.amount);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Billing', style: AppText.sectionTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logPayment,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log payment', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Outstanding', style: AppText.caption),
                Text(
                  '\$${totalOutstanding.toStringAsFixed(0)}',
                  style: AppText.pageTitle.copyWith(color: AppColors.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Fee types', style: AppText.monoLabel),
          const SizedBox(height: 12),
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
                        fee.recurring ? 'Recurring' : 'One-off',
                        style: AppText.caption,
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
                            '\$${bracket.rate.toStringAsFixed(0)}',
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
          const SizedBox(height: 16),
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
                        '\$${child.payments.where((p) => p.status == PaymentStatus.overdue).fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(0)}',
                        style: AppText.bodyMedium.copyWith(color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...child.payments
                      .where((p) => !_showOverdueOnly || p.status == PaymentStatus.overdue)
                      .map(
                        (payment) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(payment.description, style: AppText.caption),
                              Text(
                                '\$${payment.amount.toStringAsFixed(0)}',
                                style: AppText.caption.copyWith(
                                  color: payment.status == PaymentStatus.overdue ? AppColors.danger : AppColors.primary,
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

  void _logPayment() {
    final allEnrolledChildren = ChildrenStore.instance.children
        .where((c) => c.enrollmentStatus == EnrollmentStatus.enrolled)
        .toList();

    final feeTypes = FeeTypesStore.instance.feeTypes;
    if (allEnrolledChildren.isEmpty || feeTypes.isEmpty) return;

    Child selectedChild = allEnrolledChildren.first;
    FeeType selectedFee = feeTypes.first;
    PaymentStatus selectedStatus = PaymentStatus.pending;
    final amountController = TextEditingController(
      text: selectedFee.rateForAge(selectedChild.ageInMonths).toStringAsFixed(0),
    );
    final descriptionController = TextEditingController(text: selectedFee.name);
    final guardianSearchController = TextEditingController();

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
          void applySuggestedRate() {
            amountController.text =
                selectedFee.rateForAge(selectedChild.ageInMonths).toStringAsFixed(0);
          }

          var filteredChildren = matchingChildren(guardianSearchController.text);
          if (filteredChildren.isEmpty) filteredChildren = allEnrolledChildren;
          if (!filteredChildren.contains(selectedChild)) {
            selectedChild = filteredChildren.first;
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
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
                      applySuggestedRate();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text('Fee type', style: AppText.caption),
                const SizedBox(height: 6),
                _Dropdown<FeeType>(
                  value: selectedFee,
                  items: feeTypes,
                  labelBuilder: (f) => f.name,
                  onChanged: (f) {
                    setSheetState(() {
                      selectedFee = f;
                      descriptionController.text = f.name;
                      applySuggestedRate();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text('Description', style: AppText.caption),
                const SizedBox(height: 6),
                _SheetField(controller: descriptionController),
                const SizedBox(height: 12),
                Text(
                  'Amount — suggested rate for ${selectedChild.ageLabel}: '
                  '\$${selectedFee.rateForAge(selectedChild.ageInMonths).toStringAsFixed(0)}',
                  style: AppText.caption,
                ),
                const SizedBox(height: 6),
                _SheetField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Text('Status', style: AppText.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: PaymentStatus.values.map((status) {
                    final selected = selectedStatus == status;
                    return ChoiceChip(
                      label: Text(status.name),
                      selected: selected,
                      onSelected: (_) => setSheetState(() => selectedStatus = status),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.foreground,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0 || descriptionController.text.trim().isEmpty) return;

                      final payment = PaymentRecord(
                        id: const Uuid().v4(),
                        date: DateTime.now(),
                        description: descriptionController.text.trim(),
                        amount: amount,
                        status: selectedStatus,
                      );

                      await ChildrenStore.instance.updateChild(
                        selectedChild.copyWith(
                          payments: [...selectedChild.payments, payment],
                        ),
                      );

                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save payment'),
                  ),
                ),
              ],
            ),
          );
        },
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

