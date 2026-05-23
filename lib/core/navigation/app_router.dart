import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/learning/data/models/learning_models.dart';
import '../../features/learning/data/repositories/learning_repository.dart';
import '../../features/learning/presentation/pages/input_page.dart';
import '../../features/learning/presentation/pages/material_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/subscription/presentation/pages/paywall_page.dart';
import '../auth/auth_bloc.dart';
import 'app_shell.dart';

class AppRouter {
  /// Builds the router. Pass [authBloc] so we can redirect based on auth
  /// state and refresh the route when the user signs in / out.
  static GoRouter create(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _BlocListenable(authBloc.stream),
      redirect: (context, state) {
        final s = authBloc.state;
        // While the initial check is in-flight, don't redirect.
        if (s is AuthInitial || s is AuthLoading) return null;
        final loggedIn = s is Authenticated;
        final atLogin = state.matchedLocation == '/login';
        if (!loggedIn && !atLogin) return '/login';
        if (loggedIn && atLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(
          path: '/paywall',
          builder: (_, __) => const PaywallPage(),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomePage()),
            GoRoute(path: '/new', builder: (_, __) => const InputPage()),
            GoRoute(path: '/library', builder: (_, __) => const LibraryPage()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          ],
        ),
        GoRoute(
          path: '/material/:id',
          builder: (context, state) {
            final fromExtra = state.extra as LearningMaterial?;
            final material = fromExtra ??
                LearningRepository().byId(state.pathParameters['id'] ?? '');
            if (material == null) {
              return const Scaffold(
                body: Center(child: Text('Study set not found')),
              );
            }
            return MaterialPage(material: material);
          },
        ),
      ],
    );
  }
}

/// Adapts a bloc Stream into a Listenable for GoRouter's refreshListenable.
class _BlocListenable extends ChangeNotifier {
  _BlocListenable(Stream stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final dynamic _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
