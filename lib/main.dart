
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SKEsportsApp());
}

class SKEsportsApp extends StatelessWidget {
  const SKEsportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SK ESPORTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        primaryColor: const Color(0xFFFF9800),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF9800),
          secondary: Color(0xFFFF5722),
          surface: Color(0xFF1A1D2D),
        ),
      ),
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomePlaceholderScreen();
      },
    );
  }
}

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SK ESPORTS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: const Color(0xFF1A1D2D),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Color(0xFFFF9800)),
            const SizedBox(height: 16),
            const Text(
              'SK ESPORTS BGMI TOURNAMENTS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Firebase Connected Successfully!',
              style: TextStyle(color: Colors.greenAccent),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text(
                'LOGIN / REGISTER',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
