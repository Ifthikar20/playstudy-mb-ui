import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/onboarding/onboarding_bloc.dart';
import '../../../../core/theme/app_theme.dart';

/// First-login walkthrough of how PlayStudy works. Shown once, then the
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
  const _Slide({required this.icon, required this.title, required this.body});
}

const _slides = <_Slide>[
  _Slide(
    icon: Icons.auto_awesome,
    title: 'Turn anything into a study set',
    body:
        'Paste a link, upload a PDF or notes, or drop in text. PlayStudy turns it '
        'into readable sections — no summarising away the details.',
  ),
  _Slide(
    icon: Icons.school_outlined,
    title: 'Study section by section',
    body:
        'Read a section, see a real-world example, then take a short quiz on it. '
        'A learning tree shows what you\'ve done and what\'s left.',
  ),
  _Slide(
    icon: Icons.videogame_asset_outlined,
    title: 'Learn by playing',
    body:
        'Flappy, Space Hunter, a crossword and more — every game quizzes you on '
        'your own material, so playing is studying.',
  ),
  _Slide(
    icon: Icons.local_fire_department_outlined,
    title: 'Build a streak & climb ranks',
    body:
        'Earn points, keep your streak alive, and rise through ranks on your '
        'adventure. Exam coming up? Make a prep plan and study daily.',
  ),
];

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: ThemeColors.brandGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(s.icon, size: 56, color: Colors.white),
                        ),
                        const SizedBox(height: 36),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displaySmall),
                        const SizedBox(height: 14),
                        Text(s.body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7))),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: i == _index ? 22 : 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
