import 'lift_rules.dart';
import 'pose_math_utils.dart';

/// Aviso de una posición que conviene corregir durante la repetición.
class FormAlert {
  final String code;
  final String message;

  const FormAlert({
    required this.code,
    required this.message,
  });
}

/// Medidas de un frame. La alerta solo se evalúa si [repStarted] es verdadero.
class FormReading {
  final LiftType lift;
  final bool repStarted;
  final double? torsoLean;
  final KneeAdvance? kneeTravel;
  final double? kneeValgus;
  final double? kneeAsymmetry;
  final double? elbowFlare;
  final double? hipAngle;
  final double? kneeAngle;

  const FormReading({
    required this.lift,
    required this.repStarted,
    this.torsoLean,
    this.kneeTravel,
    this.kneeValgus,
    this.kneeAsymmetry,
    this.elbowFlare,
    this.hipAngle,
    this.kneeAngle,
  });
}

/// Reglas de posición de riesgo. No avisa en el setup: espera a que la
/// repetición ya haya empezado, para no marcar la postura quieta.
class FormSafety {
  const FormSafety._();

  static List<FormAlert> evaluate(FormReading reading) {
    if (!reading.repStarted) return const [];

    switch (reading.lift) {
      case LiftType.squat:
        return _sentadilla(reading);
      case LiftType.bench:
        return _banca(reading);
      case LiftType.deadlift:
        return _pesoMuerto(reading);
    }
  }

  static List<FormAlert> _sentadilla(FormReading reading) {
    final alerts = <FormAlert>[];
    final valgus = reading.kneeValgus;
    if (valgus != null && valgus >= LiftThresholds.squatValgus) {
      alerts.add(const FormAlert(
        code: 'valgus',
        message: 'Rodillas hacia adentro. Empújalas hacia afuera.',
      ));
    }

    final torso = reading.torsoLean;
    if (torso != null && torso >= LiftThresholds.squatTorsoRisk) {
      alerts.add(const FormAlert(
        code: 'torso',
        message: 'El torso se viene demasiado adelante. Pecho arriba.',
      ));
    }

    final asymmetry = reading.kneeAsymmetry;
    if (asymmetry != null && asymmetry >= LiftThresholds.kneeAsymmetry) {
      alerts.add(const FormAlert(
        code: 'asymmetry',
        message: 'Una rodilla baja más que la otra. Reparte el peso.',
      ));
    }

    final travel = reading.kneeTravel;
    if (travel != null) {
      final limit = travel.measuredFromToes
          ? LiftThresholds.squatKneePastToe
          : LiftThresholds.squatKneePastAnkle;
      if (travel.ratio >= limit) {
        alerts.add(const FormAlert(
          code: 'knee_travel',
          message: 'La rodilla pasa el pie. Siéntate más atrás.',
        ));
      }
    }
    return alerts;
  }

  static List<FormAlert> _banca(FormReading reading) {
    final flare = reading.elbowFlare;
    if (flare != null && flare >= LiftThresholds.benchElbowFlare) {
      return const [
        FormAlert(
          code: 'elbow_flare',
          message: 'Codos demasiado abiertos. Acércalos al cuerpo.',
        ),
      ];
    }
    return const [];
  }

  static List<FormAlert> _pesoMuerto(FormReading reading) {
    final alerts = <FormAlert>[];
    final torso = reading.torsoLean;
    if (torso != null && torso >= LiftThresholds.deadliftTorsoRisk) {
      alerts.add(const FormAlert(
        code: 'round_back',
        message: 'Espalda muy inclinada. Pecho arriba y espalda neutra.',
      ));
    }

    final hip = reading.hipAngle;
    final knee = reading.kneeAngle;
    if (hip != null &&
        knee != null &&
        knee >= LiftThresholds.deadliftHipShootKnee &&
        hip < LiftThresholds.deadliftHipShootHip) {
      alerts.add(const FormAlert(
        code: 'hip_shoot',
        message: 'La cadera sube antes que el pecho. Empuja el piso.',
      ));
    }
    return alerts;
  }
}

/// Evita que el aviso parpadee por un frame ruidoso.
class FormAlertLatch {
  FormAlert? _shown;
  String? _candidate;
  int _hits = 0;
  int _misses = 0;

  static const int showAfter = 3;
  static const int clearAfter = 4;

  FormAlert? get current => _shown;

  FormAlert? update(List<FormAlert> alerts) {
    if (alerts.isEmpty) {
      _candidate = null;
      _hits = 0;
      _misses++;
      if (_misses >= clearAfter) _shown = null;
      return _shown;
    }

    _misses = 0;
    final next = alerts.first;
    if (_candidate == next.code) {
      _hits++;
    } else {
      _candidate = next.code;
      _hits = 1;
    }
    if (_hits >= showAfter) _shown = next;
    return _shown;
  }

  void reset() {
    _shown = null;
    _candidate = null;
    _hits = 0;
    _misses = 0;
  }
}
