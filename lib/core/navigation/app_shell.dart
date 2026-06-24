import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Floating-dock bottom navigation: a dark rounded pill holding the main tabs
/// (the active one expands into a labelled white pill), plus a separate
/// circular accent button for the primary "New" action.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  // Tabs that live inside the dock pill.
  static const _tabs = [
    _Tab(path: '/', icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _Tab(path: '/exam', icon: Icons.event_note_outlined, activeIcon: Icons.event_note, label: 'Exam'),
    _Tab(path: '/library', icon: Icons.library_books_outlined, activeIcon: Icons.library_books, label: 'Library'),
    _Tab(path: '/profile', icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  // Primary action, rendered as the floating circular button.
  static const _createPath = '/new';

  static const _dockColor = Color(0xFF1F1B2E);
  static const _accent = Color(0xFF6B5CE7);

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
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _dockColor,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
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
              const SizedBox(width: 12),
              _CircleButton(
                active: _isActive(_createPath, location),
                onTap: () => context.go(_createPath),
              ),
            ],
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
        padding: EdgeInsets.symmetric(horizontal: active ? 14 : 8, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? tab.activeIcon : tab.icon,
              size: 23,
              color: active ? AppShell._dockColor : Colors.white70,
            ),
            // Only the active tab shows its label, like the reference. Bounded
            // + ellipsized so a long label can never overflow the dock.
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
                              color: AppShell._dockColor,
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

class _CircleButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _CircleButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppShell._accent,
          shape: BoxShape.circle,
          border: active ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: AppShell._accent.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
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
