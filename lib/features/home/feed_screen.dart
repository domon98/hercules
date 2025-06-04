import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'perfil_screen.dart';
import 'dart:convert';
import './api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Comentario {
  final String usuario;
  final String texto;
  final int idUsuario;

  Comentario({
    required this.usuario,
    required this.texto,
    required this.idUsuario,
  });

  factory Comentario.fromJson(Map<String, dynamic> json) {
    return Comentario(
      usuario: json['usuario'],
      texto: json['comentario'],
      idUsuario: json['id_usuario'],
    );
  }
}

class Publicacion {
  final int id;
  final int idUsuario;
  final String username;
  final String foto_perfil;
  final String descripcion;
  int likes;
  bool meGustaUsuario;
  final List<String> imagenes;
  final bool tieneGps;

  Publicacion({
    required this.id,
    required this.username,
    required this.foto_perfil,
    required this.idUsuario,
    required this.descripcion,
    required this.likes,
    required this.meGustaUsuario,
    required this.imagenes,
    required this.tieneGps,
  });

  factory Publicacion.fromJson(Map<String, dynamic> json) {
    return Publicacion(
      id: json['id'],
      idUsuario: json['id_usuario'],
      username: json['nombre_usuario'],
      foto_perfil: json['foto_perfil'],
      descripcion: json['descripcion'],
      likes: json['total_likes'],
      meGustaUsuario: json['me_gusta_usuario'],
      imagenes: List<String>.from(json['imagenes']),
      tieneGps: json['tiene_gps'] == 1 || json['tiene_gps'] == true,
    );
  }
}

class MapaActividad extends StatelessWidget {
  final List<dynamic> puntosGps;

  const MapaActividad({super.key, required this.puntosGps});

  @override
  Widget build(BuildContext context) {
    if (puntosGps.isEmpty) {
      return const Text('No contiene ninguna ruta');
    }

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

    if (puntos.isEmpty) {
      return const Text('Datos GPS inválidos');
    }

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
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.green,
                  size: 30,
                ),
              ),
              Marker(
                point: puntos.last,
                width: 30,
                height: 30,
                child: const Icon(Icons.flag, color: Colors.red, size: 30),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Publicacion> publicaciones = [];
  bool cargando = true;
  int? userId;
  final Map<int, List<dynamic>> _gpsCache = {};
  final Map<int, PageController> _controllers = {};
  final Map<int, ValueNotifier<int>> _indicesPorPost = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }

    for (var notifier in _indicesPorPost.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarPublicaciones();
  }

  void _mostrarDialogoBorrar(int postId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("¿Eliminar publicación?"),
          content: const Text("Esta acción no se puede deshacer."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');

                final uri = Uri.parse(
                  '${APIConfig.baseUrl}/publicacion/$postId',
                );
                final res = await http.delete(
                  uri,
                  headers: {'Authorization': 'Bearer $token'},
                );

                if (res.statusCode == 200) {
                  setState(() {
                    publicaciones.removeWhere((p) => p.id == postId);
                  });
                } else {
                  print('Error al eliminar: ${res.statusCode}');
                }
              },
              child: const Text(
                "Eliminar",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<int?> obtenerIdPorNombre(String nombreUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.post(
      Uri.parse('${APIConfig.baseUrl}/buscar_usuario_por_nombre'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'nombre_usuario': nombreUsuario}),
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['id'];
    } else {
      return null;
    }
  }

  void _mostrarComentarios(BuildContext context, int publicacionId) async {
    print('Abriendo comentarios de publicacion: $publicacionId');
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
                                      title: Text('Perfil'),
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
                          style: const TextStyle(fontWeight: FontWeight.w500),
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

  Future<void> _darLike(Publicacion post) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final uri = Uri.parse('${APIConfig.baseUrl}/publicacion/${post.id}/like');

    try {
      final response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          post.meGustaUsuario = !post.meGustaUsuario;
          post.likes += post.meGustaUsuario ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              post.meGustaUsuario ? 'Like añadido' : 'Like eliminado',
            ),
          ),
        );
      } else {
        print('Error al dar like: ${response.statusCode}');
      }
    } catch (e) {
      print('Excepción al dar like: $e');
    }
  }

  Future<void> _cargarPublicaciones() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    userId = prefs.getInt('user_id');
    final uri = Uri.parse('${APIConfig.baseUrl}/publicaciones');

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          publicaciones = List<Publicacion>.from(
            data.map((item) => Publicacion.fromJson(item)),
          );
          cargando = false;
        });
      } else {
        setState(() {
          cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        cargando = false;
      });
    }
  }

  Future<List<dynamic>> _cargarGps(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.get(
      Uri.parse('${APIConfig.baseUrl}/publicacion/$postId/gps'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      _gpsCache[postId] = data;
      return data;
    } else {
      throw Exception('Error al cargar GPS');
    }
  }

  final Map<int, int> _paginaActual = {};
  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: publicaciones.length,
      itemBuilder: (context, index) {
        final post = publicaciones[index];
        final postId = post.id;
        _indicesPorPost.putIfAbsent(postId, () => ValueNotifier<int>(0));
        final currentIndexNotifier = _indicesPorPost[postId]!;

        return Column(
          key: PageStorageKey('publicacion_${post.id}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Usuario
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage:
                        (post.foto_perfil.isNotEmpty)
                            ? NetworkImage(
                              '${APIConfig.baseUrl}/fotos_perfil/${post.foto_perfil}',
                            )
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      print("Error al cargar la imagen: $exception");
                    },
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
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
                                  usuarioId: post.idUsuario,
                                  token: token,
                                ),
                              ),
                        ),
                      );
                    },
                    child: Text(
                      post.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  (post.idUsuario == userId)
                      ? GestureDetector(
                        onTap: () => _mostrarDialogoBorrar(post.id),
                        child: const Icon(Icons.delete, color: Colors.red),
                      )
                      : const SizedBox.shrink(),
                ],
              ),
            ),

            // Imagenes con indicador
            Column(
              children: [
                if (post.imagenes.isNotEmpty) ...[
                  ValueListenableBuilder<int>(
                    valueListenable: currentIndexNotifier,
                    builder: (context, currentIndex, _) {
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: () {
                                  final nuevoIndex =
                                      (currentIndex -
                                          1 +
                                          post.imagenes.length) %
                                      post.imagenes.length;
                                  currentIndexNotifier.value = nuevoIndex;
                                },
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.5,
                                  maxHeight: 300,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    '${APIConfig.baseUrl}/imagenes_publicaciones/${post.imagenes[currentIndex]}',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, _, __) => const Icon(
                                          Icons.image_not_supported,
                                        ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () {
                                  final nuevoIndex =
                                      (currentIndex + 1) % post.imagenes.length;
                                  currentIndexNotifier.value = nuevoIndex;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(post.imagenes.length, (
                              dotIndex,
                            ) {
                              final activo = dotIndex == currentIndex;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: activo ? 10 : 8,
                                height: activo ? 10 : 8,
                                decoration: BoxDecoration(
                                  color:
                                      activo
                                          ? Colors.blueAccent
                                          : Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ],

                if (post.tieneGps)
                  FutureBuilder<List<dynamic>>(
                    future:
                        _gpsCache.containsKey(post.id)
                            ? Future.value(_gpsCache[post.id])
                            : _cargarGps(post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (snapshot.hasError || !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text('Error al cargar datos GPS'),
                        );
                      }

                      final data = snapshot.data!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: MapaActividad(puntosGps: data),
                      );
                    },
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _darLike(post),
                    child: Icon(
                      post.meGustaUsuario
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          post.meGustaUsuario
                              ? const Color.fromARGB(255, 54, 200, 244)
                              : Colors.black,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post.likes}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _mostrarComentarios(context, post.id),
                    child: const Icon(Icons.chat_bubble_outline, size: 26),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  children: [
                    TextSpan(
                      text: '${post.username} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: post.descripcion),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}
