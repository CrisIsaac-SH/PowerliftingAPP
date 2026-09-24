import 'lift_rules.dart';

/// Descarta un ángulo que saltó más rápido de lo que una articulación puede
/// moverse. Si el valor nuevo se sostiene en el frame siguiente, se acepta:
/// era un cambio real, no un punto mal puesto.
class AngleSampleGate {
  double? _lastAngle;
  int? _lastTimeMs;
  double? _pendingAngle;
  int? _pendingTimeMs;

  void reset() {
    _lastAngle = null;
    _lastTimeMs = null;
    _pendingAngle = null;
    _pendingTimeMs = null;
  }

  bool accept(double angle, int timeMs) {
    final lastAngle = _lastAngle;
    final lastTime = _lastTimeMs;
    if (lastAngle == null || lastTime == null) {
      _commit(angle, timeMs);
      return true;
    }

    if (timeMs - lastTime > LiftThresholds.clockGapMs) {
      _commit(angle, timeMs);
      return true;
    }

    if (_isPlausible(lastAngle, lastTime, angle, timeMs)) {
      _commit(angle, timeMs);
      return true;
    }

    final pendingAngle = _pendingAngle;
    final pendingTime = _pendingTimeMs;
    if (pendingAngle != null &&
        pendingTime != null &&
        _isPlausible(pendingAngle, pendingTime, angle, timeMs)) {
      _commit(angle, timeMs);
      return true;
    }

    _pendingAngle = angle;
    _pendingTimeMs = timeMs;
    return false;
  }

  bool _isPlausible(double fromAngle, int fromMs, double toAngle, int toMs) {
    final dt = toMs - fromMs;
    final delta = (toAngle - fromAngle).abs();
    if (dt <= 0) return delta <= 1;
    final speed = delta / (dt / 1000);
    return speed <= LiftThresholds.maxAngularSpeedDegPerSec;
  }

  void _commit(double angle, int timeMs) {
    _lastAngle = angle;
    _lastTimeMs = timeMs;
    _pendingAngle = null;
    _pendingTimeMs = null;
  }
}
