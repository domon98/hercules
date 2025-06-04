import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../home/api_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  // Validar usuario (solo letras y números, mínimo 3 caracteres)
  bool _validarUsuario(String usuario) {
    final RegExp regex = RegExp(r'^[a-zA-Z0-9]{3,}$');
    return regex.hasMatch(usuario);
  }

  // Validar contraseña segura
  String? _validarContrasena(String contrasena) {
    if (contrasena.length < 8) return 'Debe tener al menos 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(contrasena))
      return 'Debe contener una letra mayúscula';
    if (!RegExp(r'[a-z]').hasMatch(contrasena))
      return 'Debe contener una letra minúscula';
    if (!RegExp(r'[0-9]').hasMatch(contrasena))
      return 'Debe contener un número';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(contrasena))
      return 'Debe contener un carácter especial';
    return null;
  }

  Future<void> _registrarUsuario() async {
    if (!_validarUsuario(_username.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El nombre de usuario solo puede contener letras y números (mínimo 3)',
          ),
        ),
      );
      return;
    }

    final contrasenaError = _validarContrasena(_password.text);
    if (contrasenaError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(contrasenaError)));
      return;
    }

    if (_password.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('${APIConfig.baseUrl}/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre_usuario': _username.text.trim(),
        'correo': _email.text.trim(),
        'contrasena': _password.text,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Usuario registrado! Inicia sesión.')),
      );
      context.go('/login_home');
    } else {
      if (!mounted) return;
      final body = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['mensaje'] ?? 'Error en el registro')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/login_home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 25),

              ElevatedButton(
                onPressed: _registrarUsuario,
                child: const Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
