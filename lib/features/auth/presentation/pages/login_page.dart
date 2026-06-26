import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/auth/auth_bloc.dart';
import '../../../../core/widgets/app_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }
    context
        .read<AuthBloc>()
        .add(AuthSignInWithEmail(email: email, password: password));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = context.select<AuthBloc, bool>((b) => b.state is AuthLoading);
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message!)),
            );
          }
        },
        child: Column(
          children: [
            const _AnimatedHero(),
            Expanded(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: 1),
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 28),
                    child: child,
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  children: [
                    Text(
                      _signUp ? 'Create your account' : 'Welcome back',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _signUp
                          ? 'Start turning your material into games.'
                          : 'Pick up where you left off.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: const Color(0xFF717171)),
                    ),
                    const SizedBox(height: 26),

                    // Fastest path first: one-tap social sign-in with real logos.
                    _SocialButton(
                      label: 'Continue with Apple',
                      logo: const Icon(Icons.apple, size: 24, color: Colors.white),
                      filled: true,
                      onTap: loading
                          ? null
                          : () => context
                              .read<AuthBloc>()
                              .add(const AuthSignInWithProvider('apple')),
                    ),
                    const SizedBox(height: 12),
                    _SocialButton(
                      label: 'Continue with Google',
                      logo: SvgPicture.string(_googleLogoSvg,
                          width: 22, height: 22),
                      onTap: loading
                          ? null
                          : () => context
                              .read<AuthBloc>()
                              .add(const AuthSignInWithProvider('google')),
                    ),

                    const SizedBox(height: 22),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or use email',
                            style: theme.textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 22),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _GradientButton(
                      label: _signUp ? 'Create account' : 'Sign in',
                      loading: loading,
                      onPressed: loading ? null : _submit,
                    ),

                    const SizedBox(height: 18),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _signUp
                                ? 'Already have an account? '
                                : "New here? ",
                            style: theme.textTheme.bodyMedium,
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _signUp = !_signUp),
                            child: Text(
                              _signUp ? 'Sign in' : 'Create one',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated branded header: a gradient with continuously floating shapes, a
/// gently pulsing logo, the wordmark, and a tagline that cycles through what
/// PlayStudy does — so the screen feels alive instead of static.
class _AnimatedHero extends StatefulWidget {
  const _AnimatedHero();

  @override
  State<_AnimatedHero> createState() => _AnimatedHeroState();
}

class _AnimatedHeroState extends State<_AnimatedHero>
    with TickerProviderStateMixin {
  late final AnimationController _float;
  Timer? _rotator;
  int _tagline = 0;

  static const _taglines = [
    'Turn notes into games',
    'Quizzes, arcade & flashcards',
    'PDFs & links → playable sets',
    'Learn by playing. Beat your best.',
  ];

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _rotator = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) return;
      setState(() => _tagline = (_tagline + 1) % _taglines.length);
    });
  }

  @override
  void dispose() {
    _rotator?.cancel();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A2A2E), Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Continuously drifting soft shapes.
            _FloatingBlob(_float, size: 150, opacity: 0.12, base: const Offset(250, 10), phase: 0.0, amp: 18),
            _FloatingBlob(_float, size: 170, opacity: 0.10, base: const Offset(-40, 190), phase: 1.6, amp: 22),
            _FloatingBlob(_float, size: 46, opacity: 0.16, base: const Offset(40, 70), phase: 3.0, amp: 14),
            _FloatingBlob(_float, size: 28, opacity: 0.18, base: const Offset(300, 150), phase: 4.2, amp: 12),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pulsing logo.
                    AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) {
                        final pulse =
                            0.5 + 0.5 * math.sin(_float.value * 2 * math.pi);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.10 + 0.18 * pulse),
                                blurRadius: 18 + 14 * pulse,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: const AppLogo(size: 52, radius: 14),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'PlayStudy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Cycling tagline with a fade + slide transition.
                    SizedBox(
                      height: 24,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _taglines[_tagline],
                          key: ValueKey(_tagline),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBlob extends StatelessWidget {
  final Animation<double> animation;
  final double size;
  final double opacity;
  final Offset base;
  final double phase;
  final double amp;
  const _FloatingBlob(
    this.animation, {
    required this.size,
    required this.opacity,
    required this.base,
    required this.phase,
    required this.amp,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final a = animation.value * 2 * math.pi + phase;
        return Positioned(
          left: base.dx + math.cos(a) * amp,
          top: base.dy + math.sin(a) * amp,
          child: child!,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _GradientButton(
      {required this.label, required this.loading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget logo;
  final bool filled;
  final VoidCallback? onTap;
  const _SocialButton({
    required this.label,
    required this.logo,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        logo,
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF222222),
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: child,
            ),
    );
  }
}

/// The official multi-colour Google "G" mark, inlined so no asset is needed.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';
