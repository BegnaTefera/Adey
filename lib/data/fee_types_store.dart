import 'package:flutter/foundation.dart';
import '../models/fee_type.dart';
import 'app_database.dart';

class FeeTypesStore extends ChangeNotifier {
  FeeTypesStore._internal();

  static final FeeTypesStore instance = FeeTypesStore._internal();

  List<FeeType> _feeTypes = [];
  bool _initialized = false;

  List<FeeType> get feeTypes => List.unmodifiable(_feeTypes);

  Future<void> init() async {
    if (_initialized) return;

    final db = await AppDatabase.instance.database;
    final feeRows = await db.query('fee_types', orderBy: 'name ASC');
    final rateRows = await db.query('fee_rates', orderBy: 'min_months ASC');

    _feeTypes = feeRows.map((feeRow) {
      final name = feeRow['name'] as String;
      final rates = rateRows
          .where((rate) => rate['fee_type_name'] == name)
          .map(AgeBracket.fromMap)
          .toList();
      return FeeType(
        name: name,
        recurring: feeRow['recurring'] == 1,
        rates: rates,
      );
    }).toList();
    _initialized = true;
  }
}
