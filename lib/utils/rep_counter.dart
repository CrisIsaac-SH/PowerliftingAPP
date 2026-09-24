import 'lift_rules.dart';

/// Cuenta repeticiones a partir de un ángulo ya calculado.
///
/// No conoce la cámara ni el video: recibe el ángulo, si la forma es válida
/// y el tiempo en milisegundos. La cámara y el analizador de video usan
/// esta misma clase. No abre una repetición hasta ver la posición inicial
/// quieta un instante.
class RepCounter {
  int reps = 0;
  int validReps = 0;

  bool _inRep = false;
  bool _armed = false;
  bool _reachedDepth = false;
  int _depthFrames = 0;
  int? _startMs;
  int? _lastTickMs;
  int? _missingSinceMs;
  int? _setupSinceMs;
  double? _setupAnchor;

  bool get inRep => _inRep;

  void reset() {
    reps = 0;
    validReps = 0;
    _inRep = false;
    _armed = false;
    _reachedDepth = false;
    _depthFrames = 0;
    _startMs = null;
    _lastTickMs = null;
    _missingSinceMs = null;
    _setupSinceMs = null;
    _setupAnchor = null;
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
  }) {
    _syncClock(timeMs);
    _missingSinceMs = null;
    if (_abandonIfOpenTooLong(timeMs)) return;
    _observeSetup(lift, angle, timeMs);

    switch (lift) {
      case LiftType.bench:
        _updateEccentric(
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
          angle: angle,
          timeMs: timeMs,
          startBelow: LiftThresholds.squatStart,
          depthAtOrBelow: LiftThresholds.squatDepth,
          lockoutAtOrAbove: LiftThresholds.squatLockout,
        );
    }
  }

  void _updateEccentric({
    required double angle,
    required int timeMs,
    required double startBelow,
    required double depthAtOrBelow,
    required double lockoutAtOrAbove,
  }) {
    if (angle < startBelow && !_inRep && _armed) {
      _beginRep(timeMs);
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
      }
      _clearPhase();
    }
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
    if (!keepArmed) _armed = false;
  }
}
