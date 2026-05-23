# PlayStudy

Turn your study notes into interactive games. Snap a picture of a note and PlayStudy generates a quiz, flashcards, or a matching game so learning sticks.

## Stack

- Flutter (iOS + Android)
- `flutter_bloc` for state management
- `go_router` for navigation
- `hive` + `shared_preferences` for local storage
- `image_picker` + `camera` for note capture
- `google_generative_ai` for AI-powered game generation (planned)

## Structure

```
lib/
├── main.dart
├── core/
│   ├── config/        # App-wide config
│   ├── navigation/    # go_router + bottom-nav shell
│   └── theme/         # Light/dark themes + ThemeBloc
└── features/
    ├── home/          # Home dashboard with recent games
    ├── scan/          # Capture a note, pick a game type
    ├── games/         # Game models, repo, BLoC, play pages
    ├── library/       # All generated games
    └── profile/       # User profile + settings
```

Each feature follows the same layered shape (`data/` + `presentation/`) used in `project-gf-mb`.

## Getting started

```bash
flutter pub get
flutter run
```

The game generator currently returns mocked content in `GameRepository.generateFromImage`. Swap that for a real vision-model call once the API key and endpoint are wired up.
