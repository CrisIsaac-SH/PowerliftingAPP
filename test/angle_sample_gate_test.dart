import 'package:flutter_test/flutter_test.dart';
import 'package:powerliftingapp/utils/angle_sample_gate.dart';

void main() {
  group('AngleSampleGate', () {
    test('acepta el primer ángulo y un cambio lento', () {
      final gate = AngleSampleGate();

      expect(gate.accept(160, 0), isTrue);
      expect(gate.accept(150, 50), isTrue);
    });

    test('rechaza un salto de 50 grados en un solo frame', () {
      final gate = AngleSampleGate();

      expect(gate.accept(140, 0), isTrue);
      expect(gate.accept(90, 40), isFalse);
    });

    test('si el salto vuelve al ángulo anterior, el frame siguiente sí cuenta', () {
      final gate = AngleSampleGate();

      expect(gate.accept(140, 0), isTrue);
      expect(gate.accept(90, 40), isFalse);
      expect(gate.accept(138, 80), isTrue);
    });

    test('si el ángulo nuevo se sostiene, el segundo frame se acepta', () {
      final gate = AngleSampleGate();

      expect(gate.accept(140, 0), isTrue);
      expect(gate.accept(90, 40), isFalse);
      expect(gate.accept(88, 80), isTrue);
    });

    test('después de una pausa acepta un ángulo distinto', () {
      final gate = AngleSampleGate();

      expect(gate.accept(140, 0), isTrue);
      expect(gate.accept(80, 2000), isTrue);
    });
  });
}
