import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading-accessibility preferences (dyslexia-friendly).
///
/// Warm, muted backgrounds and slightly-softened text reduce visual stress
/// for many readers — but the best choice varies per individual, so we let
/// the student pick. Applied to the light theme only (dark mode is already
/// low-contrast). See SettingsPage for the rationale shown to users.

enum ReadingBackground { white, cream, softYellow, palePeach, lightBlue }

enum ReadingTextColor { nearBlack, darkGrey, charcoal }

const _bgColors = <ReadingBackground, Color>{
  ReadingBackground.white: Color(0xFFFFFFFF),
  ReadingBackground.cream: Color(0xFFFFF8E7),
  ReadingBackground.softYellow: Color(0xFFFFFDE7),
  ReadingBackground.palePeach: Color(0xFFFFF3E0),
  ReadingBackground.lightBlue: Color(0xFFE3F2FD),
};

const _bgLabels = <ReadingBackground, String>{
  ReadingBackground.white: 'White',
  ReadingBackground.cream: 'Cream',
  ReadingBackground.softYellow: 'Soft yellow',
  ReadingBackground.palePeach: 'Pale peach',
  ReadingBackground.lightBlue: 'Light blue',
};

const _textColors = <ReadingTextColor, Color>{
  ReadingTextColor.nearBlack: Color(0xFF222222),
  ReadingTextColor.darkGrey: Color(0xFF333333),
  ReadingTextColor.charcoal: Color(0xFF2D3436),
};

const _textLabels = <ReadingTextColor, String>{
  ReadingTextColor.nearBlack: 'Near-black',
  ReadingTextColor.darkGrey: 'Dark grey',
  ReadingTextColor.charcoal: 'Charcoal',
};

extension ReadingBackgroundX on ReadingBackground {
  Color get color => _bgColors[this]!;
  String get label => _bgLabels[this]!;
}

extension ReadingTextColorX on ReadingTextColor {
  Color get color => _textColors[this]!;
  String get label => _textLabels[this]!;
}

class ReadingState {
  final ReadingBackground background;
  final ReadingTextColor textColor;
  const ReadingState({
    this.background = ReadingBackground.white,
    this.textColor = ReadingTextColor.nearBlack,
  });

  /// True when settings are at defaults — the base theme is used unchanged.
  bool get isDefault =>
      background == ReadingBackground.white &&
      textColor == ReadingTextColor.nearBlack;

  ReadingState copyWith({
    ReadingBackground? background,
    ReadingTextColor? textColor,
  }) =>
      ReadingState(
        background: background ?? this.background,
        textColor: textColor ?? this.textColor,
      );
}

abstract class ReadingEvent {}

class LoadReading extends ReadingEvent {}

class SetBackground extends ReadingEvent {
  final ReadingBackground background;
  SetBackground(this.background);
}

class SetTextColor extends ReadingEvent {
  final ReadingTextColor textColor;
  SetTextColor(this.textColor);
}

class ReadingBloc extends Bloc<ReadingEvent, ReadingState> {
  static const _bgKey = 'reading_background';
  static const _textKey = 'reading_text_color';

  ReadingBloc() : super(const ReadingState()) {
    on<LoadReading>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      emit(ReadingState(
        background: _readEnum(
            prefs.getString(_bgKey), ReadingBackground.values, ReadingBackground.white),
        textColor: _readEnum(
            prefs.getString(_textKey), ReadingTextColor.values, ReadingTextColor.nearBlack),
      ));
    });

    on<SetBackground>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bgKey, event.background.name);
      emit(state.copyWith(background: event.background));
    });

    on<SetTextColor>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_textKey, event.textColor.name);
      emit(state.copyWith(textColor: event.textColor));
    });
  }

  static T _readEnum<T extends Enum>(String? name, List<T> values, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
