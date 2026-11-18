import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';

void main() {
  runApp(const VoiceLedgerApp());
}

class VoiceLedgerApp extends StatelessWidget {
  const VoiceLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceLedger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7C66),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: FutureBuilder<bool>(
        future: SettingsService().onboardingDone,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
        },
      ),
    );
  }
}
