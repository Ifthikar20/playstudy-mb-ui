import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/airbnb_card.dart';
import '../../data/family_repository.dart';

/// Family screen: a student links a parent (share a code); a parent links a
/// child (enter the code) and opens their analytics. Either side can unlink.
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  FamilyRepository get _repo => context.read<FamilyRepository>();
  Future<FamilyStatus>? _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.status();
  }

  void _reload() => setState(() => _future = _repo.status());

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _showCode() async {
    try {
      final code = await _repo.issueCode();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Share this code with your parent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('They enter it on their own account to link. '
                  'It expires in 30 minutes.'),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 6),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                messenger.showSnackBar(
                    const SnackBar(content: Text('Code copied')));
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      _toast('Could not create a code. Try again.');
    }
  }

  Future<void> _enterCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Link a child'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: '6-character code',
            prefixIcon: Icon(Icons.vpn_key_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
            child: const Text('Link'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final name = await _repo.redeem(code);
      _toast('Linked to $name');
      _reload();
    } catch (e) {
      _toast(apiErrorMessage(e));
    }
  }

  Future<void> _unlink(int linkId) async {
    try {
      await _repo.unlink(linkId);
      _reload();
    } catch (_) {
      _toast('Could not unlink.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Family'),
      ),
      body: FutureBuilder<FamilyStatus>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return Center(
                child: Text('Could not load family info',
                    style: theme.textTheme.bodyMedium));
          }
          final st = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const _GuideCard(),
              const SizedBox(height: 20),

              // --- Children you follow (parent mode) ---
              _SectionLabel('Children you follow'),
              if (st.children.isEmpty)
                AirbnbCard(
                  child: Row(children: [
                    const Icon(Icons.family_restroom_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Not following anyone yet.',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ]),
                )
              else
                ...st.children.map((c) => AirbnbCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(child: Text(_initial(c.name))),
                        title: Text(c.name),
                        subtitle: Text(c.email),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Unlink',
                            icon: const Icon(Icons.link_off),
                            onPressed: () => _unlink(c.linkId),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                        onTap: () => context.push('/family/child/${c.id}',
                            extra: c.name),
                      ),
                    )),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _enterCode,
                  icon: const Icon(Icons.keyboard),
                  label: const Text("Enter my child's code"),
                ),
              ),

              const SizedBox(height: 24),

              // --- Parents who follow you (student) ---
              _SectionLabel('Parents who follow you'),
              if (st.parents.isEmpty)
                AirbnbCard(
                  child: Row(children: [
                    const Icon(Icons.visibility_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('No parent is linked yet.',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ]),
                )
              else
                ...st.parents.map((p) => AirbnbCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(child: Text(_initial(p.name))),
                        title: Text(p.name),
                        subtitle: Text(p.email),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => _unlink(p.linkId),
                        ),
                      ),
                    )),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showCode,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share my code with a parent'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _initial(String n) => n.isEmpty ? '?' : n[0].toUpperCase();
}

/// Plain-language guide so neither side is confused about who does what.
class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget role(IconData icon, String who, List<String> steps) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(who,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 4),
                child: Text('${i + 1}. ${steps[i]}',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
              ),
          ],
        );

    return AirbnbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('How linking works', style: theme.textTheme.titleLarge),
          ]),
          const SizedBox(height: 14),
          role(Icons.school_outlined, "If you're the student", [
            'Tap “Share my code” below.',
            'Read the 6-character code to your parent.',
          ]),
          const SizedBox(height: 12),
          role(Icons.family_restroom_outlined, "If you're the parent", [
            'Sign in with your own account.',
            "Ask your child for their code, then tap “Enter my child's code”.",
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A parent only sees study progress — never your password, and '
                  'they can\'t change your account.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );
}
