import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark }

abstract class ThemeEvent {}

class LoadTheme extends ThemeEvent {}

class ToggleTheme extends ThemeEvent {}

class ThemeState {
  final AppThemeMode mode;
  const ThemeState(this.mode);

  bool get isLight => mode == AppThemeMode.light;
}

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const _key = 'theme_mode';

  ThemeBloc() : super(const ThemeState(AppThemeMode.light)) {
    on<LoadTheme>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      final mode = saved == 'dark' ? AppThemeMode.dark : AppThemeMode.light;
      emit(ThemeState(mode));
    });

    on<ToggleTheme>((event, emit) async {
      final next = state.isLight ? AppThemeMode.dark : AppThemeMode.light;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, next == AppThemeMode.dark ? 'dark' : 'light');
      emit(ThemeState(next));
    });
  }
}
