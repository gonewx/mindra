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
import '../di/injection_container.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String mediaLibrary = '/media';
  static const String player = '/player';
  static const String meditationHistory = '/meditation-history';
  static const String settings = '/settings';

  static final GoRouter router = GoRouter(
    initialLocation: home, // Start directly at home instead of splash
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
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
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: mediaLibrary,
            name: 'media-library',
            builder: (context, state) => const MediaLibraryPage(),
          ),
          GoRoute(
            path: player,
            name: 'player',
            builder: (context, state) {
              final mediaId = state.uri.queryParameters['mediaId'];
              return PlayerPage(mediaId: mediaId);
            },
          ),
          GoRoute(
            path: meditationHistory,
            name: 'meditation-history',
            builder: (context, state) => const MeditationHistoryPage(),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text('页面不存在', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('请检查链接或返回首页', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(home),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
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
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: AnimatedBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          context.go(_routes[index]);
        },
        items: const [
          AnimatedBottomNavigationItem(
            icon: Icons.home, // fas fa-home (实心)
            label: '首页',
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.music_note, // fas fa-music (实心)
            label: '素材库',
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.play_circle, // fas fa-play-circle (实心)
            label: '播放',
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.show_chart, // fas fa-chart-line (实心)
            label: '进度',
          ),
          AnimatedBottomNavigationItem(
            icon: Icons.person, // fas fa-user (实心)
            label: '我的',
          ),
        ],
      ),
    );
  }
}
