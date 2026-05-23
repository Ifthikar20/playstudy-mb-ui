import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/learning/data/models/learning_models.dart';
import '../../features/learning/data/repositories/learning_repository.dart';
import '../../features/learning/presentation/pages/input_page.dart';
import '../../features/learning/presentation/pages/material_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import 'app_shell.dart';

class AppRouter {
  static GoRouter create() {
    return GoRouter(
      initialLocation: '/',
      routes: [
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
            final material =
                fromExtra ?? LearningRepository().byId(state.pathParameters['id'] ?? '');
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
