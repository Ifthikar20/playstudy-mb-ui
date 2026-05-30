import 'package:flutter/material.dart';
import '../../data/models/learning_models.dart';
import '../widgets/games_grid.dart';
import '../widgets/learning_tree_view.dart';
import '../widgets/quiz_view.dart';
import '../widgets/study_flow_view.dart';

/// Result page: tabs for Study (guided section flow), Quiz, and Games.
class MaterialPage extends StatelessWidget {
  final LearningMaterial material;
  const MaterialPage({super.key, required this.material});

  void _openTree(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Learning tree')),
        body: LearningTreeView(material: material),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          titleSpacing: 0,
          title: Text(
            material.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: 'Learning tree',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.account_tree_outlined, size: 20),
              onPressed: () => _openTree(context),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(36),
            child: TabBar(
              isScrollable: false,
              labelPadding: EdgeInsets.symmetric(vertical: 6),
              tabs: [
                Tab(height: 30, text: 'Study'),
                Tab(height: 30, text: 'Quiz'),
                Tab(height: 30, text: 'Games'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            StudyFlowView(material: material),
            QuizView(questions: material.quiz, resumeKey: material.id),
            GamesGrid(material: material),
          ],
        ),
      ),
    );
  }
}
