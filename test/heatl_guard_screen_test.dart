import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hercules/utils/test_helpers.dart';

void main() {
  testWidgets('Formulario visible con campos clave presentes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthGuardScreenFake());

    // Comprueba los campos de texto
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Peso (kg)'), findsOneWidget);
    expect(find.text('Altura (m)'), findsOneWidget);
    expect(find.text('Fecha de nacimiento (YYYY-MM-DD)'), findsOneWidget);

    // Comprueba el dropdown y el botón
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Guardar y Continuar'), findsOneWidget);
  });

  tearDownAll(() {
    print(
      '\n Test completados del boton guadar y continuar, correctamente en healt_guard_screen_test.dart\n',
    );
  });
}
