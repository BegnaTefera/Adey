import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/fee_type.dart';
import 'app_database.dart';

class FeeTypesStore extends ChangeNotifier {
  FeeTypesStore._internal();

  static final FeeTypesStore instance = FeeTypesStore._internal();

  List<FeeType> _feeTypes = [];
  bool _initialized = false;

  List<FeeType> get feeTypes => List.unmodifiable(_feeTypes);

  bool get hasAnyFeeTypes => _feeTypes.isNotEmpty;

  Future<void> init() async {
    if (_initialized) return;
    await refresh();
    _initialized = true;
  }

  Future<void> refresh() async {
    final db = await AppDatabase.instance.database;
    final feeRows = await db.query(
      'fee_types',
      where: 'deleted = 0',
      orderBy: 'name ASC',
    );
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

  Future<void> save(FeeType feeType, {String? previousName}) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.insert(
        'fee_types',
        {
          'id': feeType.id,
          'name': feeType.name,
          'recurring': feeType.recurring ? 1 : 0,
          'charge_on_registration': feeType.chargeOnRegistration ? 1 : 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (previousName != null && previousName != feeType.name) {
        await txn.update(
          'payments',
          {'fee_type_name': feeType.name},
          where: 'fee_type_name = ?',
          whereArgs: [previousName],
        );
      }

      await txn.delete(
        'fee_rates',
        where: 'fee_type_id = ?',
        whereArgs: [feeType.id],
      );
      for (final rate in feeType.rates) {
        await txn.insert('fee_rates', rate.toMap(feeType.id));
      }
    });
    await refresh();
  }

  /// Tombstones the fee type: the row stays so the delete reaches other
  /// devices through sync, but every read filters it out. Age rates are
  /// left in place they belong to the hidden parent. Existing payments
  /// keep their fee_type_name and amounts.
  Future<void> delete(FeeType feeType) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'fee_types',
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [feeType.id],
    );
    await refresh();
  }
}
