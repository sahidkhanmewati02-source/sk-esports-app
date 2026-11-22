import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
        primaryColor: const Color(0xFFFFB300),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB300),
          secondary: Color(0xFFFF6F00),
          surface: Color(0xFF161A23),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161A23),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ==========================================
// 1. AUTH GATE (Auto Login Check)
// ==========================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFFB300))),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

// ==========================================
// 2. LOGIN / SIGNUP / FORGOT PASSWORD SCREEN
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _bgmiIgnCtrl = TextEditingController();
  final _bgmiIdCtrl = TextEditingController();

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _submitAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMsg('Email aur Password zaroori hai!', isError: true);
      return;
    }

    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final name = _nameCtrl.text.trim();
        final ign = _bgmiIgnCtrl.text.trim();
        final bgmiId = _bgmiIdCtrl.text.trim();

        if (name.isEmpty || ign.isEmpty || bgmiId.isEmpty) {
          _showMsg('Saari BGMI details bharein!', isError: true);
          setState(() => isLoading = false);
          return;
        }

        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await FirebaseDatabase.instance.ref('users/${cred.user!.uid}').set({
          'name': name,
          'email': email,
          'bgmiIgn': ign,
          'bgmiId': bgmiId,
          'walletBalance': 0,
          'totalKills': 0,
          'createdAt': ServerValue.timestamp,
        });
      }
    } on FirebaseAuthException catch (e) {
      _showMsg(e.message ?? 'Authentication Error', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showMsg('Password reset ke liye pehle apna Email likhein', isError: true);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMsg('Password reset link aapke email par bhej diya gaya hai!');
    } catch (e) {
      _showMsg('Email bhejne mein error aaya', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, size: 72, color: Color(0xFFFFB300)),
                const SizedBox(height: 12),
                const Text(
                  'SK ESPORTS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFFFFB300),
                  ),
                ),
                const Text(
                  'Official BGMI Tournament Platform',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                if (!isLogin) ...[
                  _buildInput(_nameCtrl, 'Full Name', Icons.person),
                  const SizedBox(height: 12),
                  _buildInput(_bgmiIgnCtrl, 'BGMI In-Game Name (IGN)', Icons.sports_esports),
                  const SizedBox(height: 12),
                  _buildInput(_bgmiIdCtrl, 'BGMI Character ID (Level 40+)', Icons.badge, isNumber: true),
                  const SizedBox(height: 12),
                ],
                _buildInput(_emailCtrl, 'Email Address', Icons.email),
                const SizedBox(height: 12),
                _buildInput(_passCtrl, 'Password', Icons.lock, isPass: true),
                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFFFB300))),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isLoading ? null : _submitAuth,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            isLogin ? 'LOGIN' : 'CREATE ACCOUNT',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? "Naya account banana hai? Sign Up karein"
                        : "Pehle se account hai? Login karein",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon,
      {bool isPass = false, bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFFFFB300)),
        filled: true,
        fillColor: const Color(0xFF161A23),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ==========================================
// 3. MAIN HOME SCREEN (Matches, Wallet, Profile)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MatchesTab(),
    WalletTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SK ESPORTS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB300)),
        ),
        actions: [
          StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('users/${FirebaseAuth.instance.currentUser!.uid}/walletBalance')
                .onValue,
            builder: (context, snap) {
              final bal = snap.data?.snapshot.value ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFB300)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFFFFB300)),
                    const SizedBox(width: 6),
                    Text('₹$bal', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB300))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF161A23),
        selectedItemColor: const Color(0xFFFFB300),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports_esports), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet & UTR'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ==========================================
// 4. MATCHES & TOURNAMENT SLOTS TAB
// ==========================================
class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  Future<void> _joinMatch(BuildContext context, String matchId, Map<dynamic, dynamic> matchData) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseDatabase.instance.ref('users/$uid');
    final matchRef = FirebaseDatabase.instance.ref('matches/$matchId');

    final userSnap = await userRef.get();
    final userData = userSnap.value as Map<dynamic, dynamic>? ?? {};
    final int wallet = (userData['walletBalance'] ?? 0) as int;
    final int entryFee = (matchData['entryFee'] ?? 30) as int;
    final int maxSlots = (matchData['maxSlots'] ?? 100) as int;
    final Map<dynamic, dynamic> joinedPlayers = (matchData['joinedPlayers'] as Map<dynamic, dynamic>?) ?? {};

    if (joinedPlayers.containsKey(uid)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aap is match mein pehle se join hain!')),
        );
      }
      return;
    }

    if (joinedPlayers.length >= maxSlots) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match ke saare slots full ho chuke hain!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (wallet < entryFee) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet mein balance kam hai! Pehle Wallet tab se UTR add karein.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Deduct Entry Fee & Book Slot
    await userRef.update({'walletBalance': wallet - entryFee});
    await matchRef.child('joinedPlayers/$uid').set({
      'bgmiIgn': userData['bgmiIgn'] ?? 'Player',
      'bgmiId': userData['bgmiId'] ?? '',
      'joinedAt': ServerValue.timestamp,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot Book Ho Gaya! Room ID match se 15 min pehle dikhega.'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('matches').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB300)));
        }

        final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

        if (data == null || data.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text(
                    'Abhi koi live match scheduled nahi hai',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Firebase Realtime Database mein "matches" node ke andar match add karein.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: Colors.black),
                    onPressed: () async {
                      // Demo match create karne ka quick button (Testing ke liye)
                      await FirebaseDatabase.instance.ref('matches').push().set({
                        'title': 'SK ESPORTS Solo Classic #1',
                        'map': 'Erangel',
                        'type': 'Solo',
                        'time': 'Today, 8:00 PM',
                        'entryFee': 30,
                        'perKill': 20,
                        'booyahPrize': 175,
                        'maxSlots': 100,
                        'roomId': 'Waiting (15 min before match)',
                        'roomPass': 'Waiting',
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Sample Erangel Match'),
                  ),
                ],
              ),
            ),
          );
        }

        final matchEntries = data.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: matchEntries.length,
          itemBuilder: (context, index) {
            final matchId = matchEntries[index].key.toString();
            final m = matchEntries[index].value as Map<dynamic, dynamic>;

            final String title = m['title'] ?? 'BGMI Match';
            final String mapName = m['map'] ?? 'Erangel';
            final String type = m['type'] ?? 'Solo';
            final String time = m['time'] ?? 'Soon';
            final int entryFee = (m['entryFee'] ?? 30) as int;
            final int perKill = (m['perKill'] ?? 20) as int;
            final int booyah = (m['booyahPrize'] ?? 175) as int;
            final int maxSlots = (m['maxSlots'] ?? (mapName.toLowerCase() == 'livik' ? 52 : 100)) as int;
            final Map<dynamic, dynamic> joined = (m['joinedPlayers'] as Map<dynamic, dynamic>?) ?? {};
            final bool isJoined = joined.containsKey(uid);

            return Card(
              color: const Color(0xFF161A23),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$mapName • $type',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('⏰ Time: $time', style: const TextStyle(color: Colors.white70)),
                    const Divider(height: 24, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _prizeCol('Chicken Dinner', '₹$booyah'),
                        _prizeCol('Per Kill', '₹$perKill'),
                        _prizeCol('Entry Fee', '₹$entryFee'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: (joined.length / maxSlots).clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      color: const Color(0xFFFFB300),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Slots: ${joined.length} / $maxSlots', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('${maxSlots - joined.length} Left', style: const TextStyle(fontSize: 12, color: Color(0xFFFFB300))),
                      ],
                    ),
                    if (isJoined) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infin
