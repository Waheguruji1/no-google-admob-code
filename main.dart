import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_onboarding.dart';
import 'main_page.dart';

// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// Provider for the user name
final userNameProvider = StateProvider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('user_name');
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    return MaterialApp(
      title: 'My Story App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: userName == null ? '/onboarding' : '/main',
      routes: {
        '/onboarding': (context) => UserOnboardingPage(),
        '/main': (context) => MainPage(),
      },
    );
  }
}
