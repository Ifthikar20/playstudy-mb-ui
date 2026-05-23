# PlayStudy

Turn any content into a study set. Paste a link, upload a file, or paste text — PlayStudy generates a **Summary**, a **Quiz**, and a **Guess the Word** mini-game so learning sticks.

## Stack

- Flutter (iOS + Android)
- `flutter_bloc` for state management
- `go_router` for navigation
- `hive` + `shared_preferences` for local storage
- `file_picker` for content upload
- **`flame`** game library — powers the Guess the Word mini-game
- `google_generative_ai` for AI-powered material generation (planned)

## Structure

```
lib/
├── main.dart
├── core/
│   ├── config/
│   ├── navigation/    # go_router + bottom-nav shell
│   └── theme/         # Clean white iOS-style light + dark
└── features/
    ├── home/          # Dashboard with recent study sets
    ├── learning/      # Input (link/upload/text) → Summary + Quiz + Game
    │   ├── data/
    │   │   ├── models/        # LearningMaterial, QuizQuestion, WordChallenge
    │   │   └── repositories/  # Mock generator (swap for AI later)
    │   └── presentation/
    │       ├── bloc/
    │       ├── pages/         # InputPage, MaterialPage
    │       └── widgets/       # SummaryView, QuizView, GuessWordGame (flame)
    ├── library/       # All saved study sets
    └── profile/       # Settings + dark mode
```

## Games

We use [**flame**](https://pub.dev/packages/flame), Flutter's standard 2D game
engine. Flame gives you `FlameGame` (your engine), `Component`s that update
and render each frame, input handlers, animations, and audio. Embed it in any
Flutter widget tree via `GameWidget(game: yourEngine)` — that's how Guess the
Word renders its animated letter tiles + confetti while the keyboard above is
regular Flutter widgets.

### Plug-and-play game architecture

```
lib/
├── core/games/
│   ├── learning_game.dart   # abstract contract every game implements
│   └── game_registry.dart   # holds all registered games
└── features/games/
    ├── EXAMPLE_NEW_GAME.dart.txt   # copy-paste template for new games
    └── guess_the_word/
        ├── guess_the_word_game.dart   # implements LearningGame
        └── guess_word_widget.dart     # the playable widget (uses flame)
```

The `MaterialPage`'s Games tab just asks `GameRegistry.instance.availableFor(material)`
and renders a card per result. It has zero knowledge of any specific game,
so adding a new one never requires touching the UI layer.

### Adding a new game

1. **Copy the template:** `lib/features/games/EXAMPLE_NEW_GAME.dart.txt` →
   `lib/features/games/<your_game>/<your_game>_game.dart`.
2. **Build the widget.** Plain Flutter, Flame, or anything else. The widget
   you return from `build()` receives the full `LearningMaterial` so you
   can pull whatever fields you need (`summary`, `quiz`, `wordGame`, …).
3. **Implement `LearningGame`** — set `id`, `name`, `emoji`/`icon`,
   `description`, and optionally `canPlay(material)` to gate on what the
   material contains.
4. **Register it once** in `lib/main.dart`:
   ```dart
   GameRegistry.instance.register(YourAwesomeGame());
   ```
5. **Done.** It shows up automatically on the Games tab of every study set
   where `canPlay()` returns true.

### Guess the Word (the bundled game)

- A clue is shown ("Organelle in plant cells where photosynthesis happens.")
- Tap letters to reveal the hidden word
- 6 lives per round, multiple rounds per set
- Confetti burst on a correct guess 🎉

Implemented as a flame `FlameGame` with `PositionComponent` letter tiles and a
small particle system for the celebration.

## Getting started

```bash
flutter pub get
flutter run
```

Material generation is mocked in `LearningRepository.generate`. Swap that for a real `google_generative_ai` call once your API key and endpoint are wired up.
