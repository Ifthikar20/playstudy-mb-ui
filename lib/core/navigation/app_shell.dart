import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell wrapping the main tab routes.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    _Tab(path: '/', icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _Tab(path: '/new', icon: Icons.add_circle_outline, activeIcon: Icons.add_circle, label: 'New'),
    _Tab(path: '/exam', icon: Icons.event_note_outlined, activeIcon: Icons.event_note, label: 'Exam'),
    _Tab(path: '/library', icon: Icons.library_books_outlined, activeIcon: Icons.library_books, label: 'Library'),
    _Tab(path: '/profile', icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  int _indexFor(String location) {
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (_tabs[i].path == '/' && location == '/') return i;
      if (_tabs[i].path != '/' && location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);
    final theme = Theme.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                  theme.brightness == Brightness.dark ? 0.3 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: index,
            onTap: (i) => context.go(_tabs[i].path),
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: _tabs
                .map((t) => BottomNavigationBarItem(
                      icon: Icon(t.icon),
                      activeIcon: Icon(t.activeIcon),
                      label: t.label,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
