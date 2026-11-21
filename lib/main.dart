import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String kFirebaseApiKey = 'AIzaSyDdXPfU6_RkgFXyq58nUeEFIQI3JI_nVf0';
const String kFirebaseDbUrl = 'https://sk-esports-live-default-rtdb.asia-southeast1.firebasedatabase.app';
const String kAdminEmail = 'sahidkhanmewati02@gmail.com'; // Apni admin email yahan rakh sakte hain

void main() => runApp(const SKEsportsUserApp());

class SKEsportsUserApp extends StatelessWidget {
  const SKEsportsUserApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SK ESPORTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFFFF9800),
        cardColor: const Color(0xFF161B22),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF9800),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true, _loading = false;
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _ignC = TextEditingController();
  final _bgmiIdC = TextEditingController();

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _submit() async {
    final email = _emailC.text.trim();
    final pass = _passC.text.trim();
    if (!email.contains('@') || pass.length < 6) {
      return _msg('Sahi Email aur kam se kam 6 digit ka Password dalein!');
    }
    if (!_isLogin && (_ignC.text.trim().isEmpty || _bgmiIdC.text.trim().length < 8)) {
      return _msg('Sahi BGMI Name (IGN) aur 10-digit BGMI ID dalein!');
    }

    setState(() => _loading = true);
    try {
      final endpoint = _isLogin ? 'accounts:signInWithPassword' : 'accounts:signUp';
      final authRes = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/$endpoint?key=$kFirebaseApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pass, 'returnSecureToken': true}),
      );
      final authData = jsonDecode(authRes.body);
      if (authRes.statusCode != 200) {
        final err = authData['error']?['message'] ?? 'Authentication Failed';
        throw Exception(err);
      }

      final String uid = authData['localId'];
      final String idToken = authData['idToken'];

      if (!_isLogin) {
        await http.put(
          Uri.parse('$kFirebaseDbUrl/users/$uid.json?auth=$idToken'),
          body: jsonEncode({
            'email': email,
            'ign': _ignC.text.trim(),
            'bgmiId': _bgmiIdC.text.trim(),
            'wallet': 0,
            'createdAt': DateTime.now().toIso8601String(),
          }),
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserHomeScreen(uid: uid, idToken: idToken, email: email),
        ),
      );
    } catch (e) {
      _msg('Error: ${e.toString().replaceAll("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sports_esports, size: 56, color: Color(0xFFFF9800)),
                const SizedBox(height: 8),
                const Text('SK ESPORTS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(
                  _isLogin ? 'Player Login' : 'Create New Player Account',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 18),
                if (!_isLogin) ...[
                  TextField(
                    controller: _ignC,
                    decoration: const InputDecoration(labelText: 'BGMI Name (IGN)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bgmiIdC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'BGMI ID (Level 40+ Only)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passC,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password (Min 6 chars)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text(_isLogin ? 'LOGIN' : 'SIGN UP', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'New Player? Create Account' : 'Already have an account? Login',
                    style: const TextStyle(color: Color(0xFF00E676)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class MatchModel {
  final String id, title, map, mode, time;
  final int entryFee, perKill, chickenDinner, maxSlots;
  int joinedCount;
  bool isJoined;
  String roomId, roomPass;

  MatchModel({
    required this.id, required this.title, required this.map, required this.mode, required this.time,
    required this.entryFee, required this.perKill, required this.chickenDinner,
    required this.maxSlots, required this.joinedCount,
    this.isJoined = false, this.roomId = '15 min before match', this.roomPass = '****',
  });
}

class WalletTxn {
  final String title, subtitle, status;
  final int amount;
  final bool isCredit;
  WalletTxn(this.title, this.subtitle, this.amount, this.isCredit, this.status);
}

class UserHomeScreen extends StatefulWidget {
  final String uid, idToken, email;
  const UserHomeScreen({super.key, required this.uid, required this.idToken, required this.email});
  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _tab = 0, _wallet = 0;
  String _ign = 'Player', _bgmiId = '0000000000';
  bool _syncing = true;

  List<MatchModel> _matches = [
    MatchModel(id: 'm1', title: 'SK ESPORTS Solo Rush #1', map: 'Erangel', mode: 'SOLO', time: 'Today, 08:00 PM', entryFee: 30, perKill: 20, chickenDinner: 175, maxSlots: 100, joinedCount: 42),
    MatchModel(id: 'm2', title: 'Midnight Livik Blast #2', map: 'Livik', mode: 'SOLO', time: 'Today, 09:30 PM', entryFee: 20, perKill: 15, chickenDinner: 100, maxSlots: 52, joinedCount: 19),
    MatchModel(id: 'm3', title: 'Weekend Miramar Clash #3', map: 'Miramar', mode: 'SQUAD', time: 'Tomorrow, 04:00 PM', entryFee: 50, perKill: 40, chickenDinner: 300, maxSlots: 100, joinedCount: 64),
    MatchModel(id: 'm4', title: 'Pro High Stakes #4', map: 'Vikendi', mode: 'SQUAD', time: 'Tomorrow, 09:00 PM', entryFee: 100, perKill: 80, chickenDinner: 600, maxSlots: 100, joinedCount: 28),
  ];

  List<WalletTxn> _txns = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _syncing = true);
    try {
      final userRes = await http.get(Uri.parse('$kFirebaseDbUrl/users/${widget.uid}.json?auth=${widget.idToken}'));
      if (userRes.statusCode == 200 && userRes.body != 'null') {
        final data = jsonDecode(userRes.body);
        _ign = data['ign'] ?? 'SK_Player';
        _bgmiId = data['bgmiId'] ?? '5123456789';
        _wallet = (data['wallet'] ?? 0) is int ? data['wallet'] : int.tryParse(data['wallet'].toString()) ?? 0;

        if (data['txns'] != null && data['txns'] is Map) {
          final List<WalletTxn> loadedTxns = [];
          (data['txns'] as Map).forEach((_, v) {
            loadedTxns.add(WalletTxn(
              v['title'] ?? 'Transaction',
              v['subtitle'] ?? '',
              v['amount'] ?? 0,
              v['isCredit'] ?? true,
              v['status'] ?? 'SUCCESS',
            ));
          });
          _txns = loadedTxns.reversed.toList();
        }
      }

      final matchRes = await http.get(Uri.parse('$kFirebaseDbUrl/matches.json?auth=${widget.idToken}'));
      if (matchRes.statusCode == 200 && matchRes.body != 'null') {
        final mMap = jsonDecode(matchRes.body) as Map<String, dynamic>;
        for (final m in _matches) {
          if (mMap[m.id] != null) {
            m.joinedCount = mMap[m.id]['joinedCount'] ?? m.joinedCount;
            m.roomId = mMap[m.id]['roomId'] ?? m.roomId;
            m.roomPass = mMap[m.id]['roomPass'] ?? m.roomPass;
            final players = mMap[m.id]['players'];
            if (players is Map && players.containsKey(widget.uid)) {
              m.isJoined = true;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _saveWalletAndTxn(WalletTxn txn) async {
    await http.patch(
      Uri.parse('$kFirebaseDbUrl/users/${widget.uid}.json?auth=${widget.idToken}'),
      body: jsonEncode({'wallet': _wallet, 'ign': _ign, 'bgmiId': _bgmiId}),
    );
    await http.post(
      Uri.parse('$kFirebaseDbUrl/users/${widget.uid}/txns.json?auth=${widget.idToken}'),
      body: jsonEncode({
        'title': txn.title,
        'subtitle': txn.subtitle,
        'amount': txn.amount,
        'isCredit': txn.isCredit,
        'status': txn.status,
      }),
    );
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void _joinDialog(MatchModel m) {
    final ignC = TextEditingController(text: _ign), idC = TextEditingController(text: _bgmiId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Join ${m.title}', style: const TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Rule: Minimum BGMI ID Level 40+ required.', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
          const SizedBox(height: 10),
          TextField(controller: ignC, decoration: const InputDecoration(labelText: 'BGMI Name (IGN)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: idC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'BGMI ID (10 Digits)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              if (ignC.text.trim().isEmpty || idC.text.trim().length < 8) return _msg('Sahi IGN aur ID dalein!');
              if (_wallet < m.entryFee) {
                Navigator.pop(ctx);
                setState(() => _tab = 1);
                return _msg('Balance kam hai! Wallet mein paise add karein.');
              }
              final txn = WalletTxn('Joined: ${m.title}', 'IGN: ${ignC.text.trim()}', m.entryFee, false, 'PAID');
              setState(() {
                _ign = ignC.text.trim();
                _bgmiId = idC.text.trim();
                _wallet -= m.entryFee;
                m.joinedCount++;
                m.isJoined = true;
                _txns.insert(0, txn);
              });
              Navigator.pop(ctx);
              await _saveWalletAndTxn(txn);
              await http.patch(
                Uri.parse('$kFirebaseDbUrl/matches/${m.id}.json?auth=${widget.idToken}'),
                body: jsonEncode({'joinedCount': m.joinedCount}),
              );
              await http.put(
                Uri.parse('$kFirebaseDbUrl/matches/${m.id}/players/${widget.uid}.json?auth=${widget.idToken}'),
                body: jsonEncode({'ign': _ign, 'bgmiId': _bgmiId, 'email': widget.email}),
              );
              _msg('Slot Confirmed! Data Live Database mein save ho gaya.');
            },
            child: Text('Pay ₹${m.entryFee}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _depositDialog() {
    int amt = 50;
    final utrC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Add Money (UPI QR)', style: TextStyle(fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(
              spacing: 6,
              children: [20, 30, 50, 100].map((v) => ChoiceChip(
                label: Text('₹$v'), selected: amt == v, selectedColor: const Color(0xFFFF9800),
                onSelected: (_) => setS(() => amt = v),
              )).toList(),
            ),
            const SizedBox(height: 10),
            const Icon(Icons.qr_code_2, size: 80, color: Color(0xFF00E676)),
            Text('Pay ₹$amt on SK ESPORTS QR', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(controller: utrC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '12-Digit UTR Number', border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () async {
                if (utrC.text.trim().length < 6) return _msg('Sahi UTR dalein!');
                final txn = WalletTxn('UPI Deposit', 'UTR: ${utrC.text.trim()}', amt, true, 'SUBMITTED');
                setState(() {
                  _wallet += amt;
                  _txns.insert(0, txn);
                });
                Navigator.pop(ctx);
                await _saveWalletAndTxn(txn);
                await http.post(
                  Uri.parse('$kFirebaseDbUrl/deposits.json?auth=${widget.idToken}'),
                  body: jsonEncode({'uid': widget.uid, 'ign': _ign, 'amount': amt, 'utr': utrC.text.trim()}),
                );
                _msg('₹$amt Added & Saved to Firebase!');
              },
              child: const Text('Add Money', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _withdrawDialog() {
    final upiC = TextEditingController(), amtC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Withdraw to UPI', style: TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: upiC, decoration: const InputDecoration(labelText: 'UPI ID (e.g. name@ybl)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Min ₹50)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              final v = int.tryParse(amtC.text.trim()) ?? 0;
              if (!upiC.text.contains('@') || v < 50 || v > _wallet) return _msg('Valid UPI aur balance check karein!');
              final txn = WalletTxn('UPI Withdrawal', upiC.text.trim(), v, false, 'PENDING');
              setState(() {
                _wallet -= v;
                _txns.insert(0, txn);
              });
              Navigator.pop(ctx);
              await _saveWalletAndTxn(txn);
              await http.post(
                Uri.parse('$kFirebaseDbUrl/withdrawals.json?auth=${widget.idToken}'),
                body: jsonEncode({'uid': widget.uid, 'ign': _ign, 'upi': upiC.text.trim(), 'amount': v}),
              );
              _msg('₹$v Withdrawal Request Sent!');
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _adminRoomDialog(MatchModel m) {
    final rIdC = TextEditingController(text: m.roomId);
    final rPassC = TextEditingController(text: m.roomPass);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Update Room: ${m.title}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: rIdC, decoration: const InputDecoration(labelText: 'Room ID', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: rPassC, decoration: const InputDecoration(labelText: 'Room Password', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              setState(() {
                m.roomId = rIdC.text.trim();
                m.roomPass = rPassC.text.trim();
              });
              Navigator.pop(ctx);
              await http.patch(
                Uri.parse('$kFirebaseDbUrl/matches/${m.id}.json?auth=${widget.idToken}'),
                body: jsonEncode({'roomId': m.roomId, 'roomPass': m.roomPass}),
              );
              _msg('Live Room ID & Pass Updated for All Players!');
            },
            child: const Text('Save Live', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(children: [
  
