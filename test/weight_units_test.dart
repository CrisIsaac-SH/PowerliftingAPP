import 'package:flutter_test/flutter_test.dart';
import 'package:powerliftingapp/utils/weight_units.dart';

void main() {
  test('225 lb se guarda en kg y vuelve a mostrarse como 225.0', () {
    final stored = toKilograms(225, WeightUnit.lb);
    expect(formatWeight(stored, WeightUnit.lb), '225.0 lb');
    expect(formatWeight(stored, WeightUnit.kg), isNot('225.0 kg'));
  });

  test('100 kg no cambia si la unidad es kilogramos', () {
    expect(formatWeight(100, WeightUnit.kg), '100.0 kg');
    expect(toKilograms(100, WeightUnit.kg), 100);
  });

  test('volver a guardar el mismo texto no altera el kg original', () {
    const original = 100.0;
    final shown = formatWeightInput(original, WeightUnit.lb);
    final stored = kilogramsToStore(shown, WeightUnit.lb, originalKilograms: original);
    expect(stored, original);
  });

  test('un valor nuevo en libras sí se convierte', () {
    final stored = kilogramsToStore('230', WeightUnit.lb, originalKilograms: 100);
    expect(stored, closeTo(230 * kgPerLb, 0.0001));
  });

  test('un valor desconocido de la base se trata como kg', () {
    expect(WeightUnit.fromDb(null), WeightUnit.kg);
    expect(WeightUnit.fromDb('LB'), WeightUnit.lb);
  });
}
