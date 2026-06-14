import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive stage look.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final state = AppState();
  await state.bootstrap();

  runApp(WorshipPadApp(state: state));
}

class WorshipPadApp extends StatelessWidget {
  const WorshipPadApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return MaterialApp(
            title: 'Worship Pad',
            debugShowCheckedModeBanner: false,
            theme: buildStageTheme(state.settings.accent),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
