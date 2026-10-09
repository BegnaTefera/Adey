import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/children_store.dart';
import '../data/fee_types_store.dart';
import '../data/formatters.dart';
import '../data/search_utils.dart';
import '../models/child.dart';
import '../models/fee_type.dart';
import '../theme/app_theme.dart';
import 'app_feedback.dart';

/// Records money already received: pick a child, add one or more fee lines,
/// and save a paid [PaymentRecord] per line. Shared between the Billing
/// screen and the child profile so both log payments the same way.
Future<void> showLogPaymentSheet(
  BuildContext context, {
  String? initialChildId,
}) {
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
    return Future.value();
  }
  if (feeTypes.isEmpty) {
    showAppFeedback(
      context,
      message: 'Add a fee type before logging a payment.',
      kind: AppFeedbackKind.info,
    );
    return Future.value();
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

  return showModalBottomSheet<void>(
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
        final noMatches = filteredChildren.isEmpty;
        if (noMatches) {
          filteredChildren = <Child>[selectedChild];
        } else if (!filteredChildren.contains(selectedChild)) {
          selectedChild = filteredChildren.first;
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
                  onChanged: (value) {
                    final matches = matchingChildren(value);
                    setSheetState(() {
                      if (matches.isNotEmpty &&
                          !matches.contains(selectedChild)) {
                        selectedChild = matches.first;
                        applySuggestedRatesForChild();
                      }
                    });
                  },
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
                if (noMatches) ...[
                  const SizedBox(height: 6),
                  Text(
                    'No child or guardian matches '
                    '"${guardianSearchController.text.trim()}". '
                    'Showing ${selectedChild.fullName}.',
                    style: AppText.caption
                        .copyWith(color: AppColors.pendingTextDark),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child:
                            Text('Fees in this payment', style: AppText.caption)),
                    TextButton.icon(
                      onPressed: lines.length >= feeTypes.length
                          ? null
                          : () => setSheetState(() {
                                lines.add(
                                  _PaymentLineDraft(
                                      defaultFeeForNewLine(), selectedChild),
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
                        style: AppText.sectionTitle
                            .copyWith(color: AppColors.primary),
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
                                  description:
                                      note.isEmpty ? feeName : '$feeName · $note',
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
                              if (context.mounted) {
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
