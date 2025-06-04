import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginHomeScreen extends StatelessWidget {
  const LoginHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                context.go('/login');
              },
              child: const Text(
                'Ya tengo cuenta',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                context.go('/register');
              },
              child: const Text(
                'Unirme a la comunidad',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
