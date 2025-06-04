import 'package:flutter/material.dart';
import 'package:hercules/features/home/feed_screen.dart';
import './config_screen.dart';
import './amigos_screen.dart';
import './new_actividad_screen.dart';
import './perfil_screen.dart';
import './health_guard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int? _userId;
  String? _token;

  @override
  void initState() {
    super.initState();
    _obtenerUsuarioId();
  }

  Future<void> _obtenerUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('user_id');
      _token = prefs.getString('token');
    });
  }

  void _onItemTapped(int selectedIndex) {
    setState(() {
      _index = selectedIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> _pages = [
      FeedScreen(),
      ActivityStartPage(),
      AmigosScreen(),
      PerfilScreen(usuarioId: _userId!, token: _token!),
      HealthGuardScreen(),
      ConfigScreen(),
    ];

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_sharp), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_task_sharp),
            label: 'Start',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_sharp),
            label: 'Amigos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_sharp),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_sharp),
            label: 'Salud',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_sharp),
            label: 'Configuración',
          ),
        ],
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.black,
        onTap: _onItemTapped,
        currentIndex: _index,
      ),
    );
  }
}
