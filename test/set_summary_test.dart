import 'package:flutter_test/flutter_test.dart';
import 'package:powerliftingapp/utils/lift_rules.dart';
import 'package:powerliftingapp/utils/rep_counter.dart';
import 'package:powerliftingapp/utils/set_summary.dart';

CompletedRep rep(int number, double minAngle, {double? maxAngle, bool valid = true}) {
  return CompletedRep(
    repNumber: number,
    valid: valid,
    invalidReason: valid ? null : 'depth',
    minAngle: minAngle,
    maxAngle: maxAngle ?? minAngle,
    durationMs: 1000,
  );
}

void main() {
  test('marca la mejor, la peor y la primera repetición que pierde 4°', () {
    final summary = SetSummary.fromReps(LiftType.squat, [
      rep(1, 75),
      rep(2, 77),
      rep(3, 84, valid: false),
    ]);

    expect(summary!['best_rep'], 1);
    expect(summary['worst_rep'], 3);
    expect(summary['fatigue_onset_rep'], 3);
    expect(SetSummary.bestAngle(LiftType.squat, [
      rep(1, 75),
      rep(2, 77),
      rep(3, 84),
    ]), 75);
  });

  test('no marca fatiga si la profundidad se mantiene', () {
    final summary = SetSummary.fromReps(LiftType.squat, [
      rep(1, 80),
      rep(2, 82),
    ]);

    expect(summary!.containsKey('fatigue_onset_rep'), isFalse);
    expect(summary['best_rep'], 1);
    expect(summary['worst_rep'], 2);
  });

  test('en peso muerto la mejor repetición es el bloqueo más alto', () {
    final reps = [
      rep(1, 90, maxAngle: 162),
      rep(2, 90, maxAngle: 172),
    ];
    final summary = SetSummary.fromReps(LiftType.deadlift, reps);

    expect(summary!['best_rep'], 2);
    expect(summary['worst_rep'], 1);
    expect(summary.containsKey('fatigue_onset_rep'), isFalse);
    expect(SetSummary.bestAngle(LiftType.deadlift, reps), 172);
  });

  test('describe cada repetición y omite las que no se contaron', () {
    final lineas = SetSummary.describir([
      {'rep_number': 1, 'valid': true, 'min_angle': 74, 'torso_angle': 12},
      {'rep_number': 2, 'valid': false, 'invalid_reason': 'depth', 'min_angle': 101},
      {'rep_number': 1, 'valid': true, 'max_angle': 170, 'knee_angle': 168},
    ]);

    expect(lineas[0], 'Rep 1: 74° · torso 12°');
    expect(lineas[1], 'Rep 2: 101° · sin profundidad');
    expect(lineas[2], 'Rep 1: bloqueo 170°');
  });
}
