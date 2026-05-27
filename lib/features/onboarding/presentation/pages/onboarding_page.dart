import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/onboarding/onboarding_bloc.dart';
import '../../../../core/theme/app_theme.dart';

/// First-login walkthrough of how PlayStudy works. Clean white (Airbnb-style)
/// background with swipe-driven parallax animations. Shown once, then the
/// OnboardingBloc flag is set so it never appears again.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  final List<Color> gradient;
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.gradient,
  });
}

const _slides = <_Slide>[
  _Slide(
    icon: Icons.auto_awesome,
    title: 'Turn anything into a study set',
    body:
        'Paste a link, upload a PDF or notes, or drop in text. PlayStudy turns it '
        'into readable sections — without summarising away the details.',
    gradient: [Color(0xFFFF385C), Color(0xFFFF6B8A)],
  ),
  _Slide(
    icon: Icons.school_outlined,
    title: 'Study section by section',
    body:
        'Read a section, see a real-world example, then take a short quiz on it. '
        'A learning tree shows what you\'ve done and what\'s left.',
    gradient: [Color(0xFF007AFF), Color(0xFF5AC8FA)],
  ),
  _Slide(
    icon: Icons.videogame_asset_outlined,
    title: 'Learn by playing',
    body:
        'Flappy, Space Hunter, a crossword and more — every game quizzes you on '
        'your own material, so playing is studying.',
    gradient: [Color(0xFF22C55E), Color(0xFF14B8A6)],
  ),
  _Slide(
    icon: Icons.local_fire_department_outlined,
    title: 'Build a streak & climb ranks',
    body:
        'Earn points, keep your streak alive, and rise through the ranks. '
        'Exam coming up? Make a prep plan and study a little every day.',
    gradient: [Color(0xFFF59E0B), Color(0xFFFF6B35)],
  ),
];

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  void _finish() {
    context.read<OnboardingBloc>().add(CompleteOnboarding());
    context.go('/');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  double get _page =>
      _controller.hasClients && _controller.page != null
          ? _controller.page!
          : _index.toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ink = Color(0xFF222222);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF717171)),
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return AnimatedBuilder(
                    animation: Listenable.merge([_controller, _float]),
                    builder: (context, _) {
                      final delta = _page - i;
                      final t = (1 - delta.abs()).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: t,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon tile: parallax slide + gentle float + scale-in.
                              Transform.translate(
                                offset: Offset(
                                    delta * -60, -6 * _float.value),
                                child: Transform.scale(
                                  scale: 0.85 + 0.15 * t,
                                  child: Container(
                                    height: 132,
                                    width: 132,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: s.gradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(36),
                                      boxShadow: [
                                        BoxShadow(
                                          color: s.gradient.first.withOpacity(0.35),
                                          blurRadius: 30,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    child: Icon(s.icon,
                                        size: 60, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 44),
                              // Text: slides up as it fades in.
                              Transform.translate(
                                offset: Offset(0, (1 - t) * 28),
                                child: Column(
                                  children: [
                                    Text(s.title,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.displaySmall
                                            ?.copyWith(
                                                color: ink,
                                                fontWeight: FontWeight.w800,
                                                height: 1.2)),
                                    const SizedBox(height: 16),
                                    Text(s.body,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                height: 1.55,
                                                color:
                                                    const Color(0xFF717171))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: i == _index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? const Color(0xFFFF385C)
                          : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: ThemeColors.brandGradient),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF385C).withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: _next,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _isLast ? 'Get started' : 'Next',
                        key: ValueKey(_isLast),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
