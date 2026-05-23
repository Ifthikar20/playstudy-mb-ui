import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_config.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_bloc.dart';
import 'features/games/data/repositories/game_repository.dart';
import 'features/games/presentation/bloc/games_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSize = 30;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  AppConfig.initialize();

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
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => GameRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeBloc()..add(LoadTheme())),
          BlocProvider(
            create: (context) => GamesBloc(
              repository: context.read<GameRepository>(),
            )..add(LoadLibrary()),
          ),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp.router(
              title: config.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeState.isLight ? ThemeMode.light : ThemeMode.dark,
              routerConfig: AppRouter.create(),
            );
          },
        ),
      ),
    );
  }
}
