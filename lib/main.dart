import 'package:eharvest_mobile/pages/login_page.dart';
import 'package:eharvest_mobile/pages/signup_page.dart';
import 'package:eharvest_mobile/pages/home_page.dart';
import 'package:eharvest_mobile/pages/splash_page.dart';
import 'package:eharvest_mobile/pages/tab_container.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eharvest_mobile/global_variables.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load SharedPreferences so platform plugins are registered early.
  await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eHarvest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(primaryColour)),
        useMaterial3: true,
      ),
      // Start with the splash page which decides where to go next.
      home: const SplashPage(),
      routes: {
        '/tabs': (context) => const TabContainer(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
