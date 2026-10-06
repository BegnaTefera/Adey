class AgeBracket {
  final String id;
  final String label;
  final int minMonths;
  final int? maxMonths;
  final double rate;

  const AgeBracket({
    required this.id,
    required this.label,
    required this.minMonths,
    required this.maxMonths,
    required this.rate,
  });

  Map<String, Object?> toMap(String feeTypeId) => {
        'id': id,
        'fee_type_id': feeTypeId,
        'label': label,
        'min_months': minMonths,
        'max_months': maxMonths,
        'rate': rate,
      };

  factory AgeBracket.fromMap(Map<String, Object?> map) => AgeBracket(
        id: map['id'] as String,
        label: map['label'] as String,
        minMonths: map['min_months'] as int,
        maxMonths: map['max_months'] as int?,
        rate: (map['rate'] as num).toDouble(),
      );
}

class FeeType {
  final String id;
  final String name;
  final bool recurring;
  final bool chargeOnRegistration;
  final List<AgeBracket> rates;

  const FeeType({
    required this.id,
    required this.name,
    required this.recurring,
    required this.chargeOnRegistration,
    required this.rates,
  });

  double rateForAge(int ageMonths) {
    for (final bracket in rates) {
      final withinMin = ageMonths >= bracket.minMonths;
      final withinMax = bracket.maxMonths == null || ageMonths <= bracket.maxMonths!;
      if (withinMin && withinMax) return bracket.rate;
    }
    return rates.isNotEmpty ? rates.last.rate : 0;
  }
}
