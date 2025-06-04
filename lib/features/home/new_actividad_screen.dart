import 'package:flutter/material.dart';
import 'actividad_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'api_config.dart';

Future<void> _subirActividad(
  String deporte,
  XFile? gpxFile,
  List<XFile> imagenes,
) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final descripcion = deporte;

  final uri = Uri.parse('${APIConfig.baseUrl}/crear_actividad');
  var request = http.MultipartRequest('POST', uri)
    ..fields['descripcion'] = descripcion;

  if (token != null) {
    request.headers['Authorization'] = 'Bearer $token';
  } else {
    print('Token no encontrado');
    return;
  }

  if (gpxFile != null) {
    request.files.add(await http.MultipartFile.fromPath('gpx', gpxFile.path));
  }

  for (var img in imagenes) {
    request.files.add(await http.MultipartFile.fromPath('imagenes', img.path));
  }

  try {
    final response = await request.send();
    if (response.statusCode == 201) {
      print('Actividad subida');
    } else if (response.statusCode == 401) {
      print('No autorizado: token no valido o expirado');
    } else {
      print('Error al subir actividad: ${response.statusCode}');
    }
  } catch (e) {
    print('Excep. durante la subida: $e');
  }
}

void _mostrarFormularioSubida(BuildContext context) {
  final TextEditingController _deporteController = TextEditingController();
  XFile? _gpxFile;
  List<XFile> _imagenes = [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder:
        (context) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: StatefulBuilder(
            builder:
                (context, setState) => SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Subir Actividad',
                        style: TextStyle(fontSize: 20),
                      ),
                      TextField(
                        controller: _deporteController,
                        decoration: const InputDecoration(
                          labelText:
                              'Nombre del deporte o titulo de la publicacion',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final result = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (result != null) {
                            setState(() => _imagenes.add(result));
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Seleccionar imagen'),
                      ),
                      Wrap(
                        children:
                            _imagenes
                                .map(
                                  (img) => Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Image.file(
                                      File(img.path),
                                      height: 50,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                          );

                          if (result != null &&
                              result.files.single.path != null) {
                            final path = result.files.single.path!;
                            if (path.toLowerCase().endsWith('.gpx')) {
                              setState(() {
                                _gpxFile = XFile(path);
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Solo se permiten archivos .gpx',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.map),
                        label: Text(
                          _gpxFile == null
                              ? 'Seleccionar archivo GPX'
                              : 'GPX seleccionado',
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _subirActividad(
                            _deporteController.text,
                            _gpxFile,
                            _imagenes,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Subir'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
  );
}

class ActivityStartPage extends StatelessWidget {
  const ActivityStartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¿Qué quieres hacer?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormularioSubida(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Hacer una publicación'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecordingActivityPage(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Comenzar actividad'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
