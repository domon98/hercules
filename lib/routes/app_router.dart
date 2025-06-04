import 'package:go_router/go_router.dart';
import '../features/auth/loginhome_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/perfil_screen.dart';
import '../features/home/amigos_screen.dart';
import '../features/home/mensajes_screen.dart';
import '../features/home/config_screen.dart';
import '../features/home/chat_screen.dart';
import '../features/home/salud_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login_home',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/login_home',
      builder: (context, state) => const LoginHomeScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/amigos', builder: (context, state) => const AmigosScreen()),
    GoRoute(path: '/salud', builder: (context, state) => const SaludScreen()),
    GoRoute(
      path: '/chat/:amigoId',
      builder: (context, state) {
        final amigoId = state.pathParameters['amigoId']!;
        return ChatScreen(amigoId: int.parse(amigoId));
      },
    ),
    GoRoute(
      path: '/perfil/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final token = state.extra as String;

        return PerfilScreen(usuarioId: int.parse(id), token: token);
      },
    ),

    GoRoute(
      path: '/mensajes',
      builder: (context, state) => const MensajesScreen(),
    ),
    GoRoute(path: '/config', builder: (context, state) => const ConfigScreen()),
  ],
);
