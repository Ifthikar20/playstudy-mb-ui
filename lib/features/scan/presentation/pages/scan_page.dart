import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../games/data/models/game_models.dart';
import '../../../games/presentation/bloc/games_bloc.dart';

/// Capture a study note: camera or gallery, then pick a game type to generate.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  XFile? _file;
  GameType _selectedType = GameType.quiz;
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 85);
      if (x != null) setState(() => _file = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $source: $e')),
        );
      }
    }
  }

  void _generate() {
    if (_file == null) return;
    context.read<GamesBloc>().add(GenerateGame(
          imagePath: _file!.path,
          type: _selectedType,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GamesBloc, GamesState>(
      listener: (context, state) {
        if (state is GameGenerated) {
          context.go('/game/${state.game.id}', extra: state.game);
        } else if (state is GamesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Scan a note')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PreviewCard(file: _file),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Text('Choose a game type',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: GameType.values.map((t) {
                    final selected = t == _selectedType;
                    return ChoiceChip(
                      label: Text('${t.emoji}  ${t.label}'),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedType = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                BlocBuilder<GamesBloc, GamesState>(
                  builder: (context, state) {
                    final loading = state is GameGenerating;
                    return ElevatedButton(
                      onPressed: (_file == null || loading) ? null : _generate,
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Generate game ✨'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final XFile? file;
  const _PreviewCard({this.file});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: file == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Snap or pick a study note',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'We\'ll turn it into an interactive game so you can learn it faster.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )
            : Image.file(File(file!.path), fit: BoxFit.cover),
      ),
    );
  }
}
