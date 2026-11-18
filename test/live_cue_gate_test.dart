import 'package:flutter_test/flutter_test.dart';
import 'package:powerliftingapp/utils/live_cue_gate.dart';

void main() {
  test('una repetición válida nueva suena una sola vez', () {
    final gate = LiveCueGate();

    expect(
      gate.observe(validReps: 1, alertCode: null, nowMs: 0),
      [LiveCue.success],
    );
    expect(
      gate.observe(validReps: 1, alertCode: null, nowMs: 40),
      isEmpty,
    );
    expect(
      gate.observe(validReps: 2, alertCode: null, nowMs: 80),
      [LiveCue.success],
    );
  });

  test('bajar el conteo no suena y la siguiente válida sí', () {
    final gate = LiveCueGate();
    gate.observe(validReps: 3, alertCode: null, nowMs: 0);

    expect(
      gate.observe(validReps: 0, alertCode: null, nowMs: 10),
      isEmpty,
    );
    expect(
      gate.observe(validReps: 1, alertCode: null, nowMs: 20),
      [LiveCue.success],
    );
  });

  test('la alerta suena al empezar y se repite si la posición sigue', () {
    final gate = LiveCueGate(alertRepeatMs: 1600);

    expect(
      gate.observe(validReps: 0, alertCode: 'valgus', nowMs: 0),
      [LiveCue.alert],
    );
    expect(
      gate.observe(validReps: 0, alertCode: 'valgus', nowMs: 500),
      isEmpty,
    );
    expect(
      gate.observe(validReps: 0, alertCode: 'valgus', nowMs: 1600),
      [LiveCue.alert],
    );
  });

  test('cambiar de falla suena de inmediato', () {
    final gate = LiveCueGate(alertRepeatMs: 1600);
    gate.observe(validReps: 0, alertCode: 'valgus', nowMs: 0);

    expect(
      gate.observe(validReps: 0, alertCode: 'torso', nowMs: 200),
      [LiveCue.alert],
    );
  });

  test('salir de la mala posición corta la alerta', () {
    final gate = LiveCueGate();
    gate.observe(validReps: 0, alertCode: 'valgus', nowMs: 0);

    expect(
      gate.observe(validReps: 0, alertCode: null, nowMs: 100),
      isEmpty,
    );
    expect(
      gate.observe(validReps: 0, alertCode: 'valgus', nowMs: 150),
      [LiveCue.alert],
    );
  });

  test('acierto y alerta pueden sonar en el mismo fotograma', () {
    final gate = LiveCueGate();

    expect(
      gate.observe(validReps: 1, alertCode: 'elbow_flare', nowMs: 0),
      [LiveCue.success, LiveCue.alert],
    );
  });

  test('reiniciar olvida el conteo y la alerta', () {
    final gate = LiveCueGate();
    gate.observe(validReps: 4, alertCode: 'torso', nowMs: 0);
    gate.reset();

    expect(
      gate.observe(validReps: 1, alertCode: null, nowMs: 5),
      [LiveCue.success],
    );
  });
}
