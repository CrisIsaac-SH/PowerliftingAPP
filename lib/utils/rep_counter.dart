import 'lift_rules.dart';

/// Una repetición que el contador dio por cerrada.
///
/// Solo entran las que también suman a [RepCounter.reps]. Un gesto demasiado
/// corto o una repetición cancelada por pérdida de tracking no se guarda:
/// no forman parte de las reps detectadas.
class CompletedRep {
  final int repNumber;
  final bool valid;

  /// `depth` cuando se contó sin sostener el fondo. Nulo si [valid] es verdadero.
  final String? invalidReason;
  final double minAngle;
  final double maxAngle;
  final int durationMs;
  final String? side;

  /// Rodilla en el frame de mayor ángulo de cadera. Solo peso muerto.
  final double? kneeAngle;

  /// Inclinación del torso y ángulo de cadera en el frame más profundo.
  /// Solo sentadilla, y solo si el hombro era visible en ese frame.
  final double? torsoAngle;
  final double? hipAngle;

  /// Rodilla del lado opuesto al analizado, en ese mismo frame, si su
  /// confianza alcanzó el umbral. Si no, queda nulo.
  final double? oppositeKneeAngle;

  const CompletedRep({
    required this.repNumber,
    required this.valid,
    required this.invalidReason,
    required this.minAngle,
    required this.maxAngle,
    required this.durationMs,
    this.side,
    this.kneeAngle,
    this.torsoAngle,
    this.hipAngle,
    this.oppositeKneeAngle,
  });

  Map<String, dynamic> toJson() {
    double round(double value) => (value * 10).round() / 10.0;

    return {
      'rep_number': repNumber,
      'valid': valid,
      if (invalidReason != null) 'invalid_reason': invalidReason,
      'min_angle': round(minAngle),
      'max_angle': round(maxAngle),
      'duration_ms': durationMs,
      if (side != null) 'side': side,
      if (kneeAngle != null) 'knee_angle': round(kneeAngle!),
      if (torsoAngle != null) 'torso_angle': round(torsoAngle!),
      if (hipAngle != null) 'hip_angle': round(hipAngle!),
      if (oppositeKneeAngle != null) 'opposite_knee_angle': round(oppositeKneeAngle!),
    };
  }
}

class _RepSample {
  final String? side;
  final double? secondaryAngle;
  final double? torsoAngle;
  final double? hipAngle;
  final double? oppositeKneeAngle;

  const _RepSample({
    this.side,
    this.secondaryAngle,
    this.torsoAngle,
    this.hipAngle,
    this.oppositeKneeAngle,
  });
}

/// Cuenta repeticiones a partir de un ángulo ya calculado.
///
/// No conoce la cámara ni el video: recibe el ángulo, si la forma es válida
/// y el tiempo en milisegundos. La cámara y el analizador de video usan
/// esta misma clase. No abre una repetición hasta ver la posición inicial
/// quieta un instante.
class RepCounter {
  int reps = 0;
  int validReps = 0;

  final List<CompletedRep> _completed = [];

  bool _inRep = false;
  bool _armed = false;
  bool _reachedDepth = false;
  int _depthFrames = 0;
  int? _startMs;
  int? _lastTickMs;
  int? _missingSinceMs;
  int? _setupSinceMs;
  double? _setupAnchor;
  double _minAngle = double.infinity;
  double _maxAngle = double.negativeInfinity;
  _RepSample? _minSample;
  _RepSample? _maxSample;
  _RepSample? _pendingSample;

  List<CompletedRep> get completed => List.unmodifiable(_completed);

  bool get inRep => _inRep;

  void reset() {
    reps = 0;
    validReps = 0;
    _completed.clear();
    _inRep = false;
    _armed = false;
    _reachedDepth = false;
    _depthFrames = 0;
    _startMs = null;
    _lastTickMs = null;
    _missingSinceMs = null;
    _setupSinceMs = null;
    _setupAnchor = null;
    _resetAngleWindow();
  }

  /// Avisa que este frame no tiene la cadena del ejercicio.
  /// Si la ausencia se alarga, cancela la repetición abierta sin contarla.
  void markMissing(int timeMs) {
    _syncClock(timeMs);
    if (!_inRep) {
      _setupSinceMs = null;
      _setupAnchor = null;
      return;
    }

    _missingSinceMs ??= timeMs;
    final missingFor = timeMs - _missingSinceMs!;
    if (missingFor >= LiftThresholds.lostTrackingMs || _openTooLong(timeMs)) {
      _clearPhase();
    }
  }

  void update({
    required LiftType lift,
    required double angle,
    required bool isValidForm,
    required int timeMs,
    double? secondaryAngle,
    double? torsoAngle,
    double? hipAngle,
    double? oppositeKneeAngle,
    String? side,
  }) {
    _syncClock(timeMs);
    _missingSinceMs = null;
    if (_abandonIfOpenTooLong(timeMs)) return;
    _pendingSample = _RepSample(
      side: side,
      secondaryAngle: secondaryAngle,
      torsoAngle: torsoAngle,
      hipAngle: hipAngle,
      oppositeKneeAngle: oppositeKneeAngle,
    );
    _observeSetup(lift, angle, timeMs);
    _observeAngle(angle, _pendingSample!);

    switch (lift) {
      case LiftType.bench:
        _updateEccentric(
          lift: lift,
          angle: angle,
          timeMs: timeMs,
          startBelow: LiftThresholds.benchStart,
          depthAtOrBelow: LiftThresholds.benchDepth,
          lockoutAtOrAbove: LiftThresholds.benchLockout,
        );
      case LiftType.deadlift:
        _updateDeadlift(
          angle: angle,
          timeMs: timeMs,
          isValidForm: isValidForm,
        );
      case LiftType.squat:
        _updateEccentric(
          lift: lift,
          angle: angle,
          timeMs: timeMs,
          startBelow: LiftThresholds.squatStart,
          depthAtOrBelow: LiftThresholds.squatDepth,
          lockoutAtOrAbove: LiftThresholds.squatLockout,
        );
    }
  }

  void _updateEccentric({
    required LiftType lift,
    required double angle,
    required int timeMs,
    required double startBelow,
    required double depthAtOrBelow,
    required double lockoutAtOrAbove,
  }) {
    if (angle < startBelow && !_inRep && _armed) {
      _beginRep(timeMs);
      final sample = _pendingSample;
      if (sample != null) _observeAngle(angle, sample);
    }
    if (_inRep && angle <= depthAtOrBelow) {
      _depthFrames++;
      if (_depthFrames >= LiftThresholds.depthFramesRequired) {
        _reachedDepth = true;
      }
    }
    if (_inRep && angle >= lockoutAtOrAbove) {
      final duration = _startMs != null ? timeMs - _startMs! : 1000;
      if (duration >= LiftThresholds.minRepDurationMs) {
        reps++;
        if (_reachedDepth) validReps++;
        _guardarRepeticion(lift: lift, valid: _reachedDepth, durationMs: duration);
      }
      _clearPhase(keepArmed: true);
    }
  }

  void _updateDeadlift({
    required double angle,
    required int timeMs,
    required bool isValidForm,
  }) {
    if (_inRep && isValidForm) {
      _reachedDepth = true;
    }
    if (_inRep && _reachedDepth && angle < LiftThresholds.deadliftPhase) {
      final duration = _startMs != null ? timeMs - _startMs! : 1000;
      if (duration >= LiftThresholds.minRepDurationMs) {
        reps++;
        validReps++;
        _guardarRepeticion(lift: LiftType.deadlift, valid: true, durationMs: duration);
      }
      _clearPhase();
    }
  }

  void _observeAngle(double angle, _RepSample sample) {
    if (!_inRep) return;
    if (angle <= _minAngle) {
      _minAngle = angle;
      _minSample = sample;
    }
    if (angle >= _maxAngle) {
      _maxAngle = angle;
      _maxSample = sample;
    }
  }

  void _guardarRepeticion({
    required LiftType lift,
    required bool valid,
    required int durationMs,
  }) {
    final sample = lift == LiftType.deadlift ? _maxSample : _minSample;
    _completed.add(
      CompletedRep(
        repNumber: reps,
        valid: valid,
        invalidReason: valid ? null : 'depth',
        minAngle: _minAngle.isFinite ? _minAngle : 0,
        maxAngle: _maxAngle.isFinite ? _maxAngle : 0,
        durationMs: durationMs,
        side: sample?.side,
        kneeAngle: lift == LiftType.deadlift ? sample?.secondaryAngle : null,
        torsoAngle: lift == LiftType.squat ? sample?.torsoAngle : null,
        hipAngle: lift == LiftType.squat ? sample?.hipAngle : null,
        oppositeKneeAngle: lift == LiftType.squat ? sample?.oppositeKneeAngle : null,
      ),
    );
  }

  void _resetAngleWindow() {
    _minAngle = double.infinity;
    _maxAngle = double.negativeInfinity;
    _minSample = null;
    _maxSample = null;
  }

  /// La posición inicial es arriba en sentadilla y banca, y abajo en peso muerto.
  bool _enPosicionInicial(LiftType lift, double angle) {
    switch (lift) {
      case LiftType.squat:
        return angle >= LiftThresholds.squatLockout;
      case LiftType.bench:
        return angle >= LiftThresholds.benchLockout;
      case LiftType.deadlift:
        return angle < LiftThresholds.deadliftPhase;
    }
  }

  void _observeSetup(LiftType lift, double angle, int timeMs) {
    if (_inRep || _armed) return;
    if (!_enPosicionInicial(lift, angle)) {
      _setupSinceMs = null;
      _setupAnchor = null;
      return;
    }

    final anchor = _setupAnchor;
    final since = _setupSinceMs;
    if (since == null ||
        anchor == null ||
        (angle - anchor).abs() > LiftThresholds.setupJitterDegrees) {
      _setupSinceMs = timeMs;
      _setupAnchor = angle;
      return;
    }
    if (timeMs - since < LiftThresholds.setupHoldMs) return;

    _armed = true;
    if (lift == LiftType.deadlift) {
      _beginRep(timeMs);
    }
  }

  void _beginRep(int timeMs) {
    _inRep = true;
    _startMs = timeMs;
    _depthFrames = 0;
    _reachedDepth = false;
    _resetAngleWindow();
  }

  void _syncClock(int timeMs) {
    final previous = _lastTickMs;
    if (previous != null) {
      final gap = timeMs - previous;
      if (gap > LiftThresholds.clockGapMs) {
        if (_startMs != null) _startMs = _startMs! + gap;
        if (_missingSinceMs != null) {
          _missingSinceMs = _missingSinceMs! + gap;
        }
        if (_setupSinceMs != null) {
          _setupSinceMs = _setupSinceMs! + gap;
        }
      }
    }
    _lastTickMs = timeMs;
  }

  bool _openTooLong(int timeMs) {
    final start = _startMs;
    if (!_inRep || start == null) return false;
    return timeMs - start >= LiftThresholds.maxRepDurationMs;
  }

  bool _abandonIfOpenTooLong(int timeMs) {
    if (!_openTooLong(timeMs)) return false;
    _clearPhase();
    return true;
  }

  void _clearPhase({bool keepArmed = false}) {
    _inRep = false;
    _reachedDepth = false;
    _depthFrames = 0;
    _startMs = null;
    _missingSinceMs = null;
    _setupSinceMs = null;
    _setupAnchor = null;
    _resetAngleWindow();
    if (!keepArmed) _armed = false;
  }
}
