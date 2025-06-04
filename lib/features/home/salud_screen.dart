import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import './api_config.dart';

class SaludScreen extends StatefulWidget {
  const SaludScreen({super.key});

  @override
  _SaludScreenState createState() => _SaludScreenState();
}

class _SaludScreenState extends State<SaludScreen> {
  bool showForm = false;
  double caloriasDiarias = 0.0;
  Map<String, dynamic>? tmbData;
  List<dynamic> comidas = [];
  TextEditingController nombreController = TextEditingController();
  TextEditingController kcalController = TextEditingController();
  TextEditingController carbsController = TextEditingController();
  TextEditingController proteinasController = TextEditingController();
  TextEditingController grasasController = TextEditingController();
  TextEditingController gramosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTMB();
    _fetchComidas();
    _fetchCaloriasConsumidasHoy();
    _fetchHistoricoDiario();
  }

  double caloriasConsumidas = 0.0;
  List<dynamic> historicoDiario = [];

  Future<void> _fetchHistoricoDiario() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${APIConfig.baseUrl}/historico_diario'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          historicoDiario = data;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar el histórico diario')),
      );
    }
  }

  Future<void> _fetchCaloriasConsumidasHoy() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${APIConfig.baseUrl}/calorias_consumidas_hoy'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Calorías consumidas hoy: ${data['calorias_consumidas']}");
        setState(() {
          caloriasConsumidas = data['calorias_consumidas'];
        });
      } else {
        print("Error al cargar las calorías: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar las calorías consumidas')),
        );
      }
    } catch (e) {
      print("Error de conexión: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las calorías consumidas')),
      );
    }
  }

  void _clearForm() {
    nombreController.clear();
    kcalController.clear();
    carbsController.clear();
    proteinasController.clear();
    grasasController.clear();
    gramosController.clear();
  }

  Future<void> _addComida() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se encontró el token de autenticación')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${APIConfig.baseUrl}/agregar_comida'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'nombre_comida': nombreController.text,
          'kcal': double.parse(kcalController.text),
          'carbs': double.parse(carbsController.text),
          'proteinas': double.parse(proteinasController.text),
          'grasas': double.parse(grasasController.text),
          'gramos': double.parse(
            gramosController.text.isNotEmpty ? gramosController.text : '100',
          ),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comida agregada correctamente')),
        );
        _fetchComidas();
        _clearForm();
        setState(() {
          showForm = false;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al agregar la comida')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión')));
    }
  }

  Future<void> _fetchTMB() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${APIConfig.baseUrl}/tmb'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          tmbData = data;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar los datos de TMB')),
      );
    }
  }

  Future<void> _fetchComidas() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${APIConfig.baseUrl}/obtener_comidas'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          comidas = json.decode(response.body);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar las comidas')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final peso = tmbData!['peso'].toString().replaceAll(".0", "");
    final consumidoHoy = caloriasConsumidas
        .toStringAsFixed(2)
        .replaceAll(".00", "");
    final restanteHoy = (tmbData!['tmb'] - caloriasConsumidas)
        .toStringAsFixed(2)
        .replaceAll(".00", "");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Salud'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/home');
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (tmbData != null)
                Card(
                  color: Colors.blue.shade50,
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Metabolismo Basal (TMB)',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '${tmbData!['tmb'].toString()} kcal/día',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        SizedBox(height: 10),
                        Divider(),
                        SizedBox(height: 5),

                        _buildInfoRow(
                          'Consumido Hoy',
                          '${caloriasConsumidas.toStringAsFixed(2)} kcal',
                        ),

                        _buildInfoRow(
                          'Restante Hoy',
                          '${(tmbData!['tmb'] - caloriasConsumidas).toStringAsFixed(2)} kcal',
                        ),

                        SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (caloriasConsumidas / tmbData!['tmb']).clamp(
                            0.0,
                            1.0,
                          ),
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            caloriasConsumidas > tmbData!['tmb']
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Progreso Diario',
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                        Divider(),
                        SizedBox(height: 5),
                        _buildInfoRow('Peso', '$peso kg'),
                        _buildInfoRow('Altura', '${tmbData!['altura']} m'),
                        _buildInfoRow('Edad', '${tmbData!['edad']} años'),
                        _buildInfoRow(
                          'Género',
                          '${tmbData!['genero'][0].toUpperCase()}${tmbData!['genero'].substring(1)}',
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 20),
              Card(
                elevation: 3,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico Diario',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      SizedBox(height: 10),
                      historicoDiario.isEmpty
                          ? Text('No hay datos registrados')
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: historicoDiario.length,
                            itemBuilder: (context, index) {
                              final comida = historicoDiario[index];

                              final nombreComida =
                                  comida['nombre_comida'] ?? 'Sin nombre';
                              final gramos =
                                  comida['gramos']?.toString() ?? '0';
                              final kcal = comida['kcal']?.toString() ?? '0';
                              final hora = comida['hora'] ?? "--:--:--";

                              return ListTile(
                                title: Text(nombreComida),
                                subtitle: Text('$gramos g | $kcal kcal'),
                                trailing: Text(
                                  hora,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Nueva Comida'),
                onPressed: () {
                  setState(() {
                    showForm = !showForm;
                  });
                },
              ),
              if (showForm) ...[
                SizedBox(height: 10),
                _buildTextField('Nombre', nombreController, TextInputType.text),
                _buildTextField(
                  'Kcal',
                  kcalController,
                  TextInputType.numberWithOptions(decimal: true),
                ),
                _buildTextField(
                  'Carbohidratos',
                  carbsController,
                  TextInputType.numberWithOptions(decimal: true),
                ),
                _buildTextField(
                  'Proteínas',
                  proteinasController,
                  TextInputType.numberWithOptions(decimal: true),
                ),
                _buildTextField(
                  'Grasas',
                  grasasController,
                  TextInputType.numberWithOptions(decimal: true),
                ),
                _buildTextField(
                  'Gramos',
                  gramosController,
                  TextInputType.numberWithOptions(decimal: true),
                ),

                SizedBox(height: 10),
                ElevatedButton(onPressed: _addComida, child: Text('Guardar')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
