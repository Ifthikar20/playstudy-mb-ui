// Hide Flutter's MaterialPage: this app defines its own MaterialPage widget
// (the learning-material screen) used by the routes below.
import 'dart:async';

import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/family/presentation/pages/child_dashboard_page.dart';
import '../../features/family/presentation/pages/family_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/exam_prep/presentation/pages/create_plan_page.dart';
import '../../features/exam_prep/presentation/pages/daily_session_page.dart';
import '../../features/exam_prep/presentation/pages/exam_prep_home_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/learning/data/models/learning_models.dart';
import '../../features/learning/data/repositories/learning_repository.dart';
import '../../features/learning/presentation/pages/input_page.dart';
import '../../features/learning/presentation/pages/material_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/rewards/presentation/pages/adventure_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/subscription/presentation/pages/paywall_page.dart';
import '../auth/auth_bloc.dart';
import '../onboarding/onboarding_bloc.dart';
import 'app_shell.dart';

class AppRouter {
  /// Builds the router. Pass [authBloc] so we can redirect based on auth
  /// state and refresh the route when the user signs in / out.
  static GoRouter create(AuthBloc authBloc, OnboardingBloc onboardingBloc) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable:
          _BlocListenable([authBloc.stream, onboardingBloc.stream]),
      redirect: (context, state) {
        final s = authBloc.state;
        // While the initial check is in-flight, don't redirect.
        if (s is AuthInitial || s is AuthLoading) return null;
        final loggedIn = s is Authenticated;
        final atLogin = state.matchedLocation == '/login';
        if (!loggedIn) return atLogin ? null : '/login';
        if (atLogin) return '/';

        // First login: show onboarding once (gated by the persisted flag).
        final ob = onboardingBloc.state;
        final atOnboarding = state.matchedLocation == '/onboarding';
        if (ob.loaded && !ob.seen) return atOnboarding ? null : '/onboarding';
        if (atOnboarding) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingPage(),
        ),
        GoRoute(
          path: '/paywall',
          builder: (_, __) => const PaywallPage(),
        ),
        GoRoute(
          path: '/family',
          builder: (_, __) => const FamilyPage(),
        ),
        GoRoute(
          path: '/family/child/:id',
          builder: (context, state) => ChildDashboardPage(
            studentId: state.pathParameters['id'] ?? '',
            studentName: (state.extra as String?) ?? 'Student',
          ),
        ),
        GoRoute(
          path: '/adventure',
          builder: (_, __) => const AdventurePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsPage(),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomePage()),
            GoRoute(path: '/new', builder: (_, __) => const InputPage()),
            GoRoute(path: '/exam', builder: (_, __) => const ExamPrepHomePage()),
            GoRoute(path: '/library', builder: (_, __) => const LibraryPage()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          ],
        ),
        GoRoute(
          path: '/exam/new',
          builder: (_, __) => const CreatePlanPage(),
        ),
        GoRoute(
          path: '/exam/:id/today',
          builder: (context, state) =>
              DailySessionPage(planId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/material/:id',
          builder: (context, state) {
            final fromExtra = state.extra as LearningMaterial?;
            // A full object (with quiz) passed via `extra` is used directly.
            // Otherwise (e.g. opened from a lightweight library row) fetch the
            // full set from the backend.
            if (fromExtra != null && fromExtra.quiz.isNotEmpty) {
              return MaterialPage(material: fromExtra);
            }
            final id = state.pathParameters['id'] ?? '';
            final repo = context.read<LearningRepository>();
            return FutureBuilder<LearningMaterial>(
              future: repo.fetch(id),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return MaterialPage(material: snapshot.data!);
                }
                if (snapshot.hasError) {
                  return const Scaffold(
                    body: Center(child: Text('Study set not found')),
                  );
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Adapts one or more bloc Streams into a Listenable for GoRouter's
/// refreshListenable, so route redirects re-run when any of them changes.
class _BlocListenable extends ChangeNotifier {
  final List<StreamSubscription> _subs = [];
  _BlocListenable(List<Stream> streams) {
    for (final s in streams) {
      _subs.add(s.listen((_) => notifyListeners()));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
