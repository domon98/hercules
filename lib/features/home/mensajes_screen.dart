import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import './api_config.dart';

class MensajesScreen extends StatefulWidget {
  const MensajesScreen({super.key});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  List<Map<String, dynamic>> mensajes = [];
  List<Map<String, dynamic>> _amigos = [];
  Map<String, dynamic>? _usuarioSeleccionado;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _obtenerAmigos();
    _obtenerMensajes();

    _refreshTimer = Timer.periodic(Duration(seconds: 5), (Timer t) {
      _obtenerMensajes();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _obtenerAmigos() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/obtener_amigos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("Amigos encontrados: $data");

        setState(() {
          _amigos =
              data
                  .map(
                    (e) => {
                      'id': e['id'],
                      'nombre': e['nombre'],
                      'foto': e['foto'] ?? 'assets/default_avatar.png',
                    },
                  )
                  .toList();
        });
      } else {
        print("Error al obtener amigos: ${response.statusCode}");
      }
    } catch (e) {
      print('Error al obtener amigos: $e');
    }
  }

  Future<void> _marcarComoLeido(int mensajeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/marcar_leido'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'mensaje_id': mensajeId}),
      );

      if (response.statusCode == 200) {
        print('Mensaje marcado como leído');
        setState(() {
          mensajes =
              mensajes.map((mensaje) {
                if (mensaje['id'] == mensajeId) {
                  return {...mensaje, 'leido': 1};
                }
                return mensaje;
              }).toList();
        });
      } else {
        print('Error al marcar como leído: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al marcar como leído: $e');
    }
  }

  Future<void> _obtenerMensajes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/obtener_mensajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'usuario_id': userId}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Datos recibidos: $data');
        print("Valor de userId al refrescar: $userId");

        final Map<int, Map<String, dynamic>> mensajesAgrupados = {};

        for (var mensaje in data) {
          final int otroUsuarioId =
              mensaje['emisor_id'] == userId
                  ? mensaje['receptor_id']
                  : mensaje['emisor_id'];

          if (!mensajesAgrupados.containsKey(otroUsuarioId) ||
              DateTime.parse(mensaje['fecha_envio']).isAfter(
                DateTime.parse(
                  mensajesAgrupados[otroUsuarioId]!['fecha_envio'],
                ),
              )) {
            mensajesAgrupados[otroUsuarioId] = mensaje;
          }
        }

        final List<Map<String, dynamic>> mensajesFiltrados =
            mensajesAgrupados.values.toList();
        mensajesFiltrados.sort((a, b) {
          return DateTime.parse(
            b['fecha_envio'],
          ).compareTo(DateTime.parse(a['fecha_envio']));
        });

        setState(() {
          mensajes = mensajesFiltrados;
        });

        print('Mensajes filtrados: $mensajes');
      } else {
        print('Error al obtener mensajes');
      }
    } catch (e) {
      print('Error en la petición HTTP: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _refreshTimer?.cancel();
            context.go('/amigos');
          },
        ),
      ),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final prefs = snapshot.data!;
          final int? userId = prefs.getInt('user_id');

          if (userId == null) {
            return const Center(child: Text("Usuario no identificado"));
          }

          return ListView.builder(
            itemCount: mensajes.length,
            itemBuilder: (context, index) {
              final mensaje = mensajes[index];

              final bool soyElEmisor = mensaje['emisor_id'] == userId;

              final String nombre =
                  soyElEmisor
                      ? (mensaje['receptor_nombre'] ?? 'Desconocido')
                      : (mensaje['emisor_nombre'] ?? 'Desconocido');

              final String foto =
                  soyElEmisor
                      ? (mensaje['receptor_foto'] ?? 'default.png')
                      : (mensaje['emisor_foto'] ?? 'default.png');

              final String fecha = mensaje['fecha_envio'] ?? '---';
              final String textoMensaje = mensaje['mensaje'] ?? '';

              final int otroUsuarioId =
                  soyElEmisor ? mensaje['receptor_id'] : mensaje['emisor_id'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 3,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[200],
                    backgroundImage:
                        foto.isNotEmpty
                            ? NetworkImage(
                              '${APIConfig.baseUrl}/fotos_perfil/$foto',
                            )
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      print("Error al cargar la imagen: $exception");
                    },
                  ),
                  title: Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    textoMensaje,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    fecha.contains(' ') ? fecha.split(' ')[1] : fecha,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    if (mensaje['receptor_id'] == userId) {
                      _marcarComoLeido(mensaje['id']);
                    }
                    _abrirChat(context, otroUsuarioId.toString());
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mostrarDialogoEnviarMensaje(context);
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  void _abrirChat(BuildContext context, String amigoId) {
    context.go('/chat/$amigoId');
  }

  void _mostrarDialogoEnviarMensaje(BuildContext context) {
    final TextEditingController _mensajeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enviar Mensaje'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: 'Seleccionar amigo',
                  border: OutlineInputBorder(),
                ),
                items:
                    _amigos.map((amigo) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: amigo,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  amigo != null
                                      ? NetworkImage(
                                        '${APIConfig.baseUrl}/fotos_perfil/${amigo['foto']}',
                                      )
                                      : const AssetImage(
                                            'assets/default_avatar.png',
                                          )
                                          as ImageProvider,
                              onBackgroundImageError: (exception, stackTrace) {
                                print("Error al cargar la imagen: $exception");
                              },
                            ),
                            const SizedBox(width: 10),
                            Text(amigo['nombre']),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _usuarioSeleccionado = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mensajeController,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_usuarioSeleccionado != null) {
                  _enviarMensaje(
                    _usuarioSeleccionado!['id'].toString(),
                    _mensajeController.text,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecciona un amigo')),
                  );
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enviarMensaje(String receptorId, String mensaje) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/enviar_mensaje'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emisor_fk': userId,
          'receptor_fk': int.parse(receptorId),
          'mensaje': mensaje,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensaje enviado correctamente')),
        );
        _obtenerMensajes();
      } else {
        print('Error al enviar el mensaje: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el mensaje')),
        );
      }
    } catch (e) {
      print('Error al enviar mensaje: $e');
    }
  }
}
