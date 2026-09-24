import 'package:flutter_test/flutter_test.dart';
import 'package:powerliftingapp/utils/lift_rules.dart';
import 'package:powerliftingapp/utils/rep_counter.dart';

void main() {
  void feed(
    RepCounter counter,
    LiftType lift,
    List<({int t, double angle, bool valid})> frames, {
    bool preparado = false,
  }) {
    if (preparado && frames.isNotEmpty) {
      final setupAngle = lift == LiftType.deadlift ? 90.0 : 170.0;
      final inicio = frames.first.t - LiftThresholds.setupHoldMs - 100;
      counter.update(
        lift: lift,
        angle: setupAngle,
        isValidForm: false,
        timeMs: inicio,
      );
      counter.update(
        lift: lift,
        angle: setupAngle,
        isValidForm: false,
        timeMs: inicio + LiftThresholds.setupHoldMs,
      );
    }
    for (final frame in frames) {
      counter.update(
        lift: lift,
        angle: frame.angle,
        isValidForm: frame.valid,
        timeMs: frame.t,
      );
    }
  }

  group('LiftThresholds.fromName', () {
    test('reconoce sentadilla, banca y peso muerto en español e inglés', () {
      expect(LiftThresholds.fromName('SQUAT'), LiftType.squat);
      expect(LiftThresholds.fromName('Sentadilla'), LiftType.squat);
      expect(LiftThresholds.fromName('BENCH PRESS'), LiftType.bench);
      expect(LiftThresholds.fromName('Press de banca'), LiftType.bench);
      expect(LiftThresholds.fromName('DEADLIFT'), LiftType.deadlift);
      expect(LiftThresholds.fromName('Peso muerto'), LiftType.deadlift);
    });

    test('un nombre desconocido se trata como sentadilla', () {
      expect(LiftThresholds.fromName('remo'), LiftType.squat);
    });
  });

  group('RepCounter sentadilla', () {
    test('cuenta una repetición válida si hay profundidad y vuelve arriba', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 170, valid: false),
        (t: 100, angle: 110, valid: false),
        (t: 250, angle: 80, valid: true),
        (t: 400, angle: 75, valid: true),
        (t: 1200, angle: 160, valid: false),
      ], preparado: true);

      expect(counter.reps, 1);
      expect(counter.validReps, 1);
      expect(counter.inRep, isFalse);
    });

    test('cuenta la repetición pero no la marca válida si no llega al fondo', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 110, valid: false),
        (t: 400, angle: 100, valid: false),
        (t: 1100, angle: 165, valid: false),
      ], preparado: true);

      expect(counter.reps, 1);
      expect(counter.validReps, 0);
    });

    test('descarta un movimiento más corto que 900 ms', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 40, angle: 70, valid: true),
        (t: 80, angle: 70, valid: true),
        (t: 200, angle: 170, valid: false),
      ], preparado: true);

      expect(counter.reps, 0);
      expect(counter.validReps, 0);
      expect(counter.inRep, isFalse);
    });

    test('no cierra la repetición si no vuelve al bloqueo', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 200, angle: 70, valid: true),
        (t: 400, angle: 70, valid: true),
        (t: 2000, angle: 100, valid: false),
      ], preparado: true);

      expect(counter.reps, 0);
      expect(counter.inRep, isTrue);
    });

    test('acumula dos repeticiones seguidas', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 110, valid: false),
        (t: 200, angle: 70, valid: true),
        (t: 350, angle: 70, valid: true),
        (t: 1100, angle: 160, valid: false),
        (t: 1300, angle: 110, valid: false),
        (t: 1500, angle: 70, valid: true),
        (t: 1650, angle: 70, valid: true),
        (t: 2500, angle: 160, valid: false),
      ], preparado: true);

      expect(counter.reps, 2);
      expect(counter.validReps, 2);
    });
  });

  group('RepCounter banca', () {
    test('exige dos fotogramas en el pecho para darla por válida', () {
      final counter = RepCounter();
      feed(counter, LiftType.bench, [
        (t: 0, angle: 100, valid: false),
        (t: 200, angle: 90, valid: true),
        (t: 1200, angle: 160, valid: false),
      ], preparado: true);

      expect(counter.reps, 1);
      expect(counter.validReps, 0);

      feed(counter, LiftType.bench, [
        (t: 1400, angle: 100, valid: false),
        (t: 1600, angle: 85, valid: true),
        (t: 1750, angle: 80, valid: true),
        (t: 2600, angle: 160, valid: false),
      ]);

      expect(counter.reps, 2);
      expect(counter.validReps, 1);
    });
  });

  group('RepCounter peso muerto', () {
    test('cuenta al volver a bajar después de un bloqueo sostenido', () {
      final counter = RepCounter();
      feed(counter, LiftType.deadlift, [
        (t: 0, angle: 100, valid: false),
        (t: 400, angle: 170, valid: true),
        (t: 1500, angle: 100, valid: false),
      ], preparado: true);

      expect(counter.reps, 1);
      expect(counter.validReps, 1);
    });

    test('no cuenta si nunca hubo bloqueo', () {
      final counter = RepCounter();
      feed(counter, LiftType.deadlift, [
        (t: 0, angle: 90, valid: false),
        (t: 800, angle: 140, valid: false),
        (t: 2000, angle: 90, valid: false),
      ], preparado: true);

      expect(counter.reps, 0);
      expect(counter.inRep, isTrue);
    });
  });

  group('RepCounter reset', () {
    test('borra el conteo y la fase abierta', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 200, angle: 70, valid: true),
        (t: 400, angle: 70, valid: true),
        (t: 1400, angle: 160, valid: false),
        (t: 1600, angle: 100, valid: false),
      ], preparado: true);

      expect(counter.reps, 1);
      expect(counter.inRep, isTrue);

      counter.reset();

      expect(counter.reps, 0);
      expect(counter.validReps, 0);
      expect(counter.inRep, isFalse);
    });
  });

  group('RepCounter repetición abierta', () {
    test('un parpadeo corto de la cadena no cancela la sentadilla', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 200, angle: 70, valid: true),
        (t: 400, angle: 70, valid: true),
      ], preparado: true);
      counter.markMissing(700);
      feed(counter, LiftType.squat, [
        (t: 1100, angle: 160, valid: false),
      ]);

      expect(counter.reps, 1);
      expect(counter.validReps, 1);
    });

    test('si la cadena falta 1.2 s, un cierre posterior no cuenta esa rep', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 200, angle: 70, valid: true),
        (t: 400, angle: 70, valid: true),
      ], preparado: true);
      counter.markMissing(600);
      counter.markMissing(1900);

      expect(counter.inRep, isFalse);

      feed(counter, LiftType.squat, [
        (t: 2100, angle: 160, valid: false),
      ]);

      expect(counter.reps, 0);
      expect(counter.validReps, 0);
    });

    test('una sentadilla que no cierra en 6 s se descarta', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 1000, angle: 70, valid: true),
        (t: 2000, angle: 70, valid: true),
        (t: 3000, angle: 90, valid: true),
        (t: 4000, angle: 90, valid: true),
        (t: 5000, angle: 100, valid: false),
        (t: 6000, angle: 110, valid: false),
      ], preparado: true);

      expect(counter.reps, 0);
      expect(counter.inRep, isFalse);
    });

    test('una pausa larga no borra la repetición que ya iba en curso', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 400, angle: 70, valid: true),
        (t: 800, angle: 70, valid: true),
        (t: 1000, angle: 80, valid: true),
      ], preparado: true);
      feed(counter, LiftType.squat, [
        (t: 8000, angle: 160, valid: false),
      ]);

      expect(counter.reps, 1);
      expect(counter.validReps, 1);
    });
  });

  group('RepCounter posición inicial quieta', () {
    test('bajar sin quedarse arriba no abre la sentadilla', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 170, valid: false),
        (t: 150, angle: 140, valid: false),
        (t: 300, angle: 90, valid: false),
        (t: 500, angle: 70, valid: true),
        (t: 700, angle: 70, valid: true),
        (t: 1600, angle: 165, valid: false),
      ]);

      expect(counter.reps, 0);
      expect(counter.inRep, isFalse);
    });

    test('quedarse quieto arriba permite abrir la sentadilla', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 168, valid: false),
        (t: 500, angle: 172, valid: false),
        (t: 700, angle: 100, valid: false),
        (t: 900, angle: 70, valid: true),
        (t: 1050, angle: 70, valid: true),
        (t: 1800, angle: 165, valid: false),
      ]);

      expect(counter.reps, 1);
      expect(counter.validReps, 1);
    });

    test('si el ángulo se mueve mucho, la espera vuelve a empezar', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 170, valid: false),
        (t: 200, angle: 150, valid: false),
        (t: 400, angle: 100, valid: false),
        (t: 1400, angle: 165, valid: false),
      ]);

      expect(counter.reps, 0);
      expect(counter.inRep, isFalse);
    });

    test('pasar rápido por el suelo no abre el peso muerto', () {
      final counter = RepCounter();
      feed(counter, LiftType.deadlift, [
        (t: 0, angle: 90, valid: false),
        (t: 200, angle: 170, valid: true),
        (t: 1500, angle: 90, valid: false),
      ]);

      expect(counter.reps, 0);
      expect(counter.inRep, isFalse);
    });

    test('una pausa durante la espera no la da por cumplida', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 170, valid: false),
        (t: 2000, angle: 170, valid: false),
        (t: 2300, angle: 100, valid: false),
        (t: 2500, angle: 70, valid: true),
        (t: 2700, angle: 70, valid: true),
        (t: 3600, angle: 165, valid: false),
      ]);

      expect(counter.reps, 0);
      expect(counter.inRep, isFalse);
    });

    test('tras perder la cadena hay que quietarse otra vez', () {
      final counter = RepCounter();
      feed(counter, LiftType.squat, [
        (t: 0, angle: 100, valid: false),
        (t: 200, angle: 70, valid: true),
      ], preparado: true);
      counter.markMissing(400);
      counter.markMissing(1700);
      feed(counter, LiftType.squat, [
        (t: 1900, angle: 100, valid: false),
        (t: 2100, angle: 70, valid: true),
        (t: 2300, angle: 70, valid: true),
        (t: 3200, angle: 165, valid: false),
      ]);

      expect(counter.reps, 0);

      feed(counter, LiftType.squat, [
        (t: 3700, angle: 168, valid: false),
        (t: 3900, angle: 100, valid: false),
        (t: 4100, angle: 70, valid: true),
        (t: 4300, angle: 70, valid: true),
        (t: 5100, angle: 165, valid: false),
      ]);

      expect(counter.reps, 1);
      expect(counter.validReps, 1);
    });
  });
}
