class PowerliftingUtils {
  /// Calcula el 1RM estimado usando la fórmula de Epley
  static double calcular1RM(double peso, int reps) {
    if (reps <= 0 || peso <= 0) return 0.0;
    if (reps == 1) return peso;
    return peso * (1 + (reps / 30.0));
  }
}