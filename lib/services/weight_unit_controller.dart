import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/weight_units.dart';

class WeightUnitController extends ChangeNotifier {
  WeightUnit unit = WeightUnit.kg;

  bool get usePounds => unit.isPounds;

  String get suffix => unit.suffix;

  String format(double kilograms, {int decimals = 1}) {
    return formatWeight(kilograms, unit, decimals: decimals);
  }

  String formatStored(dynamic kilograms, {int decimals = 1}) {
    return format(readKilograms(kilograms), decimals: decimals);
  }

  String inputText(double kilograms) => formatWeightInput(kilograms, unit);

  double toKg(double value) => toKilograms(value, unit);

  double fromKg(double kilograms) => fromKilograms(kilograms, unit);

  double? kilogramsFromInput(String text, {double? originalKilograms}) {
    return kilogramsToStore(text, unit, originalKilograms: originalKilograms);
  }

  Future<void> load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _apply(WeightUnit.kg);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('weight_unit')
          .eq('id', user.id)
          .maybeSingle();
      _apply(WeightUnit.fromDb(data?['weight_unit']));
    } catch (e) {
      debugPrint('No se pudo leer weight_unit: $e');
    }
  }

  Future<void> setUsePounds(bool usePounds) async {
    final next = usePounds ? WeightUnit.lb : WeightUnit.kg;
    if (next == unit) return;

    final previous = unit;
    _apply(next);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'weight_unit': next.dbValue})
          .eq('id', user.id);
    } catch (e) {
      _apply(previous);
      rethrow;
    }
  }

  void reset() => _apply(WeightUnit.kg);

  void _apply(WeightUnit next) {
    if (next == unit) return;
    unit = next;
    notifyListeners();
  }
}
