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

  bool get inRep => _inRep;

  void reset() {
    reps = 0;
    validReps = 0;
    _inRep = false;
    _reachedDepth = false;
    _depthFrames = 0;
    _startMs = null;
  }

  void update({
    required LiftType lift,
    required double angle,
    required bool isValidForm,
    required int timeMs,
  }) {
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

  void _clearPhase() {
    _inRep = false;
    _reachedDepth = false;
    _depthFrames = 0;
    _startMs = null;
  }
}
