import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/auth/auth_bloc.dart';
import 'core/config/app_config.dart';
import 'core/games/game_registry.dart';
import 'core/navigation/app_router.dart';
import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'core/rewards/rewards_bloc.dart';
import 'core/subscription/subscription_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/reading_bloc.dart';
import 'core/theme/theme_bloc.dart';
import 'features/exam_prep/data/repositories/exam_prep_repository.dart';
import 'features/exam_prep/presentation/bloc/exam_prep_bloc.dart';
import 'features/games/guess_the_word/guess_the_word_game.dart';
import 'features/games/super_dash/super_dash_game.dart';
import 'features/games/web/web_games.dart';
import 'features/learning/data/repositories/learning_repository.dart';
import 'features/learning/presentation/bloc/learning_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSize = 30;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  AppConfig.initialize();

  // Register all built-in games. To add a new game, write a class that
  // extends LearningGame and add one line here. The UI picks it up
  // automatically via GameRegistry — no other files need changing.
  GameRegistry.instance.register(GuessTheWordGame());
  GameRegistry.instance.register(SuperDashGame());
  GameRegistry.instance.register(FlappyWebGame());
  GameRegistry.instance.register(SpaceShooterWebGame());

  await Hive.initFlutter();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const PlayStudyApp());
}

class PlayStudyApp extends StatelessWidget {
  const PlayStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;
    final tokens = TokenStore();
    final api = ApiClient(baseUrl: config.apiBaseUrl, tokens: tokens);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: api),
        RepositoryProvider(create: (_) => LearningRepository(api)),
        RepositoryProvider(create: (_) => ExamPrepRepository(api)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeBloc()..add(LoadTheme())),
          BlocProvider(create: (_) => ReadingBloc()..add(LoadReading())),
          BlocProvider(
            create: (_) =>
                AuthBloc(api: api, tokens: tokens)..add(AuthCheckRequested()),
          ),
          BlocProvider(create: (_) => SubscriptionBloc(api: api)),
          BlocProvider(create: (_) => RewardsBloc(api: api)),
          BlocProvider(
            create: (context) =>
                LearningBloc(repository: context.read<LearningRepository>()),
          ),
          BlocProvider(
            create: (context) =>
                ExamPrepBloc(repository: context.read<ExamPrepRepository>()),
          ),
        ],
        // Build the router once with the AuthBloc so redirects work.
        // Keep it outside BlocBuilder so theme changes don't recreate it
        // (which would reset navigation state).
        child: Builder(
          builder: (context) {
            final router = AppRouter.create(context.read<AuthBloc>());
            // Hydrate per-user data whenever auth state flips to signed-in,
            // and reset it on sign-out. Centralizing this here keeps the
            // individual blocs unaware of each other.
            return BlocListener<AuthBloc, AuthState>(
              listenWhen: (prev, next) =>
                  prev.runtimeType != next.runtimeType,
              listener: (context, authState) {
                if (authState is Authenticated) {
                  context.read<SubscriptionBloc>().add(LoadSubscription());
                  context.read<RewardsBloc>().add(LoadRewards());
                  context.read<LearningBloc>().add(LoadLibrary());
                  context.read<ExamPrepBloc>().add(LoadPlans());
                }
              },
              child: BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, themeState) {
                  return BlocBuilder<ReadingBloc, ReadingState>(
                    builder: (context, reading) {
                      return MaterialApp.router(
                        title: config.appName,
                        debugShowCheckedModeBanner: false,
                        theme: AppTheme.withReading(
                            AppTheme.lightTheme, reading),
                        darkTheme: AppTheme.darkTheme,
                        themeMode: themeState.isLight
                            ? ThemeMode.light
                            : ThemeMode.dark,
                        routerConfig: router,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
