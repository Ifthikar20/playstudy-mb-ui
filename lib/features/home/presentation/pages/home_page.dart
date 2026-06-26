import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/auth/auth_bloc.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../exam_prep/data/models/exam_plan.dart';
import '../../../exam_prep/presentation/bloc/exam_prep_bloc.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';
import '../widgets/achievement_overlay.dart';
import '../widgets/games_strip.dart';
import '../widgets/study_activity_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _key = 'last_seen_points';
  int _lastSeen = -1;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _checkReturnReward();
  }

  // On returning to the dashboard, if points went up while we were away,
  // celebrate the achievement (and a level-up if the rank changed).
  Future<void> _checkReturnReward() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeen = prefs.getInt(_key) ?? -1;
    if (!mounted) return;
    final st = context.read<RewardsBloc>().state;
    if (_lastSeen >= 0 && st.points > _lastSeen) {
      final rankedUp = _rankIndexFor(_lastSeen) < st.currentRankIndex;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _celebrate(st.points - _lastSeen, st, rankedUp));
    }
    await prefs.setInt(_key, st.points);
  }

  int _rankIndexFor(int points) {
    var idx = 0;
    for (var i = 0; i < kRanks.length; i++) {
      if (points >= kRanks[i].threshold) idx = i;
    }
    return idx;
  }

  Future<void> _celebrate(int delta, RewardsState st, bool rankedUp) async {
    if (_celebrating || !mounted) return;
    _celebrating = true;
    await showAchievement(context, delta: delta, state: st, rankedUp: rankedUp);
    _celebrating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Catch rewards earned while the dashboard is already visible too.
        child: BlocListener<RewardsBloc, RewardsState>(
          listenWhen: (prev, next) => next.points > prev.points,
          listener: (context, st) {
            final rankedUp = _rankIndexFor(_lastSeen) < st.currentRankIndex;
            final delta = _lastSeen >= 0 ? st.points - _lastSeen : st.lastAward;
            _lastSeen = st.points;
            SharedPreferences.getInstance()
                .then((p) => p.setInt(_key, st.points));
            if (delta > 0) _celebrate(delta, st, rankedUp);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _Greeting(),
              const SizedBox(height: 20),
              const StudyActivityChart(),
              const SizedBox(height: 18),
              GamesStrip(onTapAny: () => context.go('/new')),
              const SizedBox(height: 18),
              _HeroCta(onTap: () => context.go('/new')),
              const SizedBox(height: 20),
              BlocBuilder<ExamPrepBloc, ExamPrepState>(
                builder: (context, state) {
                  final today = state.plans.where((p) => p.isToday).toList();
                  if (today.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _TodayPrepStrip(plan: today.first),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is Authenticated ? state.user.name : 'there';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${_first(name)}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('What do you want to learn today?',
                style: theme.textTheme.displaySmall),
          ],
        );
      },
    );
  }

  String _first(String n) {
    final parts = n.split(RegExp(r'[ @]'));
    return parts.first;
  }
}

class _HeroCta extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.secondary],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create a study set',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    )),
                SizedBox(height: 3),
                Text('Paste a link, PDF or notes — we turn it into a quiz + game.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.25,
                    )),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ),
        ]),
      ),
    );
  }
}

class _TodayPrepStrip extends StatelessWidget {
  final ExamPlan plan;
  const _TodayPrepStrip({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = plan.resultFor(DateTime.now())?.completed ?? false;
    return AirbnbCard(
      onTap: () => context.push('/exam/${plan.id}/today'),
      child: Row(children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.event_available_rounded,
              color: theme.colorScheme.tertiary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                done
                    ? "Today's session done"
                    : '${plan.questionsPerDay} questions for ${plan.examTitle}',
                style: theme.textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('${plan.daysUntilExam}d to exam',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AirbnbCard(
      padding: const EdgeInsets.all(28),
      onTap: onTap,
      child: Column(children: [
        Icon(Icons.menu_book_rounded,
            size: 44, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text('No study sets yet',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Tap to create your first one.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

/// Airbnb listing-style card for a study set: gradient header on top, body
/// with bold title + meta row, save icon in the corner.
class StudySetCard extends StatelessWidget {
  final LearningMaterial material;
  final VoidCallback onTap;
  const StudySetCard({super.key, required this.material, required this.onTap});

  IconData get _icon {
    switch (material.sourceKind) {
      case SourceKind.link:
        return Icons.link_rounded;
      case SourceKind.file:
        return Icons.description_rounded;
      case SourceKind.text:
        return Icons.text_snippet_rounded;
    }
  }

  String get _sourceLabel {
    switch (material.sourceKind) {
      case SourceKind.link:
        return 'Web link';
      case SourceKind.file:
        return 'Uploaded file';
      case SourceKind.text:
        return 'Pasted notes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? theme.colorScheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(children: [
                GradientHeader(seed: material.title, icon: _icon, height: 72),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.favorite_border,
                        color: Colors.white, size: 16),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_icon, size: 11, color: theme.colorScheme.primary),
                      const SizedBox(width: 3),
                      Text(_sourceLabel,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      material.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _MetaChip(
                          icon: Icons.menu_book_rounded,
                          label: '${material.keyPoints.length} pts'),
                      const SizedBox(width: 6),
                      _MetaChip(
                          icon: Icons.quiz_rounded,
                          label: '${material.quiz.length} quiz'),
                      const SizedBox(width: 6),
                      _MetaChip(
                          icon: Icons.videogame_asset_rounded,
                          label: '${material.wordGame.length} words'),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 3),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 11)),
      ]),
    );
  }
}
