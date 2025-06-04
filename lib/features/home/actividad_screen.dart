import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'api_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gpx/gpx.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class RecordingActivityPage extends StatefulWidget {
  const RecordingActivityPage({super.key});

  @override
  State<RecordingActivityPage> createState() => _RecordingActivityPageState();
}

class ResumenActividadScreen extends StatelessWidget {
  final String descripcion;
  final Duration? duracion;
  final double? distanciaKm;
  final double? caloriasEstimadas;
  final List<LatLng>? ruta;

  const ResumenActividadScreen({
    super.key,
    required this.descripcion,
    this.duracion,
    this.distanciaKm,
    this.caloriasEstimadas,
    this.ruta,
  });

  String _formatoResumen() {
    String resumen = descripcion;
    if (duracion != null) resumen += "\n⏱ Duración: ${duracion!.inMinutes} min";
    if (distanciaKm != null)
      resumen += "\n📏 Distancia: ${distanciaKm!.toStringAsFixed(2)} km";
    if (caloriasEstimadas != null)
      resumen += "\n🔥 Calorías: ${caloriasEstimadas!.toStringAsFixed(0)} kcal";
    return resumen;
  }

  @override
  Widget build(BuildContext context) {
    final tieneGPS = ruta != null && ruta!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de Actividad')),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (duracion != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timer, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text("Duración: ${duracion!.inMinutes} minutos"),
              ],
            ),
          ],
          if (distanciaKm != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.straighten, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Text("Distancia: ${distanciaKm!.toStringAsFixed(2)} km"),
              ],
            ),
          ],
          if (caloriasEstimadas != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text("Calorías: ${caloriasEstimadas!.toStringAsFixed(0)} kcal"),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (tieneGPS)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 300,
                  child: FlutterMap(
                    options: MapOptions(center: ruta!.last, zoom: 15),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c'],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: ruta!,
                            strokeWidth: 4,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text("Compartir actividad"),
            onPressed: () => Share.share(_formatoResumen()),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text("Volver"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _RecordingActivityPageState extends State<RecordingActivityPage> {
  bool _isRecording = false;
  bool _useGPS = false;
  String _selectedSport = '';
  Duration _elapsedTime = Duration.zero;
  late final Stopwatch _stopwatch;
  Timer? _timer;
  List<LatLng> _route = [];
  final Location _location = Location();
  double _totalDistance = 0.0;
  final List<Marker> _markers = [];
  int _markerCounter = 1;
  MapController _mapController = MapController();

  //MET
  double? _pesoUsuario;
  double? _customMet;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _askSportBeforeStarting();
    _cargarPesoUsuario();
  }

  Future<void> _cargarPesoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print(' Token no encontrado');
      return;
    }

    final url = Uri.parse('${APIConfig.baseUrl}/peso');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final peso = data['peso'];

        if (peso != null) {
          setState(() {
            _pesoUsuario = double.tryParse(peso.toString());
          });
        }
      } else {
        print('Error al obtener perfil: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al cargar peso desde la API: $e');
    }
  }

  double? calcularCalorias({
    required double? pesoKg,
    required double? met,
    required Duration? duracion,
  }) {
    if (pesoKg == null || met == null || duracion == null) return null;
    final minutos = duracion.inMinutes.toDouble();
    return (met * pesoKg * 3.5 / 200) * minutos;
  }

  Future<File> crearArchivoGpx(List<LatLng> ruta) async {
    final gpx = Gpx();
    final trkseg = Trkseg();

    trkseg.trkpts =
        ruta.map((latlng) {
          return Wpt(
            lat: latlng.latitude,
            lon: latlng.longitude,
            ele: 0,
            time: DateTime.now().toUtc(),
          );
        }).toList();

    final trk = Trk();
    trk.trksegs = [trkseg];
    gpx.trks = [trk];

    final gpxString = GpxWriter().asString(gpx, pretty: true);
    final dir = await getTemporaryDirectory();
    final filePath = p.join(dir.path, 'actividad.gpx');
    final file = File(filePath);
    return await file.writeAsString(gpxString);
  }

  double _getDefaultMETForSport(String deporte) {
    switch (deporte.toLowerCase()) {
      case 'correr':
        return 9.8;
      case 'bicicleta':
        return 8.0;
      case 'boxeo':
        return 9.5;
      default:
        return _customMet ?? 1.0;
    }
  }

  Future<void> _askSportBeforeStarting() async {
    String? selectedSport;
    String customSportName = '';

    String metValue = '';
    bool customNeedsGPS = false;
    bool isCustomSport = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Selecciona tu deporte'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedSport,
                      hint: const Text('Elige un deporte'),
                      items:
                          ['Correr', 'Bicicleta', 'Boxeo', 'Otro'].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          selectedSport = value;
                          isCustomSport = (value == 'Otro');
                          _customMet = double.tryParse(metValue);
                        });
                      },
                    ),
                    if (isCustomSport) ...[
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Nombre del deporte o de la publicacion',
                        ),
                        onChanged: (value) {
                          customSportName = value;
                        },
                      ),
                      if (_customMet != null)
                        Text(
                          'MET: $_customMet',
                          style: TextStyle(fontSize: 16),
                        ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'MET (Metabolic Equivalent)',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          metValue = value;
                        },
                      ),
                      Row(
                        children: [
                          const Text('¿Usa GPS?'),
                          const Spacer(),
                          Switch(
                            value: customNeedsGPS,
                            onChanged: (value) {
                              setState(() {
                                customNeedsGPS = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (selectedSport == null ||
                        (isCustomSport &&
                            (customSportName.isEmpty || metValue.isEmpty))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rellena todos los campos'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      if (isCustomSport) {
                        _selectedSport = customSportName;
                        _useGPS = customNeedsGPS;
                      } else {
                        _selectedSport = selectedSport!;
                        _useGPS =
                            (_selectedSport == 'Correr' ||
                                _selectedSport == 'Bicicleta');
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String generarDescripcion({
    required String deporte,
    required bool usaGps,
    Duration? duracion,
    double? distanciaKm,
  }) {
    final ahora = DateTime.now();
    final dia = ahora.day.toString().padLeft(2, '0');
    final mes = ahora.month.toString().padLeft(2, '0');
    final anio = ahora.year.toString();
    String descripcion = "$deporte – $dia/$mes/$anio";

    if (usaGps && duracion != null && distanciaKm != null) {
      final minutos = duracion.inMinutes;
      descripcion += " – ${minutos} min – ${distanciaKm.toStringAsFixed(2)} km";
    }

    return descripcion;
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double R = 6371; // km
    double dLat = (b.latitude - a.latitude) * pi / 180;
    double dLon = (b.longitude - a.longitude) * pi / 180;
    double lat1 = a.latitude * pi / 180;
    double lat2 = b.latitude * pi / 180;

    double aVal =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return R * c;
  }

  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _totalDistance = 0.0;
      _markerCounter = 1;
      _route.clear();
      _markers.clear();
    });

    if (_useGPS) {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      LatLng? previousPoint;
      _location.onLocationChanged.listen((loc) {
        if (!_isRecording || loc.latitude == null || loc.longitude == null)
          return;

        final currentPoint = LatLng(loc.latitude!, loc.longitude!);

        if (previousPoint != null) {
          final distance = _calculateDistance(previousPoint!, currentPoint);
          _totalDistance += distance;

          if (_totalDistance >= _markerCounter) {
            _markers.add(
              Marker(
                point: currentPoint,
                width: 30,
                height: 30,
                child: const Icon(Icons.location_on, color: Colors.red),
              ),
            );
            _markerCounter++;
          }
        }

        previousPoint = currentPoint;
        _route.add(currentPoint);
        _mapController.move(currentPoint, _mapController.zoom);
        setState(() {});
      });
    }

    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedTime = _stopwatch.elapsed;
      });
    });
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);
    _stopwatch.stop();
    _timer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token no disponible. Inicia sesión.')),
      );
      return;
    }

    final File gpxFile = await crearArchivoGpx(_route);

    final descripcion = generarDescripcion(
      deporte: _selectedSport,
      usaGps: _useGPS,
      duracion: _elapsedTime,
      distanciaKm: _totalDistance,
    );

    final uri = Uri.parse('${APIConfig.baseUrl}/crear_actividad');
    final request =
        http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['descripcion'] = descripcion;

    request.files.add(await http.MultipartFile.fromPath('gpx', gpxFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 201) {
        final peso = _pesoUsuario;
        final met = _customMet ?? _getDefaultMETForSport(_selectedSport);
        final calorias = calcularCalorias(
          pesoKg: peso,
          met: met,
          duracion: _elapsedTime,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => ResumenActividadScreen(
                  descripcion: descripcion,
                  duracion: _useGPS ? _elapsedTime : null,
                  distanciaKm: _useGPS ? _totalDistance : null,
                  caloriasEstimadas: calorias,
                ),
          ),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No autorizado. Token inválido')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error al subir actividad: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al subir la actividad')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedTime =
        "${_elapsedTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_elapsedTime.inSeconds.remainder(60).toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: Text('Grabando: $_selectedSport'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
            onPressed: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _askSportBeforeStarting();
                if (_selectedSport.isNotEmpty) {
                  _startRecording();
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_useGPS)
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center:
                      _route.isNotEmpty
                          ? _route.last
                          : LatLng(37.7749, -122.4194),
                  zoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route,
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  MarkerLayer(markers: _markers),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Text(
                  'Duración: $formattedTime',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Distancia: ${_totalDistance.toStringAsFixed(2)} km',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
