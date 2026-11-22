import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String dbUrl = 'https://sk-esports-live-default-rtdb.asia-southeast1.firebasedatabase.app';

void main() {
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (!mounted) return;
    if (userId != null && userId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainDashboard(userId: userId)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF9800))),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (phone.isEmpty || pass.isEmpty) {
      _msg('Number aur Password daalo');
      return;
    }

    setState(() => _loading = true);
    try {
      final url = Uri.parse('$dbUrl/users/$phone.json');
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (_isRegister) {
        if (data != null) {
          _msg('Ye number pehle se registered hai, Login karo');
          setState(() => _loading = false);
          return;
        }
        await http.put(
          url,
          body: jsonEncode({
            'phone': phone,
            'name': name.isEmpty ? 'Player_$phone' : name,
            'password': pass,
            'wallet': 0,
            'winnings': 0,
            'createdAt': DateTime.now().toIso8601String(),
          }),
        );
      } else {
        if (data == null) {
          _msg('Account nahi mila, pehle Register karo');
          setState(() => _loading = false);
          return;
        }
        if (data['password'] != pass) {
          _msg('Galat Password!');
          setState(() => _loading = false);
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', phone);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainDashboard(userId: phone)),
      );
    } catch (e) {
      _msg('Network Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.emoji_events, size: 80, color: Color(0xFFFF9800)),
              const SizedBox(height: 12),
              const Text(
                'SK ESPORTS',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const Text('BGMI Custom Tournaments', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 28),
              if (_isRegister) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'In-Game Name (IGN)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.black,
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          _isRegister ? 'CREATE ACCOUNT' : 'LOGIN',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(
                  _isRegister ? 'Pehle se account hai? Login karo' : 'Naya account banana hai? Register karo',
                  style: const TextStyle(color: Color(0xFFFF9800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  final String userId;
  const MainDashboard({super.key, required this.userId});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _tab = 0;
  Map<String, dynamic> user = {};
  Map<String, dynamic> matches = {};
  Map<String, dynamic> config = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$dbUrl/users/${widget.userId}.json')),
        http.get(Uri.parse('$dbUrl/matches.json')),
        http.get(Uri.parse('$dbUrl/config.json')),
      ]);

      setState(() {
        user = jsonDecode(responses[0].body) ?? {};
        final mData = jsonDecode(responses[1].body);
        matches = mData is Map<String, dynamic> ? mData : {};
        config = jsonDecode(responses[2].body) ?? {};
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> _joinMatch(String matchId, Map<String, dynamic> match) async {
    final int fee = int.tryParse(match['entryFee']?.toString() ?? '30') ?? 30;
    final int wallet = int.tryParse(user['wallet']?.toString() ?? '0') ?? 0;
    final Map joined = match['joined'] is Map ? match['joined'] : {};
    final int maxSlots = int.tryParse(match['maxSlots']?.toString() ?? '100') ?? 100;

    if (joined.containsKey(widget.userId)) {
      _toast('Tum is match mein pehle se joined ho!');
      return;
    }
    if (joined.length >= maxSlots) {
      _toast('Slots Full ho gaye hain!');
      return;
    }
    if (wallet < fee) {
      _toast('Wallet mein balance kam hai! Pehle Add Money karo.');
      return;
    }

    final bgmiCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Match'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Entry Fee: ₹$fee (Wallet se katega)\nRule: Level 40+ BGMI ID zaroori hai.'),
            const SizedBox(height: 12),
            TextField(
              controller: bgmiCtrl,
              decoration: const InputDecoration(
                labelText: 'Apna BGMI Name / ID daalo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.black),
            child: const Text('Confirm Join'),
          ),
        ],
      ),
    );

    if (confirm != true || bgmiCtrl.text.trim().isEmpty) return;

    await http.patch(
      Uri.parse('$dbUrl/users/${widget.userId}.json'),
      body: jsonEncode({'wallet': wallet - fee}),
    );
    await http.put(
      Uri.parse('$dbUrl/matches/$matchId/joined/${widget.userId}.json'),
      body: jsonEncode({
        'bgmiId': bgmiCtrl.text.trim(),
        'phone': widget.userId,
        'joinedAt': DateTime.now().toIso8601String(),
      }),
    );
    _toast('Match Join ho gaya!');
    _refresh();
  }

  Future<void> _submitDeposit() async {
    final amtCtrl = TextEditingController();
    final utrCtrl = TextEditingController();
    final upiId = config['upiId']?.toString() ?? 'Admin se UPI lo';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Money (UPI)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('UPI ID: $upiId', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Upar diye gaye UPI par payment karke Amount aur 12-digit UTR daalo:'),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: utrCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '12-Digit UTR Number', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (amtCtrl.text.isEmpty || utrCtrl.text.isEmpty) return;
              await http.post(
                Uri.parse('$dbUrl/deposits.json'),
                body: jsonEncode({
                  'userId': widget.userId,
                  'amount': int.tryParse(amtCtrl.text.trim()) ?? 0,
                  'utr': utrCtrl.text.trim(),
                  'status': 'pending',
                  'time': DateTime.now().toIso8601String(),
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _toast('Deposit Request bhej di gayi hai! Admin verify karke add karega.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.black),
            child: const Text('Submit UTR'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitWithdraw() async {
    final amtCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    final int wallet = int.tryParse(user['wallet']?.toString() ?? '0') ?? 0;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Money'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available Balance: ₹$wallet'),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Withdraw Amount (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: upiCtrl,
              decoration: const InputDecoration(labelText: 'Apni UPI ID daalo', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
              if (amt <= 0 || amt > wallet || upiCtrl.text.trim().isEmpty) {
                _toast('Sahi amount aur UPI ID daalo');
                return;
              }
              await http.patch(
                Uri.parse('$dbUrl/users/${widget.userId}.json'),
                body: jsonEncode({'wallet': wallet - amt}),
              );
              await http.post(
                Uri.parse('$dbUrl/withdrawals.json'),
                body: jsonEncode({
                  'userId': widget.userId,
                  'amount': amt,
                  'upi': upiCtrl.text.trim(),
                  'status': 'pending',
                  'time': DateTime.now().toIso8601String(),
                }),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _toast('Withdraw Request submit ho gayi!');
              _refresh();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), foregroundColor: Colors.black),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = user['wallet'] ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SK ESPORTS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1D2D),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: Center(
              child: Text('₹$wallet', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _tab == 0
              ? _buildMatchesTab()
              : _tab == 1
                  ? _buildWalletTab(wallet)
                  : _buildProfileTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        selectedItemColor: const Color(0xFFFF9800),
        backgroundColor: const Color(0xFF1A1D2D),
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports_esports), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    if (matches.isEmpty) {
      return const Center(child: Text('Abhi koi match live nahi hai'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: matches.entries.map((entry) {
        final id = entry.key;
        final m = entry.value as Map<String, dynamic>;
        final Map joined = m['joined'] is Map ? m['joined'] : {};
        final bool isJoined = joined.containsKey(widget.userId);
        final int maxSlots = int.tryParse(m['maxSlots']?.toString() ?? '100') ?? 100;

        return Card(
          color: const Color(0xFF1A1D2D),
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m['title']?.toString() ?? 'BGMI Solo Tournament',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFFF9800)),
                    ),
                    Chip(
                      label: Text('${m['map'] ?? 'Erangel'} | ${m['type'] ?? 'SOLO'}'),
                      backgroundColor: Colors.black38,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Time: ${m['time'] ?? 'Soon'}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Entry: ₹${m['entryFee'] ?? 30}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Per Kill: ₹${m['perKill'] ?? 20}', style: const TextStyle(color: Colors.greenAccent)),
                    Text('Booyah/CD: ₹${m['prize'] ?? 175}', style: const TextStyle(color: Colors.amber)),
                  ],
                ),
                const Divider(height: 20),
                if (isJoined && m['roomId'] != null && m['roomId'].toString().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      'Room ID: ${m['roomId']}   |   Pass: ${m['roomPass'] ?? ''}',
                      style: const TextStyle(color: Colors.gre
