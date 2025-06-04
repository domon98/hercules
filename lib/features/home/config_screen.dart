import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'api_config.dart';
import 'package:intl/intl.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  // Variables de la foto de perfil
  String? _fotoUrl;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes;

  // Controladores para los campos
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _alturaController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  String? _nivelActividad = '1.2';
  String? _genero = 'hombre';
  final TextEditingController _nombreCompletoController =
      TextEditingController();

  // Errores
  String? _errorPeso;
  String? _errorAltura;
  String? _errorFecha;
  String? _errorNombreCompleto;

  bool _isLoading = true;

  final List<DropdownMenuItem<String>> _actividadItems = const [
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
  ];

  final List<DropdownMenuItem<String>> _generoItems = const [
    DropdownMenuItem(value: 'hombre', child: Text('Hombre')),
    DropdownMenuItem(value: 'mujer', child: Text('Mujer')),
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
    _cargarNombreCompleto();
  }

  Widget _buildDropdownNivel() {
    return DropdownButtonFormField<String>(
      value: _nivelActividad,
      items: _actividadItems,
      onChanged: (value) {
        setState(() {
          _nivelActividad = value!;
        });
        _guardarDatos();
      },
      decoration: const InputDecoration(labelText: 'Nivel de Actividad'),
    );
  }

  Widget _buildDropdownGenero() {
    return DropdownButtonFormField<String>(
      value: _genero,
      items: _generoItems,
      onChanged: (value) {
        setState(() {
          _genero = value!;
        });
        _guardarDatos();
      },
      decoration: const InputDecoration(labelText: 'Género'),
    );
  }

  String _formatearFecha(String fecha) {
    try {
      DateTime parsedDate = DateTime.parse(fecha);
      return "${parsedDate.year.toString().padLeft(4, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
    } catch (e) {
      print("Error al formatear la fecha: $e");
      return "Fecha inválida";
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Eliminar el token del almacenamiento local
    await prefs.remove('token');

    // Mostrar un SnackBar con el mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesión cerrada correctamente'),
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
    );

    // Redirigir al login
    context.go('/login_home');
  }

  Future<void> _eliminarCuenta(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      return;
    }

    //Mostrar carga mientras se elimina
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final response = await http.delete(
        Uri.parse('${APIConfig.baseUrl}/eliminar_cuenta'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      Navigator.of(context).pop(); // Cierra el loader

      if (response.statusCode == 200) {
        // Eliminar el token de SharedPreferences
        await prefs.remove('token');

        // Muestra animación
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    "¡Listo! Tu cuenta ha sido eliminada correctamente.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    //Redirigir al login
                    context.go('/login_home');
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      } else {
        final errorResponse = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorResponse['mensaje'] ?? 'Error al eliminar cuenta',
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al eliminar cuenta')));
    }
  }

  void _mostrarDialogoEliminarCuenta(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Cuenta'),
          content: const Text(
            '⚠️ Se borrarán todos tus datos de forma permanente. Esta acción no se puede deshacer. ¿Estás seguro de continuar?',
            style: TextStyle(color: Colors.redAccent),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();
                await _eliminarCuenta(context);
              },
              child: const Text('Sí, Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> _loadImageFromNetwork(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'Connection': 'keep-alive',
            'Keep-Alive': 'timeout=5, max=1',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      print("Imagen descargada correctamente");
      return response.bodyBytes;
    } else {
      print("Error al descargar la imagen: ${response.statusCode}");
      throw Exception('Failed to load image');
    }
  }

  /// Seleccionar una nueva imagen
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  // Subir la nueva imagen al servidor y actualizar en tiempo real
  Future<void> _uploadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      return;
    }

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha seleccionado una imagen')),
      );
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${APIConfig.baseUrl}/usuario/foto_perfil'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath('foto_perfil', _imageFile!.path),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final data = jsonDecode(responseData);

      // Actualizar la URL y recargar los bytes de la imagen
      final nuevaUrl = '${APIConfig.baseUrl}/fotos_perfil/${data['ruta']}';
      print("🔄 Nueva URL de la imagen: $nuevaUrl");

      final imageBytes = await _loadImageFromNetwork(nuevaUrl);

      setState(() {
        _fotoUrl = nuevaUrl;
        _imageBytes = imageBytes;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al subir la imagen')));
    }
  }

  // Validación de formulario
  bool _validarFormulario() {
    final int? peso = int.tryParse(_pesoController.text);
    final double? altura = double.tryParse(_alturaController.text);

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
          _fechaController.text.isEmpty
              ? 'La fecha de nacimiento es obligatoria'
              : null;
    });

    return _errorPeso == null && _errorAltura == null && _errorFecha == null;
  }

  String? _validarContrasena(String contrasena) {
    print("🔍 Validando contraseña...");

    if (contrasena.length < 8) {
      print("❌ Contraseña demasiado corta");
      return 'Debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(contrasena)) {
      print("❌ Falta una letra mayúscula");
      return 'Debe contener una letra mayúscula';
    }
    if (!RegExp(r'[a-z]').hasMatch(contrasena)) {
      print("❌ Falta una letra minúscula");
      return 'Debe contener una letra minúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(contrasena)) {
      print("❌ Falta un número");
      return 'Debe contener un número';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(contrasena)) {
      print("❌ Falta un carácter especial");
      return 'Debe contener un carácter especial';
    }

    print("✅ Contraseña válida");
    return null;
  }

  Future<void> _cambiarContrasena(String actual, String nueva) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      return;
    }

    // Verificar que los campos no están vacíos
    if (actual.isEmpty || nueva.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los campos de contraseña no pueden estar vacíos'),
        ),
      );
      return;
    }

    final requestBody = jsonEncode({
      'contrasena_actual': actual,
      'contrasena_nueva': nueva,
    });

    final response = await http.put(
      Uri.parse('${APIConfig.baseUrl}/usuario/cambiar_contrasena'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña cambiada correctamente')),
      );
    } else {
      //  Imprimir el error
      print(
        "Error al cambiar contraseña: ${response.statusCode} - ${response.body}",
      );

      final errorResponse = jsonDecode(response.body);
      final mensaje = errorResponse['mensaje'];

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _mostrarDialogoCambioContrasena() async {
    final TextEditingController _actualController = TextEditingController();
    final TextEditingController _nuevaController = TextEditingController();
    final TextEditingController _repetirController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Cambiar Contraseña'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _actualController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña Actual',
                      ),
                      obscureText: true,
                    ),
                    TextField(
                      controller: _nuevaController,
                      decoration: const InputDecoration(
                        labelText: 'Nueva Contraseña',
                      ),
                      obscureText: true,
                    ),
                    TextField(
                      controller: _repetirController,
                      decoration: const InputDecoration(
                        labelText: 'Repetir Nueva Contraseña',
                      ),
                      obscureText: true,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    print("🛠️ Botón guardar pulsado");
                    final actual = _actualController.text;
                    final nueva = _nuevaController.text;
                    final repetir = _repetirController.text;

                    setState(() {
                      error = null;
                    });

                    //  1: Si no coinciden
                    if (nueva != repetir) {
                      print("❌ Las contraseñas no coinciden");
                      setState(() {
                        error = 'Las contraseñas no coinciden';
                      });
                      return;
                    }

                    // 2: Validación de requisitos
                    final errorValidacion = _validarContrasena(nueva);
                    if (errorValidacion != null) {
                      print("❌ Error en la validación: $errorValidacion");
                      setState(() {
                        error = errorValidacion;
                      });
                      return;
                    }

                    // 3: Verificación con el backend
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('token');

                      if (token == null) {
                        setState(() {
                          error = 'No has iniciado sesión';
                        });
                        return;
                      }

                      final requestBody = jsonEncode({
                        'contrasena_actual': actual,
                        'contrasena_nueva': nueva,
                      });

                      final response = await http.put(
                        Uri.parse(
                          '${APIConfig.baseUrl}/usuario/cambiar_contrasena',
                        ),
                        headers: {
                          'Authorization': 'Bearer $token',
                          'Content-Type': 'application/json',
                        },
                        body: requestBody,
                      );

                      if (response.statusCode == 200) {
                        print("Contraseña cambiada correctamente");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contraseña cambiada correctamente'),
                          ),
                        );
                        Navigator.pop(context);
                      } else {
                        final errorResponse = jsonDecode(response.body);
                        setState(() {
                          error =
                              errorResponse['mensaje'] ??
                              'Error al cambiar la contraseña';
                        });
                      }
                    } catch (e) {
                      print(" Error al cambiar la contraseña: $e");
                      setState(() {
                        error = "Error al cambiar la contraseña";
                      });
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cargarDatosUsuario() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final response = await http.get(
      Uri.parse('${APIConfig.baseUrl}/usuario'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final fotoPerfil = data['foto_perfil'];
      if (fotoPerfil != null) {
        final urlCompleta = '${APIConfig.baseUrl}/fotos_perfil/$fotoPerfil';
        print("URL de la imagen generada: $urlCompleta");

        try {
          final imageBytes = await _loadImageFromNetwork(urlCompleta);
          setState(() {
            _imageBytes = imageBytes;
            _fotoUrl = urlCompleta;
          });
        } catch (e) {
          print("Error al cargar la imagen: $e");
        }
      } else {
        print("No hay foto de perfil para este usuario.");
      }
      _pesoController.text =
          data['peso']?.toString().replaceAll('.00', '') ?? '';
      _alturaController.text =
          data['altura']?.toString().replaceAll('.00', '') ?? '';
      // Formatear fecha  solo visualmente
      if (data['fecha_nacimiento'] != null) {
        try {
          if (data['fecha_nacimiento'].contains('GMT')) {
            final dateFormat = DateFormat(
              "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
              'en_US',
            );
            DateTime fechaNacimiento = dateFormat.parse(
              data['fecha_nacimiento'],
            );

            _fechaController.text = DateFormat(
              'yyyy-MM-dd',
            ).format(fechaNacimiento);
          } else {
            DateTime fechaNacimiento = DateTime.parse(data['fecha_nacimiento']);
            _fechaController.text = DateFormat(
              'yyyy-MM-dd',
            ).format(fechaNacimiento);
          }
        } catch (e) {
          print("Error al formatear la fecha: $e");
          _fechaController.text =
              data['fecha_nacimiento']; // Mostramos el original
        }
      } else {
        _fechaController.text = '';
      }

      _nivelActividad = data['nivel_actividad']?.toString() ?? '1.2';
      _genero = data['genero'] ?? 'hombre';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar datos del usuario')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _cargarNombreCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      return;
    }

    final response = await http.get(
      Uri.parse('${APIConfig.baseUrl}/usuario/nombre_completo'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['nombre_completo'] == null || data['nombre_completo'].isEmpty) {
        _nombreCompletoController.text = "Nombre completo sin definir";
      } else {
        _nombreCompletoController.text = data['nombre_completo'];
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar el nombre completo')),
      );
    }
  }

  Future<void> _guardarDatos() async {
    if (!_validarFormulario()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      return;
    }

    final RegExp formatoFecha = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    String fechaTexto = _fechaController.text.trim();

    if (fechaTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha no puede estar vacía')),
      );
      return;
    }

    if (!formatoFecha.hasMatch(fechaTexto)) {
      try {
        if (fechaTexto.contains("GMT")) {
          final dateFormat = DateFormat(
            "EEE, dd MMM yyyy HH:mm:ss 'GMT'",
            'en_US',
          );
          DateTime fechaForzada = dateFormat.parse(fechaTexto);
          fechaTexto =
              "${fechaForzada.year.toString().padLeft(4, '0')}-${fechaForzada.month.toString().padLeft(2, '0')}-${fechaForzada.day.toString().padLeft(2, '0')}";
        } else {
          DateTime fechaForzada = DateTime.parse(fechaTexto);
          fechaTexto =
              "${fechaForzada.year.toString().padLeft(4, '0')}-${fechaForzada.month.toString().padLeft(2, '0')}-${fechaForzada.day.toString().padLeft(2, '0')}";
        }

        _fechaController.text = fechaTexto; // 🔄 Guardamos en el campo de texto
      } catch (e) {
        print("Error al formatear la fecha: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El formato de la fecha debe ser YYYY-MM-DD'),
          ),
        );
        return;
      }
    }

    DateTime? fecha;
    try {
      fecha = DateTime.parse(fechaTexto);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de fecha inválido')),
      );
      return;
    }

    final formattedDate =
        "${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
    print("Fecha correcta y formateada: $formattedDate");
    final requestBody = jsonEncode({
      'peso': _pesoController.text,
      'altura': _alturaController.text,
      'fecha_nacimiento': formattedDate,
      'nivel_actividad': _nivelActividad,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos guardados correctamente')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar los datos')),
      );
    }
  }

  Future<void> _guardarNombreCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No has iniciado sesión')));
      return;
    }

    final requestBody = jsonEncode({
      'nombre_completo': _nombreCompletoController.text,
    });

    final response = await http.put(
      Uri.parse('${APIConfig.baseUrl}/usuario/nombre_completo'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre actualizado correctamente')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el nombre')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          _imageBytes != null
                              ? Image.memory(
                                _imageBytes!,
                                width: 250,
                                height: 250,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error al cargar la imagen: $error');
                                  return const Icon(
                                    Icons.error,
                                    size: 100,
                                    color: Colors.red,
                                  );
                                },
                              )
                              : const Icon(Icons.person, size: 100),
                          TextButton(
                            onPressed: _pickImage,
                            child: const Text(
                              'Cambiar foto de perfil',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ExpansionTile(
                      title: const Text('Centro de Salud'),
                      children: [
                        _buildTextField(
                          'Peso (kg)',
                          _pesoController,
                          _errorPeso,
                        ),
                        _buildTextField(
                          'Altura (m)',
                          _alturaController,
                          _errorAltura,
                        ),
                        GestureDetector(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );

                            if (pickedDate != null) {
                              final formattedDate =
                                  "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";

                              _fechaController.text = formattedDate;

                              _guardarDatos();
                            }
                          },
                          child: AbsorbPointer(
                            child: _buildTextField(
                              'Fecha de Nacimiento',
                              _fechaController,
                              _errorFecha,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownNivel(),
                        const SizedBox(height: 10),
                        _buildDropdownGenero(),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text('Informacion Personal'),
                      children: [
                        //Nombre Completo
                        _buildTextField(
                          'Nombre Completo',
                          _nombreCompletoController,
                          _errorNombreCompleto,
                          onSave: _guardarNombreCompleto,
                        ),
                        const SizedBox(height: 10),

                        //Cambio de Contraseña
                        ElevatedButton(
                          onPressed: () {
                            _mostrarDialogoCambioContrasena();
                          },
                          child: const Text('Cambiar Contraseña'),
                        ),
                      ],
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          _mostrarDialogoEliminarCuenta(context);
                        },
                        child: const Text(
                          'Eliminar cuenta',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          bool? confirm = await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Cerrar Sesión'),
                                content: const Text(
                                  '¿Estás seguro de que quieres cerrar sesión?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    child: const Text(
                                      'Cerrar Sesión',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirm == true) {
                            await _cerrarSesion(context);
                          }
                        },
                        icon: const Icon(
                          Icons.power_settings_new,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? error, {
    bool readOnly = false,
    VoidCallback? onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, errorText: error),
          readOnly: readOnly,
          onSubmitted: (_) {
            if (onSave != null) {
              onSave();
            } else {
              _guardarDatos();
            }
          },
        ),
      ],
    );
  }
}
