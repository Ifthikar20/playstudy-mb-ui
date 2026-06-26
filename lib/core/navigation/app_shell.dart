import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Floating-dock bottom navigation — Airbnb-style: a single white pill holding
/// the four primary tabs. The active tab tints + shows its label; inactive
/// tabs are icon-only in muted grey.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    _Tab(path: '/', icon: Icons.home_rounded, label: 'Home'),
    _Tab(path: '/exam', icon: Icons.menu_book_rounded, label: 'Exam'),
    _Tab(path: '/library', icon: Icons.auto_stories_rounded, label: 'Library'),
    _Tab(path: '/profile', icon: Icons.person_rounded, label: 'Profile'),
  ];

  static const _accent = Color(0xFF1A1A1A);
  static const _inactive = Color(0xFF8A8A93);

  bool _isActive(String path, String location) =>
      path == '/' ? location == '/' : location.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final t in _tabs)
                  _DockItem(
                    tab: t,
                    active: _isActive(t.path, location),
                    onTap: () => context.go(t.path),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;
  const _DockItem({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: active ? 14 : 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppShell._accent.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 23,
              color: active ? AppShell._accent : AppShell._inactive,
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 92),
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppShell._accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final String label;
  const _Tab({
    required this.path,
    required this.icon,
    required this.label,
  });
}
