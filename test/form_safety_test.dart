import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:powerliftingapp/utils/form_safety.dart';
import 'package:powerliftingapp/utils/lift_rules.dart';
import 'package:powerliftingapp/utils/pose_math_utils.dart';

void main() {
  PoseLandmark punto(PoseLandmarkType type, double x, double y) {
    return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.95);
  }

  FormReading lectura({
    required LiftType lift,
    required bool repStarted,
    double? torsoLean,
    KneeAdvance? kneeTravel,
    double? kneeValgus,
    double? kneeAsymmetry,
    double? elbowFlare,
    double? hipAngle,
    double? kneeAngle,
  }) {
    return FormReading(
      lift: lift,
      repStarted: repStarted,
      torsoLean: torsoLean,
      kneeTravel: kneeTravel,
      kneeValgus: kneeValgus,
      kneeAsymmetry: kneeAsymmetry,
      elbowFlare: elbowFlare,
      hipAngle: hipAngle,
      kneeAngle: kneeAngle,
    );
  }

  group('FormSafety', () {
    test('no avisa si la repetición todavía no empezó', () {
      final alerts = FormSafety.evaluate(
        lectura(
          lift: LiftType.squat,
          repStarted: false,
          torsoLean: 80,
          kneeValgus: 0.4,
        ),
      );

      expect(alerts, isEmpty);
    });

    test('sentadilla avisa valgo, torso, asimetría y rodilla adelantada', () {
      final alerts = FormSafety.evaluate(
        lectura(
          lift: LiftType.squat,
          repStarted: true,
          torsoLean: 70,
          kneeValgus: 0.25,
          kneeAsymmetry: 30,
          kneeTravel: const KneeAdvance(ratio: 0.2, measuredFromToes: true),
        ),
      );

      expect(alerts.map((alert) => alert.code), [
        'valgus',
        'torso',
        'asymmetry',
        'knee_travel',
      ]);
    });

    test('la rodilla sobre el tobillo exige más avance que sobre la punta del pie', () {
      final sobreTobillo = FormSafety.evaluate(
        lectura(
          lift: LiftType.squat,
          repStarted: true,
          kneeTravel: const KneeAdvance(ratio: 0.2, measuredFromToes: false),
        ),
      );
      final sobrePunta = FormSafety.evaluate(
        lectura(
          lift: LiftType.squat,
          repStarted: true,
          kneeTravel: const KneeAdvance(ratio: 0.2, measuredFromToes: true),
        ),
      );

      expect(sobreTobillo, isEmpty);
      expect(sobrePunta.single.code, 'knee_travel');
    });

    test('banca avisa codos abiertos solo durante la repetición', () {
      expect(
        FormSafety.evaluate(
          lectura(lift: LiftType.bench, repStarted: false, elbowFlare: 2.4),
        ),
        isEmpty,
      );
      expect(
        FormSafety.evaluate(
          lectura(lift: LiftType.bench, repStarted: true, elbowFlare: 2.4),
        ).single.code,
        'elbow_flare',
      );
    });

    test('peso muerto avisa espalda redonda y cadera que sube primero', () {
      final alerts = FormSafety.evaluate(
        lectura(
          lift: LiftType.deadlift,
          repStarted: true,
          torsoLean: 82,
          hipAngle: 120,
          kneeAngle: 158,
        ),
      );

      expect(alerts.map((alert) => alert.code), ['round_back', 'hip_shoot']);
    });

    test('el bloqueo del peso muerto no se lee como cadera adelantada', () {
      final alerts = FormSafety.evaluate(
        lectura(
          lift: LiftType.deadlift,
          repStarted: true,
          torsoLean: 20,
          hipAngle: 170,
          kneeAngle: 170,
        ),
      );

      expect(alerts, isEmpty);
    });
  });

  group('FormAlertLatch', () {
    test('espera varios frames antes de mostrar y de apagar', () {
      final latch = FormAlertLatch();
      const alerta = FormAlert(code: 'torso', message: 'Pecho arriba.');

      expect(latch.update(const [alerta]), isNull);
      expect(latch.update(const [alerta]), isNull);
      expect(latch.update(const [alerta])?.code, 'torso');

      expect(latch.update(const []), isNotNull);
      expect(latch.update(const []), isNotNull);
      expect(latch.update(const []), isNotNull);
      expect(latch.update(const []), isNull);
    });
  });

  group('medidas de posición', () {
    test('la rodilla por delante de la punta del pie da un avance positivo', () {
      final pose = Pose(
        landmarks: {
          PoseLandmarkType.rightHip: punto(PoseLandmarkType.rightHip, 0, 0),
          PoseLandmarkType.rightKnee: punto(PoseLandmarkType.rightKnee, 80, 50),
          PoseLandmarkType.rightAnkle: punto(PoseLandmarkType.rightAnkle, 40, 100),
          PoseLandmarkType.rightFootIndex: punto(PoseLandmarkType.rightFootIndex, 50, 105),
        },
      );

      final avance = PoseMathUtils.avanceRodilla(pose, PoseSide.right);
      expect(avance, isNotNull);
      expect(avance!.measuredFromToes, isTrue);
      expect(avance.ratio, greaterThan(LiftThresholds.squatKneePastToe));
    });

    test('en vista frontal no se inventa avance de rodilla ni apertura de codos', () {
      final pose = Pose(
        landmarks: {
          PoseLandmarkType.rightHip: punto(PoseLandmarkType.rightHip, 100, 0),
          PoseLandmarkType.rightKnee: punto(PoseLandmarkType.rightKnee, 100, 50),
          PoseLandmarkType.rightAnkle: punto(PoseLandmarkType.rightAnkle, 102, 100),
          PoseLandmarkType.leftShoulder: punto(PoseLandmarkType.leftShoulder, 80, 0),
          PoseLandmarkType.rightShoulder: punto(PoseLandmarkType.rightShoulder, 82, 0),
          PoseLandmarkType.leftElbow: punto(PoseLandmarkType.leftElbow, 70, 40),
          PoseLandmarkType.rightElbow: punto(PoseLandmarkType.rightElbow, 90, 40),
        },
      );

      expect(PoseMathUtils.avanceRodilla(pose, PoseSide.right), isNull);
      expect(PoseMathUtils.aperturaCodos(pose), isNull);
    });

    test('el valgo mide la rodilla que se mete hacia el centro', () {
      final pose = Pose(
        landmarks: {
          PoseLandmarkType.leftShoulder: punto(PoseLandmarkType.leftShoulder, 0, -80),
          PoseLandmarkType.rightShoulder: punto(PoseLandmarkType.rightShoulder, 100, -80),
          PoseLandmarkType.leftHip: punto(PoseLandmarkType.leftHip, 10, 0),
          PoseLandmarkType.rightHip: punto(PoseLandmarkType.rightHip, 90, 0),
          PoseLandmarkType.leftKnee: punto(PoseLandmarkType.leftKnee, 35, 40),
          PoseLandmarkType.rightKnee: punto(PoseLandmarkType.rightKnee, 70, 40),
          PoseLandmarkType.leftAnkle: punto(PoseLandmarkType.leftAnkle, 5, 80),
          PoseLandmarkType.rightAnkle: punto(PoseLandmarkType.rightAnkle, 95, 80),
        },
      );

      final valgo = PoseMathUtils.valgoRodillas(pose);
      expect(valgo, isNotNull);
      expect(valgo!, greaterThan(LiftThresholds.squatValgus));
    });

    test('los codos abiertos superan el ancho de hombros', () {
      final pose = Pose(
        landmarks: {
          PoseLandmarkType.leftShoulder: punto(PoseLandmarkType.leftShoulder, 40, 0),
          PoseLandmarkType.rightShoulder: punto(PoseLandmarkType.rightShoulder, 80, 0),
          PoseLandmarkType.leftElbow: punto(PoseLandmarkType.leftElbow, 0, 30),
          PoseLandmarkType.rightElbow: punto(PoseLandmarkType.rightElbow, 120, 30),
        },
      );

      final flare = PoseMathUtils.aperturaCodos(pose);
      expect(flare, isNotNull);
      expect(flare!, greaterThan(LiftThresholds.benchElbowFlare));
    });
  });
}
