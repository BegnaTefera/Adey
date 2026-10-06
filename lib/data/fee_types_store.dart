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
    await refresh();
    _initialized = true;
  }

  Future<void> refresh() async {
    final db = await AppDatabase.instance.database;
    final feeRows = await db.query('fee_types', orderBy: 'name ASC');
    final rateRows = await db.query('fee_rates', orderBy: 'min_months ASC');

    _feeTypes = feeRows.map((feeRow) {
      final id = feeRow['id'] as String;
      final rates = rateRows
          .where((rate) => rate['fee_type_id'] == id)
          .map(AgeBracket.fromMap)
          .toList();
      return FeeType(
        id: id,
        name: feeRow['name'] as String,
        recurring: feeRow['recurring'] == 1,
        chargeOnRegistration: feeRow['charge_on_registration'] == 1,
        rates: rates,
      );
    }).toList();
    notifyListeners();
  }
}
