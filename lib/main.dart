

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SkEsportsApp());
}

class SkEsportsApp extends StatelessWidget {
  const SkEsportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SK ESPORTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFFFF6B00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B00),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF161B22),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MainDashboard();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

// ==================== 1. AUTH SCREEN (LOGIN / SIGNUP / RESET) ====================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool isLogin = true;
  bool loading = false;

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _msg("Email aur Password dono bharein");
      return;
    }
    setState(() => loading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        await FirebaseDatabase.instance.ref('users/${cred.user!.uid}').set({
          'name': _nameCtrl.text.trim().isEmpty ? 'Player' : _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'wallet': 0,
          'kills': 0,
          'winnings': 0,
        });
      }
    } on FirebaseAuthException catch (e) {
      _msg(e.message ?? "Auth Error");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      _msg("Password reset ke liye pehle Email likhein");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      _msg("Password reset link aapke email par bhej diya gaya hai!");
    } catch (e) {
      _msg("Reset email bhejne mein dikkat aayi");
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_esports, size: 72, color: Color(0xFFFF6B00)),
              const SizedBox(height: 12),
              const Text(
                "SK ESPORTS",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const Text("BGMI Custom Tournaments", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              if (!isLogin)
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "In-Game Name (IGN)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              if (!isLogin) const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text("Forgot Password?"),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isLogin ? "LOGIN" : "CREATE ACCOUNT",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? "Naya account banayein? Sign Up" : "Pehle se account hai? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 2. MAIN DASHBOARD ====================
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _index = 0;
  final List<Widget> _pages = const [
    MatchesTab(),
    WalletTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SK ESPORTS", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: const Color(0xFFFF6B00),
        backgroundColor: const Color(0xFF161B22),
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: "Matches"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// ==================== 3. MATCHES TAB (LIVIK 52 / CLASSIC 100) ====================
class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final matchesRef = FirebaseDatabase.instance.ref('matches');

    return StreamBuilder<DatabaseEvent>(
      stream: matchesRef.onValue,
      builder: (context, snapshot) {
        List> matchList = [
          {
            'id': 'match_erangel_1',
            'title': 'SK Daily Classic #1',
            'map': 'Erangel',
            'type': 'Squad',
            'entryFee': 30,
            'perKill': 20,
            'booyah': 175,
            'maxSlots': 100,
            'joined': 42,
            'time': 'Today, 8:00 PM',
            'roomId': 'Joining ke baad dikhega',
          },
          {
            'id': 'match_livik_1',
            'title': 'SK Rush Livik #2',
            'map': 'Livik',
            'type': 'Solo',
            'entryFee': 30,
            'perKill': 20,
            'booyah': 175,
            'maxSlots': 52,
            'joined': 38,
            'time': 'Today, 9:30 PM',
            'roomId': 'Joining ke baad dikhega',
          },
        ];

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final raw = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
          matchList = raw.entries.map((e) {
            final m = Map<String, dynamic>.from(e.value as Map);
            m['id'] = e.key;
            return m;
          }).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: matchList.length,
          itemBuilder: (context, i) {
            final m = matchList[i];
            final int maxSlots = m['maxSlots'] ?? (m['map'] == 'Livik' ? 52 : 100);
            final int joined = m['joined'] ?? 0;
            final bool isFull = joined >= maxSlots;

            return Card(
              color: const Color(0xFF161B22),
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          m['title'] ?? 'BGMI Match',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Chip(
                          label: Text("${m['map']} • ${m['type']}"),
                          backgroundColor: const Color(0xFFFF6B00).withOpacity(0.2),
                        ),
                      ],
                    ),
                    Text("Time: ${m['time']}", style: const TextStyle(color: Colors.grey)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCol("ENTRY FEE", "₹${m['entryFee']}"),
                        _statCol("PER KILL", "₹${m['perKill']}"),
                        _statCol("CHICKEN DINNER", "₹${m['booyah']}"),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: (joined / maxSlots).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[800],
                      color: isFull ? Colors.red : const Color(0xFF00E676),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Slots: $joined / $maxSlots", style: const TextStyle(fontSize: 13)),
                        Text(
                          isFull ? "FULL" : "${maxSlots - joined} Left",
                          style: TextStyle(
                            color: isFull ? Colors.red : const Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFull ? Colors.grey : const Color(0xFFFF6B00),
                        ),
                        onPressed: isFull ? null : () => _showJoinDialog(context, m),
                        child: Text(
                          isFull ? "SLOTS FULL" : "JOIN MATCH (₹${m['entryFee']})",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
      ],
    );
  }

  void _showJoinDialog(BuildContext context, Map<String, dynamic> match) {
    final bgmiIdCtrl = TextEditingController();
    final ignCtrl = TextEditingController();
    final levelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text("Join ${match['title']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Rule: BGMI ID Level 30+ hona zaroori hai. No hacks/emulators.",
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ignCtrl,
              decoration: const InputDecoration(labelText: "BGMI Character Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bgmiIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "BGMI Character ID (10 digits)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: levelCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "BGMI Account Level (Min 30)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
            onPressed: () async {
              final lvl = int.tryParse(levelCtrl.text.trim()) ?? 0;
              if (bgmiIdCtrl.text.trim().isEmpty || ignCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("BGMI Name aur ID dono bharein")),
                );
                return;
              }
              if (lvl < 30) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Minimum Level 30+ required hai!")),
                );
                return;
              }

              final uid = FirebaseAuth.instance.currentUser!.uid;

final alreadyJoined = await FirebaseDatabase.instance
    .ref('registrations/${match['id']}/$uid')
    .get();
if (alreadyJoined.exists) {
  if (ctx.mounted) Navigator.pop(ctx);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aap pehle hi is match mein join kar chuke hain!")),
    );
  }
  return;
}

final userRef = FirebaseDatabase.instance.ref('users/$uid');
final usersSnap = await userRef.get();
final int wallet = (usersSnap.child('wallet').value as num?)?.toInt() ?? 0;
                  
              final int fee = match['entryFee'] ?? 30;

              if (wallet < fee) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Wallet balance kam hai! Pehle UTR se deposit karein.")),
                  );
                }
                return;
              }

              await userRef.update({'wallet': wallet - fee});
              await FirebaseDatabase.instance
                  .ref('registrations/${match['id']}/$uid')
                  .set({
                'ign': ignCtrl.text.trim(),
                'bgmiId': bgmiIdCtrl.text.trim(),
                'level': lvl,
                'timestamp': ServerValue.timestamp,
              });
await FirebaseDatabase.instance
    .ref('matches/${match['id']}/joined')
    .set(ServerValue.increment(1));
                  
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Slot Booked! Room ID Telegram aur App par milega.")),
                );
              }
            },
            child: const Text("Confirm Slot", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ==================== 4. WALLET & UTR DEPOSIT TAB ====================
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  final _amountCtrl = TextEditingController(text: "30");
  final _utrCtrl = TextEditingController();
  final String adminUpi = "skesports@upi"; // Apna UPI ID yahan badlein

  Future<void> _submitUtr() async {
    final amt = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final utr = _utrCtrl.text.trim();
    if (amt < 10 || utr.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sahi Amount aur 12-digit UTR number bharein")),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseDatabase.instance.ref('deposits').push().set({
      'uid': uid,
      'amount': amt,
      'utr': utr,
      'status': 'pending',
      'timestamp': ServerValue.timestamp,
    });

    _utrCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("UTR Request bhej di gayi! Verification ke baad balance add hoga.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseDatabase.instance.ref('users/$uid');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DatabaseEvent>(
            stream: userRef.onValue,
            builder: (context, snap) {
              int balance = 0;
              int winnings = 0;
              if (snap.hasData && snap.data!.snapshot.value != null) {
                final data = Map<dynamic, dynamic>.from(snap.data!.snapshot.value as Map);
                balance = data['wallet'] ?? 0;
                winnings = data['winnings'] ?? 0;
              }
              return Card(
                color: const Color(0xFF161B22),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text("DEPOSIT WALLET", style: TextStyle(color: Colors.grey
