import 'package:flutter_test/flutter_test.dart';
import 'package:hercules/utils/test_helpers.dart'; // Asegúrate de que esta ruta es correcta

void main() {
  testWidgets('Verifica que el texto "Completa tu perfil" se muestra', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HealthGuardScreenFake());

    expect(find.text('Completa tu perfil'), findsOneWidget);
  });

  tearDownAll(() {
    print(
      '\n Test del texto a mostrar completados correctamente en healt_guard_test.dart\n',
    );
  });
}
