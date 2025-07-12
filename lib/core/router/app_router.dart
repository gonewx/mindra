import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/media/presentation/pages/media_library_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/meditation/presentation/pages/meditation_history_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/media/presentation/bloc/media_bloc.dart';
import '../../shared/widgets/animated_bottom_navigation.dart';
import '../../features/player/presentation/widgets/floating_player.dart';
import '../di/injection_container.dart';
import '../localization/app_localizations.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String mediaLibrary = '/media';
  static const String player = '/player';
  static const String meditationHistory = '/meditation-history';
  static const String settings = '/settings';

  static final GoRouter router = GoRouter(
    initialLocation: splash, // Start with splash screen
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const OnboardingPage(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider(
            create: (context) => getIt<MediaBloc>(),
            child: MainScaffold(child: child),
          );
        },
        routes: [
          GoRoute(
            path: home,
            name: 'home',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const HomePage(),
            ),
          ),
          GoRoute(
            path: mediaLibrary,
            name: 'media-library',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const MediaLibraryPage(),
            ),
          ),
          GoRoute(
            path: player,
            name: 'player',
            pageBuilder: (context, state) {
              final mediaId = state.uri.queryParameters['mediaId'];
              final timerMinutes = state.uri.queryParameters['timer'];
              return NoTransitionPage<void>(
                key: state.pageKey,
                child: PlayerPage(
                  mediaId: mediaId,
                  timerMinutes: timerMinutes != null
                      ? int.tryParse(timerMinutes)
                      : null,
                ),
              );
            },
          ),
          GoRoute(
            path: meditationHistory,
            name: 'meditation-history',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const MeditationHistoryPage(),
            ),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      final localizations = AppLocalizations.of(context)!;
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                localizations.pageNotFound,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                localizations.pageNotFoundDesc,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(home),
                child: Text(localizations.backToHome),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class MainScaffold extends StatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  static const List<String> _routes = [
    AppRouter.home,
    AppRouter.mediaLibrary,
    AppRouter.player,
    AppRouter.meditationHistory,
    AppRouter.settings,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final String location = GoRouterState.of(context).matchedLocation;
    setState(() {
      _selectedIndex = _routes.indexOf(location);
      if (_selectedIndex < 0) _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final showFloatingPlayer = currentRoute != AppRouter.player; // 在非播放页面显示浮动球
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (showFloatingPlayer) const FloatingPlayer(),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          context.go(_routes[index]);
        },
        items: [
          AnimatedBottomNavigationItem(
            icon: Icons.home, // fas fa-home (实心)
            label: localizations.home,
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.music_note, // fas fa-music (实心)
            label: localizations.mediaLibrary,
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.play_circle, // fas fa-play-circle (实心)
            label: localizations.play,
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.show_chart, // fas fa-chart-line (实心)
            label: localizations.progress,
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.person, // fas fa-user (实心)
            label: localizations.profile,
          ),
        ],
      ),
    );
  }
}
