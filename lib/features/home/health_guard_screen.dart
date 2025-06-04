import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'api_config.dart';

class HealthGuardScreen extends StatefulWidget {
  const HealthGuardScreen({super.key});

  @override
  State<HealthGuardScreen> createState() => _HealthGuardScreenState();
}

class _HealthGuardScreenState extends State<HealthGuardScreen> {
  bool cargando = true;
  bool necesitaActualizar = false;

  // Controladores de los campos
  final TextEditingController _peso = TextEditingController();
  final TextEditingController _altura = TextEditingController();
  final TextEditingController _fechaNacimiento = TextEditingController();
  String? _genero = 'hombre';
  String? _nivelActividad = '1.2';

  // Errores
  String? _errorPeso;
  String? _errorAltura;
  String? _errorFecha;

  @override
  void initState() {
    super.initState();
    _verificarDatosUsuario();
  }

  Future<void> _verificarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      return;
    }

    final response = await http.get(
      Uri.parse('${APIConfig.baseUrl}/usuario'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['peso'] == null ||
          data['altura'] == null ||
          data['fecha_nacimiento'] == null ||
          data['nivel_actividad'] == null ||
          data['genero'] == null) {
        _peso.text = data['peso']?.toString() ?? '';
        _altura.text = data['altura']?.toString() ?? '';

        if (data['fecha_nacimiento'] != null) {
          final fechaParseada = DateTime.parse(data['fecha_nacimiento']);
          _fechaNacimiento.text =
              "${fechaParseada.year}-${fechaParseada.month.toString().padLeft(2, '0')}-${fechaParseada.day.toString().padLeft(2, '0')}";
        } else {
          _fechaNacimiento.text = '';
        }

        _genero = data['genero'] ?? 'hombre';
        _nivelActividad = data['nivel_actividad']?.toString() ?? '1.2';

        setState(() {
          necesitaActualizar = true;
          cargando = false;
        });
      } else {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/salud');
        });
      }
    } else {
      setState(() => cargando = false);
    }
  }

  bool _validarFormulario() {
    final int? peso = int.tryParse(_peso.text);
    final double? altura = double.tryParse(_altura.text);

    setState(() {
      _errorPeso =
          (peso == null || peso < 30 || peso > 300)
              ? 'El peso debe estar entre 30 y 300 kg'
              : null;

      _errorAltura =
          (altura == null || altura < 0.5 || altura > 3.0)
              ? 'La altura debe estar entre 0.5 y 3.0 m'
              : null;

      _errorFecha =
          _fechaNacimiento.text.isEmpty
              ? 'La fecha de nacimiento es obligatoria'
              : null;
    });

    return _errorPeso == null && _errorAltura == null && _errorFecha == null;
  }

  Future<void> _actualizarPerfil() async {
    if (!_validarFormulario()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final requestBody = jsonEncode({
      'peso': int.parse(_peso.text),
      'altura': double.parse(_altura.text),
      'fecha_nacimiento': _fechaNacimiento.text,
      'nivel_actividad': double.tryParse(_nivelActividad ?? '0'),
      'genero': _genero,
    });

    final response = await http.put(
      Uri.parse('${APIConfig.baseUrl}/usuario'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      if (!mounted) return;
      context.go('/salud');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar los datos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (necesitaActualizar) {
      return Scaffold(
        appBar: AppBar(title: const Text('Completa tu perfil')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Necesitamos algunos datos para continuar con tu monitoreo de salud',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _peso,
                decoration: InputDecoration(
                  labelText: 'Peso (kg)',
                  errorText: _errorPeso,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _altura,
                decoration: InputDecoration(
                  labelText: 'Altura (m)',
                  errorText: _errorAltura,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _fechaNacimiento,
                decoration: InputDecoration(
                  labelText: 'Fecha de nacimiento (YYYY-MM-DD)',
                  errorText: _errorFecha,
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    String formattedDate =
                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    setState(() {
                      _fechaNacimiento.text = formattedDate;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _nivelActividad,
                decoration: const InputDecoration(
                  labelText: 'Nivel de Actividad',
                ),
                items: const [
                  DropdownMenuItem(
                    value: '1.2',
                    child: Text('Sedentario (poco o nada de ejercicio al día)'),
                  ),
                  DropdownMenuItem(
                    value: '1.375',
                    child: Text('Actividad ligera (1-3 días a la semana)'),
                  ),
                  DropdownMenuItem(
                    value: '1.55',
                    child: Text('Actividad moderada (3-5 días a la semana)'),
                  ),
                  DropdownMenuItem(
                    value: '1.725',
                    child: Text('Actividad intensa (6-7 días a la semana)'),
                  ),
                  DropdownMenuItem(
                    value: '1.9',
                    child: Text('Muy intensa (ejercicio diario)'),
                  ),
                ],
                onChanged: (value) => setState(() => _nivelActividad = value),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _actualizarPerfil,
                child: const Text('Guardar y Continuar'),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox();
  }
}
