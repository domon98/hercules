import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapaActividad extends StatelessWidget {
  final List<dynamic> puntosGps;

  const MapaActividad({super.key, required this.puntosGps});

  @override
  Widget build(BuildContext context) {
    if (puntosGps.isEmpty) return const Text('Sin datos GPS');

    final puntos =
        puntosGps
            .where((p) => p['lat'] != null && p['lon'] != null)
            .map(
              (p) => LatLng(
                double.parse(p['lat'].toString()),
                double.parse(p['lon'].toString()),
              ),
            )
            .toList();

    if (puntos.isEmpty) return const Text('Datos GPS inválidos');

    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(puntos),
            padding: const EdgeInsets.all(20),
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(points: puntos, strokeWidth: 4, color: Colors.blue),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: puntos.first,
                width: 30,
                height: 30,
                child: const Icon(Icons.play_arrow, color: Colors.green),
              ),
              Marker(
                point: puntos.last,
                width: 30,
                height: 30,
                child: const Icon(Icons.flag, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Publicacion {
  final int id;
  final int idUserPub;
  final String? imagen;

  Publicacion({required this.id, this.imagen, required this.idUserPub});

  factory Publicacion.fromJson(Map<String, dynamic> json) {
    return Publicacion(
      id: json['id'],
      imagen: json['imagen'],
      idUserPub: json['user_id'] ?? -1,
    );
  }
}

class Comentario {
  final String usuario;
  final String texto;
  final int idUsuario;

  Comentario({
    required this.usuario,
    required this.texto,
    required this.idUsuario,
  });
}

class PerfilUsuario {
  final String nombreUsuario;
  final String fotoPerfil;
  final int numAmigos;
  final int numPublicaciones;
  final List<Publicacion> publicaciones;

  PerfilUsuario({
    required this.nombreUsuario,
    required this.fotoPerfil,
    required this.numAmigos,
    required this.numPublicaciones,
    required this.publicaciones,
  });

  factory PerfilUsuario.fromJson(Map<String, dynamic> json) {
    return PerfilUsuario(
      nombreUsuario: json['nombre_usuario'],
      fotoPerfil: '${APIConfig.baseUrl}/fotos_perfil/${json['foto_perfil']}',
      numAmigos: json['num_amigos'],
      numPublicaciones: json['num_publicaciones'],
      publicaciones:
          (json['publicaciones'] ?? [])
              .map<Publicacion>((p) => Publicacion.fromJson(p))
              .toList(),
    );
  }
}

class _GaleriaImagenes extends StatefulWidget {
  final List<String> imagenes;

  const _GaleriaImagenes({super.key, required this.imagenes});

  @override
  State<_GaleriaImagenes> createState() => _GaleriaImagenesState();
}

class _GaleriaImagenesState extends State<_GaleriaImagenes> {
  int _paginaActual = 0;

  void _cambiarImagen(int cambio) {
    setState(() {
      _paginaActual = (_paginaActual + cambio) % widget.imagenes.length;
      if (_paginaActual < 0) _paginaActual = widget.imagenes.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final imagen = widget.imagenes[_paginaActual];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _cambiarImagen(-1),
              icon: const Icon(Icons.arrow_back_ios),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.5,
                maxHeight: 300,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imagen,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, _, __) => const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _cambiarImagen(1),
              icon: const Icon(Icons.arrow_forward_ios),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.imagenes.length, (index) {
            final activo = index == _paginaActual;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: activo ? 10 : 8,
              height: activo ? 10 : 8,
              decoration: BoxDecoration(
                color: activo ? Colors.blueAccent : Colors.grey[400],
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class PerfilScreen extends StatefulWidget {
  final int usuarioId;
  final String token;

  const PerfilScreen({super.key, required this.usuarioId, required this.token});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late Future<Map<String, dynamic>> _datosPerfil;
  bool _solicitudPendiente = false;

  @override
  void initState() {
    super.initState();
    _datosPerfil = _construirDatosPerfil().then((datos) {
      _solicitudPendiente = datos['solicitudPendiente'];
      return datos;
    });
  }

  Future<Map<String, dynamic>> _construirDatosPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    final idActual = prefs.getInt('user_id');
    final token = prefs.getString('token');

    if (token == null || idActual == null) {
      throw Exception('Token o ID no disponible');
    }

    final perfil = await obtenerPerfil(token, widget.usuarioId);
    final amigo = await sonAmigos(idActual, widget.usuarioId, token);
    final pendiente = await tieneSolicitudPendiente(
      idActual,
      widget.usuarioId,
      token,
    );

    return {
      'perfil': perfil,
      'esAmigo': amigo,
      'solicitudPendiente': pendiente,
    };
  }

  Future<bool> sonAmigos(int idActual, int idPerfil, String token) async {
    if (idActual == idPerfil) return true;

    final response = await http.get(
      Uri.parse('${APIConfig.baseUrl}/son_amigos/$idActual/$idPerfil'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['son_amigos'] == true;
    } else {
      return false;
    }
  }

  Future<bool> tieneSolicitudPendiente(
    int idActual,
    int idPerfil,
    String token,
  ) async {
    if (idActual == idPerfil) return false;

    final response = await http.post(
      Uri.parse('${APIConfig.baseUrl}/buscar_usuarios'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'nombre': '', // Nombre vacio para no filtrar
        'user_id': idActual,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final usuario = data.firstWhere(
        (e) => e['id'] == idPerfil,
        orElse: () => null,
      );

      return usuario != null && usuario['estado'] == 'pendiente';
    }

    return false;
  }

  Future<PerfilUsuario?> obtenerPerfil(String token, int usuarioId) async {
    final uri =
        usuarioId == -1
            ? Uri.parse('${APIConfig.baseUrl}/perfil')
            : Uri.parse('${APIConfig.baseUrl}/perfil/$usuarioId');

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return PerfilUsuario.fromJson(json.decode(response.body));
    } else {
      print('Error al cargar perfil: ${response.body}');
      return null;
    }
  }

  void _mostrarAmigos(BuildContext context, int usuarioPerfilId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('${APIConfig.baseUrl}/amigos_de/$usuarioPerfilId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al cargar amigos')));
      return;
    }

    final data = json.decode(response.body);
    final amigos = List<Map<String, dynamic>>.from(data);

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Amigos'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Scrollbar(
                child: ListView.builder(
                  itemCount: amigos.length,
                  itemBuilder: (context, index) {
                    final amigo = amigos[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          '${amigo['foto_perfil']}',
                        ),
                      ),
                      title: Text(amigo['nombre_usuario']),
                      trailing:
                          amigo['es_amigo_comun'] == true
                              ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                              : null,
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cerrar'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  void _mostrarComentarios(BuildContext context, int publicacionId) async {
    print('Abriendo comentarios de publicacion $publicacionId');
    final TextEditingController _controller = TextEditingController();
    List<Comentario> comentarios = [];

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final uri = Uri.parse(
      '${APIConfig.baseUrl}/publicacion/$publicacionId/comentarios',
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      comentarios = List<Comentario>.from(
        data.map(
          (item) => Comentario(
            usuario: item['usuario'],
            texto: item['contenido'],
            idUsuario: item['id_usuario'],
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Comentarios",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: comentarios.length,
                  itemBuilder: (context, index) {
                    final c = comentarios[index];
                    return ListTile(
                      title: GestureDetector(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('token');

                          if (token == null) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => Scaffold(
                                    appBar: AppBar(
                                      title: const Text("Perfil"),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                    body: PerfilScreen(
                                      usuarioId: c.idUsuario,
                                      token: token,
                                    ),
                                  ),
                            ),
                          );
                        },
                        child: Text(
                          c.usuario,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      subtitle: Text(c.texto),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Escribe un comentario...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final texto = _controller.text.trim();
                        if (texto.isEmpty) return;

                        final postUri = Uri.parse(
                          '${APIConfig.baseUrl}/publicacion/$publicacionId/comentar',
                        );
                        final res = await http.post(
                          postUri,
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode({'contenido': texto}),
                        );

                        if (res.statusCode == 201) {
                          Navigator.pop(context);
                          _mostrarComentarios(context, publicacionId);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void eliminarPublicacion(int publicacionId, BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("¿Eliminar publicación?"),
            content: const Text("Esta acción no se puede deshacer."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await http.delete(
        Uri.parse('${APIConfig.baseUrl}/publicacion/$publicacionId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      Navigator.of(context).pop();
      setState(() {
        _datosPerfil = _construirDatosPerfil();
      });
    }
  }

  void abrirPublicacion(
    BuildContext context,
    int publicacionId,
    int publicacionUserId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('user_id');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  if (publicacionUserId == userId)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed:
                          () => eliminarPublicacion(publicacionId, context),
                    ),
                ],
              ),
              body: FutureBuilder<http.Response>(
                future: http.get(
                  Uri.parse('${APIConfig.baseUrl}/publicacion/$publicacionId'),
                  headers: {'Authorization': 'Bearer $token'},
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.statusCode != 200) {
                    return const Center(
                      child: Text('Error al cargar la publicación'),
                    );
                  }
                  final data = json.decode(snapshot.data!.body);
                  final imagenes =
                      List<String>.from(data['imagenes'] ?? [])
                          .map(
                            (url) => url.replaceFirst(
                              'http://localhost:5000',
                              APIConfig.baseUrl,
                            ),
                          )
                          .toList();
                  final bool tieneGps =
                      data['tiene_gps'] == 1 || data['tiene_gps'] == true;
                  bool meGusta = data['me_gusta_usuario'] == true;
                  int likes = data['me_gustas'] ?? 0;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (imagenes.isNotEmpty)
                          _GaleriaImagenes(imagenes: imagenes),

                        if (tieneGps)
                          FutureBuilder<http.Response>(
                            future: http.get(
                              Uri.parse(
                                '${APIConfig.baseUrl}/publicacion/$publicacionId/gps',
                              ),
                              headers: {'Authorization': 'Bearer $token'},
                            ),
                            builder: (context, gpsSnapshot) {
                              if (gpsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              } else if (gpsSnapshot.hasError ||
                                  !gpsSnapshot.hasData ||
                                  gpsSnapshot.data!.statusCode != 200) {
                                return const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Text('❌ Error al cargar datos GPS'),
                                );
                              }

                              final puntosGps = json.decode(
                                gpsSnapshot.data!.body,
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                child: MapaActividad(puntosGps: puntosGps),
                              );
                            },
                          ),

                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['descripcion'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 10),

                              StatefulBuilder(
                                builder: (context, setState) {
                                  return Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          final endpoint =
                                              '${APIConfig.baseUrl}/publicacion/$publicacionId/like';

                                          final response =
                                              meGusta
                                                  ? await http.delete(
                                                    Uri.parse(endpoint),
                                                    headers: {
                                                      'Authorization':
                                                          'Bearer $token',
                                                    },
                                                  )
                                                  : await http.post(
                                                    Uri.parse(endpoint),
                                                    headers: {
                                                      'Authorization':
                                                          'Bearer $token',
                                                    },
                                                  );

                                          if (response.statusCode == 200 ||
                                              response.statusCode == 201) {
                                            setState(() {
                                              meGusta = !meGusta;
                                              likes += meGusta ? 1 : -1;
                                            });
                                          }
                                        },
                                        child: Icon(
                                          meGusta
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color:
                                              meGusta
                                                  ? const Color.fromARGB(
                                                    255,
                                                    54,
                                                    200,
                                                    244,
                                                  )
                                                  : Colors.black,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        child: Text(
                                          '$likes',
                                          key: ValueKey(likes),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.comment),
                                        onPressed:
                                            () => _mostrarComentarios(
                                              context,
                                              publicacionId,
                                            ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget _construirVistaPerfil(
      PerfilUsuario perfil,
      bool esAmigo,
      BuildContext context,
      void Function(VoidCallback) setState,
    ) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(perfil.fotoPerfil),
              ),
              const SizedBox(height: 20),
              Text(
                perfil.nombreUsuario,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (esAmigo) ...[
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatBox(
                      'Amigos',
                      perfil.numAmigos,
                      onTap: () => _mostrarAmigos(context, widget.usuarioId),
                    ),
                    const SizedBox(width: 40),
                    _buildStatBox('Publicaciones', perfil.numPublicaciones),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 1),
                const SizedBox(height: 10),
                const Text(
                  'Publicaciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                perfil.publicaciones.isNotEmpty
                    ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: perfil.publicaciones.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        final pub = perfil.publicaciones[index];
                        return GestureDetector(
                          onTap:
                              () => abrirPublicacion(
                                context,
                                pub.id,
                                pub.idUserPub,
                              ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                pub.imagen != null
                                    ? Image.network(
                                      pub.imagen!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, _, __) => const Icon(
                                            Icons.image_not_supported,
                                          ),
                                    )
                                    : Container(
                                      color: const Color.fromARGB(
                                        255,
                                        183,
                                        212,
                                        228,
                                      ),
                                      child: const Icon(Icons.location_on),
                                    ),
                          ),
                        );
                      },
                    )
                    : const Text('No hay publicaciones aún 💤'),
              ] else ...[
                const SizedBox(height: 30),
                const Text(
                  '🔒 Este perfil es privado.\nSolo sus amigos pueden ver sus publicaciones.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _solicitudPendiente == true
                    ? ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.hourglass_top),
                      label: const Text('Solicitud enviada'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    )
                    : ElevatedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('token');
                        final userId = prefs.getInt('user_id');

                        if (token == null || userId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Sesión no válida'),
                            ),
                          );
                          return;
                        }

                        final response = await http.post(
                          Uri.parse('${APIConfig.baseUrl}/enviar_solicitud'),
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode({
                            'usuario_fk': userId,
                            'amigo_fk': widget.usuarioId,
                          }),
                        );

                        if (response.statusCode == 200) {
                          setState(() {
                            _solicitudPendiente = true;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${response.body}')),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Enviar solicitud de amistad'),
                    ),
              ],
            ],
          ),
        ),
      );
    }

    return FutureBuilder(
      future: _datosPerfil,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return const Center(child: Text('No se encontraron datos'));
        }

        final datos = snapshot.data as Map<String, dynamic>;
        final perfil = datos['perfil'] as PerfilUsuario;
        final esAmigo = datos['esAmigo'] as bool;
        final solicitudPendiente = datos['solicitudPendiente'] as bool;

        return _construirVistaPerfil(perfil, esAmigo, context, setState);
      },
    );
  }

  Widget _buildStatBox(String label, int value, {VoidCallback? onTap}) {
    final contenido = Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );

    return onTap == null
        ? contenido
        : GestureDetector(onTap: onTap, child: contenido);
  }
}
