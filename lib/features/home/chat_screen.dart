import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import './api_config.dart';

class ChatScreen extends StatefulWidget {
  final int amigoId;
  const ChatScreen({super.key, required this.amigoId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _mensajes = [];
  final TextEditingController _mensajeController = TextEditingController();
  String? _nombreAmigo;
  Timer? _refreshTimer;
  String? _fotoAmigo;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _iniciarSesion();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    _obtenerMensajes();

    _refreshTimer = Timer.periodic(Duration(seconds: 5), (Timer t) {
      _obtenerMensajes();
    });
  }

  Future<void> _obtenerMensajes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    _userId = prefs.getInt('user_id');

    if (token == null || _userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/obtener_conversacion'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'usuario_id': _userId, 'amigo_id': widget.amigoId}),
      );

      if (response.statusCode == 200) {
        final List<dynamic>? data = json.decode(response.body);

        if (data == null) {
          print('Conversación vacía');
          setState(() {
            _mensajes = [];
          });
          return;
        }

        print('Conversación obtenida: $data');

        if (data.isNotEmpty) {
          final primerMensaje = data.first;
          if (primerMensaje['emisor_id'] == _userId) {
            _nombreAmigo = primerMensaje['receptor_nombre'];
            _fotoAmigo = primerMensaje['receptor_foto'] ?? 'default.png';
          } else {
            _nombreAmigo = primerMensaje['emisor_nombre'];
            _fotoAmigo = primerMensaje['emisor_foto'] ?? 'default.png';
          }
        }

        setState(() {
          _mensajes =
              data.map((e) {
                return {
                  'id': e['id'],
                  'emisor_id': e['emisor_id'],
                  'emisor_nombre': e['emisor_nombre'] ?? 'Desconocido',
                  'emisor_foto': e['emisor_foto'] ?? 'default.png',
                  'receptor_id': e['receptor_id'],
                  'receptor_nombre': e['receptor_nombre'] ?? 'Desconocido',
                  'receptor_foto': e['receptor_foto'] ?? 'default.png',
                  'mensaje': e['mensaje'] ?? '',
                  'fecha': e['fecha_envio'] ?? '',
                  'leido': e['leido'] == 1 ? true : false,
                };
              }).toList();
        });
      } else {
        print('Error al obtener la conversación: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener la conversación: $e');
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
          _mensajes =
              _mensajes.map((mensaje) {
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

  Future<void> _enviarMensaje() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || _userId == null || _mensajeController.text.isEmpty) {
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/enviar_mensaje'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emisor_fk': _userId,
          'receptor_fk': widget.amigoId,
          'mensaje': _mensajeController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        _mensajeController.clear();
        _obtenerMensajes();
      }
    } catch (e) {
      print('Error al enviar el mensaje: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  (_fotoAmigo != null && _fotoAmigo != 'default.png')
                      ? NetworkImage(
                        '${APIConfig.baseUrl}/fotos_perfil/$_fotoAmigo',
                      )
                      : const AssetImage('assets/default_avatar.png')
                          as ImageProvider,
              backgroundColor: Colors.grey[200],
              onBackgroundImageError: (exception, stackTrace) {
                print("Error al cargar la imagen: $exception");
              },
            ),
            const SizedBox(width: 10),
            Text(_nombreAmigo ?? 'Chat'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _refreshTimer?.cancel();
            context.go('/mensajes');
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final mensaje = _mensajes[index];
                final esMio = mensaje['emisor_id'] == _userId;

                //Nombre del usuario que envió el mensaje
                final nombreUsuario =
                    esMio ? "Yo" : (mensaje['emisor_nombre'] ?? 'Desconocido');

                return Align(
                  alignment:
                      esMio ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 10,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: esMio ? Colors.blue[200] : Colors.grey[300],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft:
                            esMio ? Radius.circular(12) : Radius.circular(0),
                        bottomRight:
                            esMio ? Radius.circular(0) : Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          esMio
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        if (!esMio)
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundImage:
                                    (_fotoAmigo != null &&
                                            _fotoAmigo != 'default.png')
                                        ? NetworkImage(
                                          '${APIConfig.baseUrl}/fotos_perfil/$_fotoAmigo',
                                        )
                                        : const AssetImage(
                                              'assets/default_avatar.png',
                                            )
                                            as ImageProvider,
                                backgroundColor: Colors.grey[200],
                                onBackgroundImageError: (
                                  exception,
                                  stackTrace,
                                ) {
                                  print(
                                    "Error al cargar la imagen: $exception",
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(
                                nombreUsuario,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        if (!esMio) const SizedBox(height: 5),
                        Text(
                          mensaje['mensaje'],
                          style: const TextStyle(color: Colors.black),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment:
                              esMio
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                          children: [
                            Text(
                              mensaje['fecha'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 5),
                            if (esMio)
                              mensaje['leido']
                                  ? Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 14,
                                  )
                                  : Icon(
                                    Icons.check,
                                    color: Colors.black54,
                                    size: 14,
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensajeController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _enviarMensaje,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
