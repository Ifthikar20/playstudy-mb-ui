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
            // Tolerate any extra type — only use it if it really is a
            // LearningMaterial with content, otherwise fall through to fetch.
            final extra = state.extra;
            final fromExtra = extra is LearningMaterial ? extra : null;
            if (fromExtra != null && fromExtra.quiz.isNotEmpty) {
              debugPrint('[router] /material/${fromExtra.id} from extra');
              return MaterialPage(material: fromExtra);
            }
            final id = state.pathParameters['id'] ?? '';
            debugPrint('[router] /material/$id fetching from repo');
            return _MaterialLoader(id: id);
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

/// Loads a study set by id with a friendly retry + back UI on failure, so
/// a transient backend error never strands the user on a dead screen.
class _MaterialLoader extends StatefulWidget {
  final String id;
  const _MaterialLoader({required this.id});

  @override
  State<_MaterialLoader> createState() => _MaterialLoaderState();
}

class _MaterialLoaderState extends State<_MaterialLoader> {
  late Future<LearningMaterial> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<LearningMaterial> _load() async {
    try {
      final repo = context.read<LearningRepository>();
      final m = await repo.fetch(widget.id);
      debugPrint('[router] /material/${widget.id} loaded "${m.title}"');
      return m;
    } catch (e, st) {
      debugPrint('[error] load material/${widget.id} failed: $e');
      debugPrint('[error] $st');
      rethrow;
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningMaterial>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              title: const Text('Study set'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text("Couldn't open this study set.",
                        textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text('${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return MaterialPage(material: snap.data!);
      },
    );
  }
}
