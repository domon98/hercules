import 'package:flutter/material.dart';

class HealthGuardScreenFake extends StatelessWidget {
  const HealthGuardScreenFake({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Completa tu perfil')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const TextField(
                decoration: InputDecoration(labelText: 'Peso (kg)'),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Altura (m)'),
              ),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Fecha de nacimiento (YYYY-MM-DD)',
                ),
              ),
              DropdownButtonFormField<String>(
                value: '1.2',
                items: const [
                  DropdownMenuItem<String>(
                    value: '1.2',
                    child: Text('Sedentario'),
                  ),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Guardar y Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
