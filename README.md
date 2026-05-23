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

## Guess the Word

A flame-powered mini-game built into every study set:

- A clue is shown ("Organelle in plant cells where photosynthesis happens.")
- Tap letters to reveal the hidden word
- 6 lives per round, multiple rounds per set
- Confetti burst on a correct guess 🎉

The flame engine (`features/learning/presentation/widgets/guess_word_game.dart`) renders the animated letter tiles + celebration particles; the keyboard and controls are regular Flutter widgets above it.

## Getting started

```bash
flutter pub get
flutter run
```

Material generation is mocked in `LearningRepository.generate`. Swap that for a real `google_generative_ai` call once your API key and endpoint are wired up.
