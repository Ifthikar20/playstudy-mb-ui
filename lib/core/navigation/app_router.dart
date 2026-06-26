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
import '../../features/settings/presentation/pages/offline_page.dart';
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
        GoRoute(
          path: '/offline',
          builder: (_, __) => const OfflinePage(),
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
  LearningMaterial? _material;
  Object? _error;
  Timer? _poll;
  int _refreshAttempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<LearningRepository>();
      final m = await repo.fetch(widget.id);
      debugPrint(
          '[router] /material/${widget.id} loaded "${m.title}" (${m.status})');
      if (!mounted) return;
      setState(() {
        _material = m;
        _error = null;
      });
      _scheduleRefresh(m);
    } catch (e, st) {
      debugPrint('[error] load material/${widget.id} failed: $e');
      debugPrint('[error] $st');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  // While the set is still generating (opened early), re-fetch every couple of
  // seconds so newly-finished sections and quiz questions appear live. Stops
  // the moment the set is ready or failed.
  void _scheduleRefresh(LearningMaterial m) {
    _poll?.cancel();
    if (!m.isGenerating) {
      _refreshAttempt = 0;
      return;
    }
    // Back off as the wait grows: snappy for the first refreshes, then ease to
    // 3s so a long generation doesn't hammer the endpoint.
    final delay = _refreshAttempt < 6
        ? const Duration(milliseconds: 1500)
        : const Duration(seconds: 3);
    _refreshAttempt++;
    _poll = Timer(delay, _refresh);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final repo = context.read<LearningRepository>();
      final m = await repo.fetch(widget.id);
      if (!mounted) return;
      setState(() => _material = m);
      _scheduleRefresh(m);
    } catch (_) {
      // Transient error — keep trying while we're still on screen.
      if (mounted && _material != null) _scheduleRefresh(_material!);
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _material = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
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
                const Icon(Icons.cloud_off_rounded,
                    size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text("Couldn't open this study set.",
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final m = _material;
    if (m == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Generation failed server-side with nothing usable — show a clear message
    // instead of an empty study screen.
    if (m.status == 'failed' && m.sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
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
                const Icon(Icons.error_outline_rounded,
                    size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text("This study set couldn't be generated.",
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                const Text(
                    'The source may not have had enough readable text. '
                    'Try another file or link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        MaterialPage(material: m),
        if (m.isGenerating)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BuildingBanner(sectionCount: m.sections.length),
          ),
      ],
    );
  }
}

/// Slim "still generating" strip shown over a study set opened early, so the
/// user knows more sections are still arriving.
class _BuildingBanner extends StatelessWidget {
  final int sectionCount;
  const _BuildingBanner({required this.sectionCount});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Center(
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(24),
            color: primary,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      sectionCount > 0
                          ? 'Adding more… $sectionCount section${sectionCount == 1 ? '' : 's'} ready'
                          : 'Building your study set…',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
