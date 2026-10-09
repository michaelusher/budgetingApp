import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/theme/app_theme.dart';
import 'package:budget_buddy/screens/onboarding_screen.dart';
import 'package:budget_buddy/screens/main_shell.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppState appState = AppState();

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Budget Buddy',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appState.themeMode,
          scrollBehavior: const _AppScrollBehavior(),
          home: _AppRoot(appState: appState),
        );
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _AppRoot extends StatelessWidget {
  final AppState appState;
  const _AppRoot({required this.appState});

  @override
  Widget build(BuildContext context) {
    if (!appState.isLoaded) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    if (!appState.isOnboarded) {
      return OnboardingScreen(appState: appState);
    }
    return MainShell(appState: appState);
  }
}
