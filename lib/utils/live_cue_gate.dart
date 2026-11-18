/// Sonido que la cámara en vivo debe reproducir en este fotograma.
enum LiveCue { success, alert }

/// Decide cuándo suena el acierto y cuándo la alerta.
///
/// El acierto suena una vez por cada repetición válida nueva. La alerta suena
/// al entrar en una mala posición y, si esa posición sigue, otra vez al pasar
/// [alertRepeatMs]. Así no pita en cada fotograma.
class LiveCueGate {
  LiveCueGate({this.alertRepeatMs = 1600});

  final int alertRepeatMs;

  int _validReps = 0;
  String? _alertCode;
  int? _lastAlertMs;

  List<LiveCue> observe({
    required int validReps,
    required String? alertCode,
    required int nowMs,
  }) {
    final cues = <LiveCue>[];
    if (validReps > _validReps) cues.add(LiveCue.success);
    _validReps = validReps;

    if (alertCode == null) {
      _alertCode = null;
      return cues;
    }

    final changed = alertCode != _alertCode;
    final due = _lastAlertMs == null || nowMs - _lastAlertMs! >= alertRepeatMs;
    _alertCode = alertCode;
    if (!changed && !due) return cues;

    _lastAlertMs = nowMs;
    cues.add(LiveCue.alert);
    return cues;
  }

  void reset() {
    _validReps = 0;
    _alertCode = null;
    _lastAlertMs = null;
  }
}
