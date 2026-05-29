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
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
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
                _toast('Code copied');
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
      builder: (_) => AlertDialog(
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
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
      appBar: AppBar(title: const Text('Family')),
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
              Text(
                'Link a parent so they can see your learning progress, or link a '
                'child to follow theirs.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
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
                  icon: const Icon(Icons.add),
                  label: const Text('Link a child (enter their code)'),
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
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Link a parent (share a code)'),
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
