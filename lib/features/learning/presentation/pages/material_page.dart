import 'package:flutter/material.dart';
import '../../data/models/learning_models.dart';
import '../widgets/games_grid.dart';
import '../widgets/quiz_view.dart';
import '../widgets/summary_view.dart';

/// Result page: tabs for Summary, Quiz, and Games (registered via GameRegistry).
class MaterialPage extends StatelessWidget {
  final LearningMaterial material;
  const MaterialPage({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(material.title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Summary'),
              Tab(icon: Icon(Icons.quiz_outlined), text: 'Quiz'),
              Tab(icon: Icon(Icons.videogame_asset_outlined), text: 'Games'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SummaryView(material: material),
            QuizView(questions: material.quiz),
            GamesGrid(material: material),
          ],
        ),
      ),
    );
  }
}
