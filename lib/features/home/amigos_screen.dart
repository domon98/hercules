import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import './api_config.dart';

class AmigosScreen extends StatefulWidget {
  const AmigosScreen({super.key});

  @override
  State<AmigosScreen> createState() => _AmigosScreenState();
}

class _AmigosScreenState extends State<AmigosScreen> {
  // 🔄 Variables de control
  bool _isSearching = false;
  bool _mostrarSolicitudes = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _resultadosBusqueda = [];
  List<Map<String, dynamic>> _solicitudesPendientes = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _obtenerSolicitudesPendientes(); // 🔄 Cargar solicitudes al iniciar
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _obtenerSolicitudesPendientes();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // 🔄 Cancelar el Timer cuando se elimina el widget
    super.dispose();
  }

  Future<void> _obtenerSolicitudesPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${APIConfig.baseUrl}/obtener_solicitudes?usuario_id=$userId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _solicitudesPendientes =
              data
                  .map(
                    (e) => {
                      'id': e['id'],
                      'usuario_fk':
                          e['usuario_fk'], // 🔄 Aquí añadimos el usuario_fk
                      'nombre': e['nombre'],
                      'foto': e['foto'] ?? 'assets/default_avatar.png',
                    },
                  )
                  .toList();
        });
      }
    } catch (e) {
      print('Error al obtener solicitudes pendientes: $e');
    }
  }

  Future<void> _aceptarSolicitud(int solicitudId, int usuarioFk) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id'); // El ID del usuario logueado

    if (token == null || userId == null) return;

    print("✅ Datos enviados: usuario_fk=$usuarioFk, amigo_fk=$userId");

    final response = await http.post(
      Uri.parse('${APIConfig.baseUrl}/aceptar_solicitud'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'usuario_fk': userId, // 👉 El usuario que envió la solicitud
        'amigo_fk': usuarioFk, // 👉 El usuario logueado que la acepta
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada correctamente')),
      );

      await _buscarAmigos(_searchController.text);

      setState(() {
        _solicitudesPendientes.removeWhere((sol) => sol['id'] == solicitudId);

        // 🔄 Actualizamos la lista de búsqueda
        _resultadosBusqueda =
            _resultadosBusqueda.map((usuario) {
              if (usuario['id'] == solicitudId) {
                return {...usuario, 'estado': 'pendiente'};
              }
              return usuario;
            }).toList();
      });
    } else {
      print('❌ Error al aceptar la solicitud: ${response.body}');
    }
  }

  // 🔄 Rechazar solicitud
  Future<void> _rechazarSolicitud(int amigoId, int usuarioFk) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id'); // El ID del usuario logueado

    print(
      "✅ Datos enviados en rechazar: usuario_fk=$userId, amigo_fk=$usuarioFk",
    );

    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/rechazar_solicitud'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'usuario_fk': usuarioFk, // ✅ Usuario que envió la solicitud
          'amigo_fk': userId, // ✅ Usuario que rechaza
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada correctamente')),
        );

        // 🔄 Actualizamos la lista
        setState(() {
          _solicitudesPendientes.removeWhere((sol) => sol['id'] == amigoId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo rechazar la solicitud')),
        );
      }
    } catch (e) {
      print('Error al rechazar solicitud: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error de conexión')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.person_add),
              label: Text(
                'Solicitudes Pendientes (${_solicitudesPendientes.length})',
              ),
              onPressed: () {
                setState(() {
                  _mostrarSolicitudes = !_mostrarSolicitudes;
                });
              },
            ),
            if (_mostrarSolicitudes) _buildSolicitudesList(),
            const SizedBox(height: 10),
            // 🔹 Botón de Buscar Amigos
            ElevatedButton.icon(
              icon: Icon(Icons.search),
              label: Text('Buscar Usuarios'),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _resultadosBusqueda.clear();
                  }
                });
              },
            ),
            if (_isSearching) _buildSearchField(),
            const SizedBox(height: 10),
            // 🔹 Botón de Mensajes
            ElevatedButton.icon(
              icon: Icon(Icons.message),
              label: Text('Mensajes'),
              onPressed: () {
                context.go('/mensajes');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buscarAmigos(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/buscar_usuarios'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'nombre': nombre, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          _resultadosBusqueda =
              data.map((e) {
                return {
                  'id': e['id'],
                  'nombre': e['nombre'],
                  'foto': e['foto'],
                  'estado': e['estado'],
                };
              }).toList();
        });
      }
    } catch (e) {
      print('Error al buscar usuarios: $e');
    }
  }

  Future<void> _enviarSolicitud(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    int? usuarioId = prefs.getInt('user_id');

    if (usuarioId == null) {
      print("❌ No se ha encontrado el ID del usuario en SharedPreferences");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/enviar_solicitud'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'usuario_fk': usuarioId, 'amigo_fk': userId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada correctamente')),
        );

        // 🔄 Actualizamos el estado del botón en la lista local
        setState(() {
          _resultadosBusqueda =
              _resultadosBusqueda.map((usuario) {
                if (usuario['id'].toString() == userId) {
                  print("✅ Actualizando usuario: ${usuario['nombre']}");
                  return {...usuario, 'estado': 'pendiente'};
                }
                return usuario;
              }).toList();
        });
      } else {
        print('❌ Error al enviar la solicitud: ${response.body}');
      }
    } catch (e) {
      print('Error al enviar solicitud: $e');
    }
  }

  // 🔄 Método para construir el campo de búsqueda y los resultados
  Widget _buildSearchField() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Nombre de usuario',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (value.length > 2) {
              _buscarAmigos(value);
            }
          },
        ),
        const SizedBox(height: 10),
        ..._resultadosBusqueda.map(
          (usuario) => ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  (usuario['foto'] != null &&
                          usuario['foto'].startsWith('http'))
                      ? NetworkImage(usuario['foto'])
                      : (usuario['foto'] != null
                              ? NetworkImage(
                                '${APIConfig.baseUrl}/fotos_perfil/${usuario['foto']}',
                              )
                              : const AssetImage('assets/default_avatar.png'))
                          as ImageProvider,
              onBackgroundImageError: (_, __) {
                print("❌ Error al cargar la imagen, mostrando la por defecto.");
              },
              backgroundColor: Colors.grey[200],
            ),
            title: Text(usuario['nombre'] ?? 'Usuario'),
            trailing:
                usuario['estado'] == 'aceptado'
                    ? ElevatedButton(
                      onPressed: () {
                        context.go('/perfil/${usuario['id']}');
                      },
                      child: const Text('Mostrar Perfil'),
                    )
                    : usuario['estado'] == 'pendiente'
                    ? ElevatedButton(
                      onPressed: null, // 🔒 Botón deshabilitado
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text('Solicitud Enviada'),
                    )
                    : ElevatedButton(
                      onPressed: () {
                        _enviarSolicitud(usuario['id'].toString());
                      },
                      child: const Text('Enviar Solicitud'),
                    ),
          ),
        ),
      ],
    );
  }

  // 🔄 Construcción de la lista de solicitudes
  Widget _buildSolicitudesList() {
    return Column(
      children:
          _solicitudesPendientes.map((solicitud) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                    solicitud['foto'].startsWith('http')
                        ? solicitud['foto']
                        : '${APIConfig.baseUrl}/fotos_perfil/${solicitud['foto']}',
                  ),
                  onBackgroundImageError: (_, __) {
                    print(
                      "❌ Error al cargar la imagen, mostrando la por defecto.",
                    );
                  },
                  backgroundColor: Colors.grey[200],
                  child:
                      solicitud['foto'] == null || solicitud['foto'] == ''
                          ? Image.asset('assets/default_avatar.png')
                          : null,
                ),
                title: Text(solicitud['nombre'] ?? 'Usuario'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        // 🔄 Aquí pasas los IDs correctamente
                        _aceptarSolicitud(
                          solicitud['id'],
                          solicitud['usuario_fk'], // ✅ Esto antes estaba mal
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        _rechazarSolicitud(
                          solicitud['id'],
                          solicitud['usuario_fk'], // ✅ Igualmente corregido
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }
}
