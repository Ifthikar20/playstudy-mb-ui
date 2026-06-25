import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/storage/offline_store.dart';
import '../../../../core/subscription/subscription_bloc.dart';
import '../../../../core/widgets/airbnb_button.dart';
import '../../../settings/presentation/pages/offline_page.dart'
    show showOfflineFullDialog;
import '../../data/models/learning_models.dart';
import '../bloc/learning_bloc.dart';
import '../widgets/generating_overlay.dart';
import '../widgets/qr_scanner_sheet.dart';

/// Input page: paste a link OR upload a file OR paste text, then generate
/// summary + quiz + game.
class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _linkCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  PlatformFile? _file;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _linkCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _file = result.files.first);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _toast('Clipboard is empty');
      return;
    }
    _linkCtrl.text = text;
    _linkCtrl.selection =
        TextSelection.collapsed(offset: _linkCtrl.text.length);
    setState(() {});
  }

  Future<void> _scanQr() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QrScannerPage(),
      ),
    );
    if (value == null || value.isEmpty) return;
    _linkCtrl.text = value;
    _linkCtrl.selection =
        TextSelection.collapsed(offset: _linkCtrl.text.length);
    setState(() {});
  }

  void _generate() {
    final sub = context.read<SubscriptionBloc>().state;
    if (!sub.canGenerate) {
      context.push('/paywall');
      return;
    }
    final bloc = context.read<LearningBloc>();
    switch (_tab.index) {
      case 0:
        var url = _linkCtrl.text.trim();
        if (url.isEmpty) return _toast('Paste a link first');
        // iOS autofill sometimes appends a duplicate of the URL, either cleanly
        // (foo.pdf + foo.pdf) or with overlap (foo. + foo.pdf). The COMPLETE
        // URL is always the last one, so keep everything from the last scheme.
        final lower = url.toLowerCase();
        final last = [lower.lastIndexOf('http://'), lower.lastIndexOf('https://')]
            .where((i) => i > 0)
            .fold<int>(-1, (a, b) => b > a ? b : a);
        if (last > 0) url = url.substring(last);
        bloc.add(GenerateMaterial(sourceKind: SourceKind.link, sourceRef: url));
        break;
      case 1:
        if (_file == null) return _toast('Pick a file first');
        bloc.add(GenerateMaterial(
          sourceKind: SourceKind.file,
          sourceRef: _file!.path ?? _file!.name,
          titleHint: _file!.name,
        ));
        break;
      case 2:
        final text = _textCtrl.text.trim();
        if (text.length < 20) return _toast('Paste at least a paragraph of text');
        bloc.add(GenerateMaterial(sourceKind: SourceKind.text, sourceRef: text));
        break;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LearningBloc, LearningState>(
      listener: (context, state) {
        if (state is GenerateSuccess) {
          debugPrint('[input] GenerateSuccess -> push /material/${state.material.id}');
          // Usage + the creation reward are applied server-side on success —
          // re-read both rather than reporting points from the client.
          context.read<SubscriptionBloc>().add(LoadSubscription());
          context.read<RewardsBloc>().add(LoadRewards());
          context.push('/material/${state.material.id}', extra: state.material);
          // If saving this new quiz filled offline storage, tell the user so
          // they're not confused, and offer to free space.
          OfflineStore.isFull().then((full) {
            if (full && mounted) showOfflineFullDialog(context);
          });
        } else if (state is LearningError) {
          debugPrint('[input] LearningError: ${state.message}');
          _toast(state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
          ),
          title: const Text('New study set'),
          bottom: TabBar(
            controller: _tab,
            tabs: const [
              Tab(icon: Icon(Icons.link_rounded), text: 'Link'),
              Tab(icon: Icon(Icons.upload_file_rounded), text: 'Upload'),
              Tab(icon: Icon(Icons.text_snippet_rounded), text: 'Text'),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(children: [
            Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _linkTab(),
                      _uploadTab(),
                      _textTab(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: BlocBuilder<LearningBloc, LearningState>(
                    builder: (context, state) {
                      return AirbnbButton(
                        label: 'Generate learning material',
                        icon: Icons.auto_awesome_rounded,
                        loading: state is Generating,
                        onPressed: _generate,
                      );
                    },
                  ),
                ),
              ],
            ),
            // Friendly full-screen waiting UI while the backend generates.
            BlocBuilder<LearningBloc, LearningState>(
              buildWhen: (a, b) => (a is Generating) != (b is Generating),
              builder: (context, state) {
                if (state is! Generating) return const SizedBox.shrink();
                final subject = _tab.index == 0
                    ? _linkCtrl.text.trim()
                    : _tab.index == 1
                        ? (_file?.name ?? '')
                        : 'Your pasted notes';
                return Positioned.fill(
                  child: GeneratingOverlay(
                      subject: subject.isEmpty ? null : subject),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  static final _ytHost = RegExp(
      r'^https?://(?:www\.|m\.|music\.)?(?:youtube\.com|youtu\.be)/',
      caseSensitive: false);

  Widget _linkTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paste a link',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
              'Articles, blog posts, or a YouTube video. We read text or the '
              'video captions and turn them into a study set.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          TextField(
            controller: _linkCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'https://example.com/article, PDF, or YouTube link',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: _linkCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Clear',
                      onPressed: () {
                        _linkCtrl.clear();
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Quick actions — paste from clipboard or scan a QR for the URL.
          Row(children: [
            Expanded(
              child: _PillAction(
                icon: Icons.content_paste_rounded,
                label: 'Paste',
                onTap: _pasteFromClipboard,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PillAction(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan QR',
                onTap: _scanQr,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (_ytHost.hasMatch(_linkCtrl.text.trim()))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.smart_display_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'YouTube detected — we\'ll pull the video captions and '
                    'use them to build your study set.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _uploadTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Upload a file',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('PDF, text, doc, or an image of your notes.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickFile,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _file == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_upload_rounded,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 12),
                              Text('Tap to choose a file',
                                  style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('PDF, TXT, DOC, PNG, JPG',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_rounded, size: 48),
                              const SizedBox(height: 12),
                              Text(_file!.name,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('${(_file!.size / 1024).toStringAsFixed(1)} KB',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _pickFile,
                                child: const Text('Choose a different file'),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paste text',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Copy your notes here and we\'ll turn them into a study set.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Paste your study notes here...',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact pill button used for the Paste / Scan helpers under the link field.
class _PillAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: scheme.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
