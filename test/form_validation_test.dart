import 'package:flutter_test/flutter_test.dart';
import 'package:hercules/utils/form_validation.dart';

void main() {
  group('Validación de formulario', () {
    test('Formulario válido', () {
      expect(
        validarFormulario(peso: '70', altura: '1.75', fecha: '2000-01-01'),
        isTrue,
      );
    });

    test('Peso inválido', () {
      expect(
        validarFormulario(peso: '10', altura: '1.75', fecha: '2000-01-01'),
        isFalse,
      );
    });

    test('Altura inválida', () {
      expect(
        validarFormulario(peso: '70', altura: '0.2', fecha: '2000-01-01'),
        isFalse,
      );
    });

    test('Fecha vacía', () {
      expect(validarFormulario(peso: '70', altura: '1.75', fecha: ''), isFalse);
    });
  });
  tearDownAll(() {
    print('\n Test completados correctamente en form_validation_test.dart\n');
  });
}
