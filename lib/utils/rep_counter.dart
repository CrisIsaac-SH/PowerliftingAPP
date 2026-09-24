import 'lift_rules.dart';

/// Cuenta repeticiones a partir de un ángulo ya calculado.
///
/// No conoce la cámara ni el video: recibe el ángulo, si la forma es válida
/// y el tiempo en milisegundos. La cámara y el analizador de video usan
/// esta misma clase.
class RepCounter {
  int reps = 0;
  int validReps = 0;

  bool _inRep = false;
  bool _reachedDepth = false;
  int _depthFrames = 0;
  int? _startMs;
  int? _lastTickMs;
  int? _missingSinceMs;

  bool get inRep => _inRep;

  void reset() {
    reps = 0;
    validReps = 0;
    _inRep = false;
    _reachedDepth = false;
    _depthFrames = 0;
    _startMs = null;
    _lastTickMs = null;
    _missingSinceMs = null;
  }

  /// Avisa que este frame no tiene la cadena del ejercicio.
  /// Si la ausencia se alarga, cancela la repetición abierta sin contarla.
  void markMissing(int timeMs) {
    _syncClock(timeMs);
    if (!_inRep) return;

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
    if (angle < startBelow && !_inRep) {
      _inRep = true;
      _startMs = timeMs;
      _depthFrames = 0;
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
      _clearPhase();
    }
  }

  void _updateDeadlift({
    required double angle,
    required int timeMs,
    required bool isValidForm,
  }) {
    if (angle < LiftThresholds.deadliftPhase && !_inRep) {
      _inRep = true;
      _startMs = timeMs;
    }
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

  void _syncClock(int timeMs) {
    final previous = _lastTickMs;
    if (previous != null && _inRep && _startMs != null) {
      final gap = timeMs - previous;
      if (gap > LiftThresholds.clockGapMs) {
        _startMs = _startMs! + gap;
        if (_missingSinceMs != null) {
          _missingSinceMs = _missingSinceMs! + gap;
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

  void _clearPhase() {
    _inRep = false;
    _reachedDepth = false;
    _depthFrames = 0;
    _startMs = null;
    _missingSinceMs = null;
  }
}
