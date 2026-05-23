import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/games/data/models/game_models.dart';
import '../../features/games/presentation/pages/flashcards_play_page.dart';
import '../../features/games/presentation/pages/quiz_play_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/scan/presentation/pages/scan_page.dart';
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
            GoRoute(path: '/scan', builder: (_, __) => const ScanPage()),
            GoRoute(path: '/library', builder: (_, __) => const LibraryPage()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          ],
        ),
        GoRoute(
          path: '/game/:id',
          builder: (context, state) {
            final game = state.extra as Game?;
            if (game == null) {
              return const Scaffold(
                body: Center(child: Text('Game not found')),
              );
            }
            return game.type == GameType.flashcards
                ? FlashcardsPlayPage(game: game)
                : QuizPlayPage(game: game);
          },
        ),
      ],
    );
  }
}
