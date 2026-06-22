import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';

/// Native (no WebView) crossword built from the study set's word challenges.
/// Words are placed with simple interlocking; tap a cell to select that word,
/// type with the built-in keyboard. Completing the grid awards points.
class CrosswordNativeWidget extends StatefulWidget {
  final List<WordChallenge> words;
  const CrosswordNativeWidget({super.key, required this.words});

  @override
  State<CrosswordNativeWidget> createState() => _CrosswordNativeWidgetState();
}

class _CrosswordNativeWidgetState extends State<CrosswordNativeWidget> {
  late _Puzzle _puzzle;
  _Placed? _activeWord;
  int _activeCell = 0; // index within the active word
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _puzzle = _buildPuzzle(widget.words);
    if (_puzzle.placed.isNotEmpty) {
      _activeWord = _puzzle.placed.first;
    }
  }

  void _selectWord(_Placed w, {int cell = 0}) {
    setState(() {
      _activeWord = w;
      _activeCell = cell;
    });
  }

  void _type(String letter) {
    final w = _activeWord;
    if (w == null || _solved) return;
    setState(() {
      final cellKey = w.cellKeyAt(_activeCell);
      _puzzle.entries[cellKey] = letter;
      if (_activeCell < w.answer.length - 1) _activeCell++;
    });
    _checkSolved();
  }

  void _backspace() {
    final w = _activeWord;
    if (w == null) return;
    setState(() {
      final cellKey = w.cellKeyAt(_activeCell);
      if ((_puzzle.entries[cellKey] ?? '').isEmpty && _activeCell > 0) {
        _activeCell--;
      }
      _puzzle.entries[w.cellKeyAt(_activeCell)] = '';
    });
  }

  void _checkSolved() {
    for (final w in _puzzle.placed) {
      for (var i = 0; i < w.answer.length; i++) {
        if ((_puzzle.entries[w.cellKeyAt(i)] ?? '') !=
            w.answer[i].toUpperCase()) {
          return;
        }
      }
    }
    if (!_solved) {
      setState(() => _solved = true);
      GameScoreScope.report(context, widget.words.length);
      context.read<RewardsBloc>().add(
            const RecordActivity(points: 15, reason: 'Crossword solved'),
          );
    }
  }

  bool _wordComplete(_Placed w) {
    for (var i = 0; i < w.answer.length; i++) {
      if ((_puzzle.entries[w.cellKeyAt(i)] ?? '') !=
          w.answer[i].toUpperCase()) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_puzzle.placed.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Not enough words to build a crossword.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return Container(
      color: const Color(0xFFF4F2FB),
      child: SafeArea(
        child: Column(
          children: [
            if (_solved)
              Container(
                width: double.infinity,
                color: const Color(0xFF15803D),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Text('Solved! +15 points 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            // Grid.
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildGrid(theme),
            ),
            // Active clue.
            if (_activeWord != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Text('${_activeWord!.number}${_activeWord!.across ? "→" : "↓"}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_activeWord!.clue,
                            style: theme.textTheme.bodyMedium)),
                  ]),
                ),
              ),
            // Clue list.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                children: [
                  for (final w in _puzzle.placed)
                    ListTile(
                      dense: true,
                      onTap: () => _selectWord(w),
                      selected: _activeWord == w,
                      selectedTileColor:
                          theme.colorScheme.primary.withOpacity(0.06),
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: _wordComplete(w)
                            ? const Color(0xFF15803D)
                            : theme.colorScheme.primary.withOpacity(0.15),
                        child: _wordComplete(w)
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text('${w.number}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary)),
                      ),
                      title: Text(
                        '${w.across ? "Across" : "Down"} · ${w.clue}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            // Keyboard.
            _Keyboard(onLetter: _type, onBackspace: _backspace),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(ThemeData theme) {
    final cell = ((MediaQuery.of(context).size.width - 24) / _puzzle.cols)
        .clamp(18.0, 40.0);
    return Center(
      child: SizedBox(
        width: cell * _puzzle.cols,
        height: cell * _puzzle.rows,
        child: Stack(
          children: [
            for (var r = 0; r < _puzzle.rows; r++)
              for (var c = 0; c < _puzzle.cols; c++)
                if (_puzzle.filled.containsKey('$r,$c'))
                  Positioned(
                    left: c * cell,
                    top: r * cell,
                    width: cell,
                    height: cell,
                    child: _GridCell(
                      letter: _puzzle.entries['$r,$c'] ?? '',
                      number: _puzzle.numbers['$r,$c'],
                      active: _activeWord != null &&
                          _activeWord!.coversCell(r, c),
                      cursor: _activeWord != null &&
                          _activeWord!.cellKeyAt(_activeCell) == '$r,$c',
                      size: cell,
                      onTap: () {
                        final words = _puzzle.wordsAtCell(r, c);
                        if (words.isEmpty) return;
                        // Prefer the currently active word if it covers this
                        // cell; otherwise switch to the first word here.
                        final target = (_activeWord != null &&
                                words.contains(_activeWord))
                            ? _activeWord!
                            : words.first;
                        _selectWord(target, cell: target.cellIndex(r, c));
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final String letter;
  final int? number;
  final bool active;
  final bool cursor;
  final double size;
  final VoidCallback onTap;
  const _GridCell({
    required this.letter,
    required this.number,
    required this.active,
    required this.cursor,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: cursor
              ? primary.withOpacity(0.25)
              : active
                  ? primary.withOpacity(0.10)
                  : Colors.white,
          border: Border.all(
              color: cursor ? primary : Colors.black26,
              width: cursor ? 2 : 1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Stack(children: [
          if (number != null)
            Positioned(
              left: 1,
              top: 0,
              child: Text('$number',
                  style: TextStyle(
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54)),
            ),
          Center(
            child: Text(letter,
                style: TextStyle(
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
          ),
        ]),
      ),
    );
  }
}

class _Keyboard extends StatelessWidget {
  final ValueChanged<String> onLetter;
  final VoidCallback onBackspace;
  const _Keyboard({required this.onLetter, required this.onBackspace});

  static const _rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7E5F0),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final ch in _rows[i].split(''))
                    _Key(label: ch, onTap: () => onLetter(ch)),
                  if (i == 2)
                    _Key(
                      label: '⌫',
                      wide: true,
                      onTap: onBackspace,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final bool wide;
  final VoidCallback onTap;
  const _Key({required this.label, required this.onTap, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: wide ? 48 : 30,
            height: 42,
            alignment: Alignment.center,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

// ---- Puzzle model + builder ------------------------------------------------

class _Placed {
  final String answer; // upper-case
  final String clue;
  final int row;
  final int col;
  final bool across;
  int number = 0;
  _Placed({
    required this.answer,
    required this.clue,
    required this.row,
    required this.col,
    required this.across,
  });

  String cellKeyAt(int i) =>
      across ? '$row,${col + i}' : '${row + i},$col';

  bool coversCell(int r, int c) {
    for (var i = 0; i < answer.length; i++) {
      if (cellKeyAt(i) == '$r,$c') return true;
    }
    return false;
  }

  int cellIndex(int r, int c) {
    for (var i = 0; i < answer.length; i++) {
      if (cellKeyAt(i) == '$r,$c') return i;
    }
    return 0;
  }
}

class _Puzzle {
  final List<_Placed> placed;
  final Map<String, bool> filled; // 'r,c' -> true
  final Map<String, String> entries; // 'r,c' -> typed letter
  final Map<String, int> numbers; // 'r,c' -> clue number
  final int rows;
  final int cols;
  _Puzzle({
    required this.placed,
    required this.filled,
    required this.entries,
    required this.numbers,
    required this.rows,
    required this.cols,
  });

  List<_Placed> wordsAtCell(int r, int c) =>
      placed.where((w) => w.coversCell(r, c)).toList();
}

_Puzzle _buildPuzzle(List<WordChallenge> words) {
  // Clean + sort longest-first for better interlocking.
  final items = words
      .map((w) => MapEntry(
          w.word.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), ''), w.clue))
      .where((e) => e.key.length >= 2 && e.key.length <= 12)
      .toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));

  final placed = <_Placed>[];
  final grid = <String, String>{}; // 'r,c' -> letter

  bool canPlace(String word, int row, int col, bool across) {
    for (var i = 0; i < word.length; i++) {
      final r = across ? row : row + i;
      final c = across ? col + i : col;
      final existing = grid['$r,$c'];
      if (existing != null && existing != word[i]) return false;
    }
    return true;
  }

  void place(String word, String clue, int row, int col, bool across) {
    for (var i = 0; i < word.length; i++) {
      final r = across ? row : row + i;
      final c = across ? col + i : col;
      grid['$r,$c'] = word[i];
    }
    placed.add(_Placed(
        answer: word, clue: clue, row: row, col: col, across: across));
  }

  if (items.isEmpty) {
    return _Puzzle(
        placed: [],
        filled: {},
        entries: {},
        numbers: {},
        rows: 0,
        cols: 0);
  }

  // Place the first word horizontally near origin (offset to allow growth).
  place(items.first.key, items.first.value, 20, 20, true);

  for (var k = 1; k < items.length; k++) {
    final word = items[k].key;
    final clue = items[k].value;
    var placedIt = false;
    // Try to interlock on a shared letter with any placed cell.
    outer:
    for (var i = 0; i < word.length && !placedIt; i++) {
      for (final entry in grid.entries) {
        if (entry.value != word[i]) continue;
        final parts = entry.key.split(',');
        final gr = int.parse(parts[0]);
        final gc = int.parse(parts[1]);
        // Try placing perpendicular to whatever crosses here. Attempt both.
        // Vertical placement so this word's i-th letter lands on (gr,gc).
        final vRow = gr - i;
        if (canPlace(word, vRow, gc, false) &&
            _noAdjacentConflict(grid, word, vRow, gc, false)) {
          place(word, clue, vRow, gc, false);
          placedIt = true;
          break outer;
        }
        final hCol = gc - i;
        if (canPlace(word, gr, hCol, true) &&
            _noAdjacentConflict(grid, word, gr, hCol, true)) {
          place(word, clue, gr, hCol, true);
          placedIt = true;
          break outer;
        }
      }
    }
    if (!placedIt) {
      // Stack below everything on its own row.
      final maxR = grid.keys
          .map((k) => int.parse(k.split(',')[0]))
          .fold<int>(0, (a, b) => b > a ? b : a);
      place(word, clue, maxR + 2, 20, true);
    }
  }

  // Normalise coordinates to start at 0,0 and compute size.
  final rs = grid.keys.map((k) => int.parse(k.split(',')[0]));
  final cs = grid.keys.map((k) => int.parse(k.split(',')[1]));
  final minR = rs.reduce((a, b) => a < b ? a : b);
  final minC = cs.reduce((a, b) => a < b ? a : b);

  final filled = <String, bool>{};
  for (final key in grid.keys) {
    final p = key.split(',');
    filled['${int.parse(p[0]) - minR},${int.parse(p[1]) - minC}'] = true;
  }
  // Shift placed words.
  final shifted = placed
      .map((w) => _Placed(
          answer: w.answer,
          clue: w.clue,
          row: w.row - minR,
          col: w.col - minC,
          across: w.across))
      .toList();

  // Number the words by start cell (reading order).
  shifted.sort((a, b) {
    final ka = a.row * 1000 + a.col;
    final kb = b.row * 1000 + b.col;
    return ka.compareTo(kb);
  });
  final numbers = <String, int>{};
  var n = 1;
  for (final w in shifted) {
    final key = '${w.row},${w.col}';
    if (!numbers.containsKey(key)) {
      numbers[key] = n;
      w.number = n;
      n++;
    } else {
      w.number = numbers[key]!;
    }
  }

  final maxR = filled.keys
      .map((k) => int.parse(k.split(',')[0]))
      .fold<int>(0, (a, b) => b > a ? b : a);
  final maxC = filled.keys
      .map((k) => int.parse(k.split(',')[1]))
      .fold<int>(0, (a, b) => b > a ? b : a);

  return _Puzzle(
    placed: shifted,
    filled: filled,
    entries: {for (final k in filled.keys) k: ''},
    numbers: numbers,
    rows: maxR + 1,
    cols: maxC + 1,
  );
}

/// Reject placements that would sit a word immediately alongside a parallel
/// word (which would create accidental two-letter words). Cheap heuristic.
bool _noAdjacentConflict(
    Map<String, String> grid, String word, int row, int col, bool across) {
  for (var i = 0; i < word.length; i++) {
    final r = across ? row : row + i;
    final c = across ? col + i : col;
    // The crossing cell itself is allowed to already match.
    final isCross = grid['$r,$c'] == word[i];
    if (isCross) continue;
    // Check the two perpendicular neighbours aren't occupied (would form a
    // run). Only matters for non-crossing cells.
    if (across) {
      if (grid.containsKey('${r - 1},$c') || grid.containsKey('${r + 1},$c')) {
        return false;
      }
    } else {
      if (grid.containsKey('$r,${c - 1}') || grid.containsKey('$r,${c + 1}')) {
        return false;
      }
    }
  }
  // Also ensure the cells immediately before/after the word are empty.
  if (across) {
    if (grid.containsKey('$row,${col - 1}') ||
        grid.containsKey('$row,${col + word.length}')) return false;
  } else {
    if (grid.containsKey('${row - 1},$col') ||
        grid.containsKey('${row + word.length},$col')) return false;
  }
  return true;
}
