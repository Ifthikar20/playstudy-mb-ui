import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/learning_models.dart';
import '../bloc/learning_bloc.dart';

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

  void _generate() {
    final bloc = context.read<LearningBloc>();
    switch (_tab.index) {
      case 0:
        final url = _linkCtrl.text.trim();
        if (url.isEmpty) return _toast('Paste a link first');
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
          context.go('/material/${state.material.id}', extra: state.material);
        } else if (state is LearningError) {
          _toast(state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New study set'),
          bottom: TabBar(
            controller: _tab,
            tabs: const [
              Tab(icon: Icon(Icons.link), text: 'Link'),
              Tab(icon: Icon(Icons.upload_file_outlined), text: 'Upload'),
              Tab(icon: Icon(Icons.text_snippet_outlined), text: 'Text'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
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
                    final loading = state is Generating;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : _generate,
                        child: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Generate learning material'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paste a link',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Articles, blog posts, or any URL with content to learn from.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          TextField(
            controller: _linkCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://example.com/article',
              prefixIcon: Icon(Icons.link),
            ),
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
                              Icon(Icons.cloud_upload_outlined,
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
                              const Icon(Icons.description_outlined, size: 48),
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
