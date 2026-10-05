enum WeightUnit {
  kg,
  lb;

  static WeightUnit fromDb(dynamic value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == 'lb' || text == 'lbs' || text == 'libras') return WeightUnit.lb;
    return WeightUnit.kg;
  }

  String get dbValue => this == WeightUnit.lb ? 'lb' : 'kg';

  String get suffix => this == WeightUnit.lb ? 'lb' : 'kg';

  bool get isPounds => this == WeightUnit.lb;
}

/// Libra internacional (avoirdupois).
const double kgPerLb = 0.45359237;

double toKilograms(double value, WeightUnit unit) {
  return unit == WeightUnit.lb ? value * kgPerLb : value;
}

double fromKilograms(double kilograms, WeightUnit unit) {
  return unit == WeightUnit.lb ? kilograms / kgPerLb : kilograms;
}

double readKilograms(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return 0;
  return double.tryParse(value.toString()) ?? 0;
}

String formatWeight(double kilograms, WeightUnit unit, {int decimals = 1}) {
  final shown = fromKilograms(kilograms, unit);
  return '${shown.toStringAsFixed(decimals)} ${unit.suffix}';
}

String formatWeightInput(double kilograms, WeightUnit unit) {
  return fromKilograms(kilograms, unit).toStringAsFixed(1);
}

/// Convierte lo que escribió el usuario a kg.
/// Si el texto coincide con el valor ya guardado, se conserva el kg original
/// para no arrastrar el redondeo de la pantalla.
double? kilogramsToStore(String text, WeightUnit unit, {double? originalKilograms}) {
  final entered = double.tryParse(text.trim());
  if (entered == null) return null;
  if (originalKilograms != null) {
    final shown = double.parse(formatWeightInput(originalKilograms, unit));
    if ((entered - shown).abs() < 0.001) return originalKilograms;
  }
  return toKilograms(entered, unit);
}
