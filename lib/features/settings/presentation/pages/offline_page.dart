import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/offline_store.dart';
import '../../../../core/widgets/airbnb_card.dart';

/// Shows everything saved for offline play and lets the user free space.
class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  List<OfflineSet> _sets = const [];
  int _used = 0;
  int _quiz = 0;
  int _games = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await OfflineStore.sets();
    final quiz = await OfflineStore.quizBytes();
    final games = await OfflineStore.gameBytes();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _quiz = quiz;
      _games = games;
      _used = quiz + games;
      _loading = false;
    });
  }

  Future<void> _remove(OfflineSet s) async {
    await OfflineStore.removeSet(s.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all offline content?'),
        content: const Text(
            'Removes every saved quiz and downloaded game. You can re-download '
            'them anytime you\'re online.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await OfflineStore.clearAll();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = OfflineStore.limitBytes;
    final frac = (_used / limit).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Offline'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                AirbnbCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Storage used',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text('${_fmt(_used)} of ${_fmt(limit)}',
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 10,
                          backgroundColor: theme.dividerColor,
                          color: frac > 0.9
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Quizzes ${_fmt(_quiz)}  ·  Games ${_fmt(_games)}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('OFFLINE QUIZZES',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                ),
                if (_sets.isEmpty)
                  AirbnbCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 44,
                          color: theme.colorScheme.primary),
                      const SizedBox(height: 10),
                      Text('No quizzes saved offline yet',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Open a study set while online and it\'s saved here so '
                        'you can play it with no internet.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ]),
                  )
                else
                  AirbnbCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _sets.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: theme.dividerColor),
                          ListTile(
                            leading: Icon(Icons.quiz_rounded,
                                color: theme.colorScheme.primary),
                            title: Text(_sets[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(_fmt(_sets[i].bytes)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              tooltip: 'Free up',
                              onPressed: () => _remove(_sets[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _used == 0 ? null : _clearAll,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Clear all offline content'),
                ),
              ],
            ),
    );
  }

  static String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Pop-up shown when offline storage is full, so the user understands why a new
/// quiz/game couldn't be saved and can free space.
Future<void> showOfflineFullDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Offline storage full'),
      content: const Text(
        'You\'ve used all 50 MB of offline space. Free up a saved quiz or game '
        'to download more for offline play.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ctx.push('/offline');
          },
          child: const Text('Manage'),
        ),
      ],
    ),
  );
}
