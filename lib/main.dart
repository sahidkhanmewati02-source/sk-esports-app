import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const kApiKey = 'AIzaSyDdXPfU6_RkgFXyq58nUeEFIQI3JI_nVf0';
const kDbUrl = 'https://sk-esports-live-default-rtdb.asia-southeast1.firebasedatabase.app';
const kAdmin = 'sahidkhanmewati02@gmail.com';

void main() => runApp(const SKEsportsApp());

class SKEsportsApp extends StatelessWidget {
  const SKEsportsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SK ESPORTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        cardColor: const Color(0xFF161B22),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFF9800), secondary: Color(0xFF00E676)),
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
  final _emailC = TextEditingController(), _passC = TextEditingController();
  final _ignC = TextEditingController(), _idC = TextEditingController();

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _submit() async {
    final email = _emailC.text.trim(), pass = _passC.text.trim();
    if (!email.contains('@') || pass.length < 6) return _msg('Sahi Email aur 6+ digit Password dalein!');
    if (!_isLogin && (_ignC.text.trim().isEmpty || _idC.text.trim().length < 8)) {
      return _msg('Sahi BGMI IGN aur 10-digit ID dalein!');
    }
    setState(() => _loading = true);
    try {
      final ep = _isLogin ? 'accounts:signInWithPassword' : 'accounts:signUp';
      final res = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/$ep?key=$kApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pass, 'returnSecureToken': true}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) throw Exception(data['error']?['message'] ?? 'Login Failed');
      final uid = data['localId'], token = data['idToken'];
      if (!_isLogin) {
        await http.put(
          Uri.parse('$kDbUrl/users/$uid.json?auth=$token'),
          body: jsonEncode({'email': email, 'ign': _ignC.text.trim(), 'bgmiId': _idC.text.trim(), 'wallet': 0}),
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(uid: uid, token: token, email: email)));
    } catch (e) {
      _msg(e.toString().replaceAll('Exception: ', ''));
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
                const Icon(Icons.sports_esports, size: 54, color: Color(0xFFFF9800)),
                const SizedBox(height: 8),
                const Text('SK ESPORTS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(_isLogin ? 'Player Login' : 'Create Player Account', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                if (!_isLogin) ...[
                  TextField(controller: _ignC, decoration: const InputDecoration(labelText: 'BGMI Name (IGN)', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _idC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'BGMI ID (Level 40+)', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                ],
                TextField(controller: _emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _passC, obscureText: true, decoration: const InputDecoration(labelText: 'Password (6+ chars)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text(_isLogin ? 'LOGIN' : 'SIGN UP', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'New Player? Create Account' : 'Already have account? Login', style: const TextStyle(color: Color(0xFF00E676))),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class MatchItem {
  final String id, title, map, mode, time;
  final int fee, kill, win, slots;
  int joined;
  bool isJoined;
  String rId, rPass;
  MatchItem(this.id, this.title, this.map, this.mode, this.time, this.fee, this.kill, this.win, this.slots, this.joined,
      {this.isJoined = false, this.rId = '15 min before match', this.rPass = '****'});
}

class TxnItem {
  final String title, sub, status;
  final int amt;
  final bool credit;
  TxnItem(this.title, this.sub, this.amt, this.credit, this.status);
}

class HomeScreen extends StatefulWidget {
  final String uid, token, email;
  const HomeScreen({super.key, required this.uid, required this.token, required this.email});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0, _wallet = 0;
  String _ign = 'Player', _bgmiId = '0000000000';
  bool _loading = true;
  List<TxnItem> _txns = [];

  final List<MatchItem> _matches = [
    MatchItem('m1', 'SK ESPORTS Solo Rush #1', 'Erangel', 'SOLO', 'Today, 08:00 PM', 30, 20, 175, 100, 42),
    MatchItem('m2', 'Midnight Livik Blast #2', 'Livik', 'SOLO', 'Today, 09:30 PM', 20, 15, 100, 52, 19),
    MatchItem('m3', 'Weekend Miramar Clash #3', 'Miramar', 'SQUAD', 'Tomorrow, 04:00 PM', 50, 40, 300, 100, 64),
    MatchItem('m4', 'Pro High Stakes #4', 'Vikendi', 'SQUAD', 'Tomorrow, 09:00 PM', 100, 80, 600, 100, 28),
  ];

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _sync() async {
    setState(() => _loading = true);
    try {
      final uRes = await http.get(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'));
      if (uRes.statusCode == 200 && uRes.body != 'null') {
        final d = jsonDecode(uRes.body);
        _ign = d['ign'] ?? 'SK_Player';
        _bgmiId = d['bgmiId'] ?? '5123456789';
        _wallet = int.tryParse(d['wallet'].toString()) ?? 0;
        if (d['txns'] is Map) {
          final list = <TxnItem>[];
          (d['txns'] as Map).forEach((_, v) => list.add(TxnItem(v['title'] ?? '', v['sub'] ?? '', v['amt'] ?? 0, v['credit'] ?? true, v['status'] ?? 'OK')));
          _txns = list.reversed.toList();
        }
      }
      final mRes = await http.get(Uri.parse('$kDbUrl/matches.json?auth=${widget.token}'));
      if (mRes.statusCode == 200 && mRes.body != 'null') {
        final mMap = jsonDecode(mRes.body) as Map<String, dynamic>;
        for (final m in _matches) {
          if (mMap[m.id] != null) {
            m.joined = mMap[m.id]['joined'] ?? m.joined;
            m.rId = mMap[m.id]['rId'] ?? m.rId;
            m.rPass = mMap[m.id]['rPass'] ?? m.rPass;
            if (mMap[m.id]['players'] is Map && (mMap[m.id]['players'] as Map).containsKey(widget.uid)) m.isJoined = true;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveTxn(TxnItem t) async {
    await http.patch(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'), body: jsonEncode({'wallet': _wallet, 'ign': _ign, 'bgmiId': _bgmiId}));
    await http.post(Uri.parse('$kDbUrl/users/${widget.uid}/txns.json?auth=${widget.token}'),
        body: jsonEncode({'title': t.title, 'sub': t.sub, 'amt': t.amt, 'credit': t.credit, 'status': t.status}));
  }

  void _join(MatchItem m) {
    final ignC = TextEditingController(text: _ign), idC = TextEditingController(text: _bgmiId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Join ${m.title}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Rule: Minimum BGMI Level 40+ required.', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
          const SizedBox(height: 10),
          TextField(controller: ignC, decoration: const InputDecoration(labelText: 'BGMI Name (IGN)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: idC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'BGMI ID', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              if (ignC.text.trim().isEmpty || idC.text.trim().length < 8) return _msg('Sahi IGN aur ID dalein!');
              if (_wallet < m.fee) {
                Navigator.pop(ctx);
                setState(() => _tab = 1);
                return _msg('Balance kam hai! Wallet mein add karein.');
              }
              final t = TxnItem('Joined: ${m.title}', 'IGN: ${ignC.text.trim()}', m.fee, false, 'PAID');
              setState(() {
                _ign = ignC.text.trim();
                _bgmiId = idC.text.trim();
                _wallet -= m.fee;
                m.joined++;
                m.isJoined = true;
                _txns.insert(0, t);
              });
              Navigator.pop(ctx);
              await _saveTxn(t);
              await http.patch(Uri.parse('$kDbUrl/matches/${m.id}.json?auth=${widget.token}'), body: jsonEncode({'joined': m.joined}));
              await http.put(Uri.parse('$kDbUrl/matches/${m.id}/players/${widget.uid}.json?auth=${widget.token}'),
                  body: jsonEncode({'ign': _ign, 'bgmiId': _bgmiId, 'email': widget.email}));
              _msg('Slot Confirmed!');
            },
            child: Text('Pay ₹${m.fee}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deposit() {
    int amt = 50;
    final utrC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Add Money (UPI QR)', style: TextStyle(fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(
              spacing: 6,
              children: [20, 30, 50, 100].map((v) => ChoiceChip(label: Text('₹$v'), selected: amt == v, selectedColor: const Color(0xFFFF9800), onSelected: (_) => setS(() => amt = v))).toList(),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.qr_code_2, size: 76, color: Color(0xFF00E676)),
            Text('Pay ₹$amt on SK ESPORTS QR', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: utrC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '12-Digit UTR Number', border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () async {
                if (utrC.text.trim().length < 6) return _msg('Sahi UTR dalein!');
                final t = TxnItem('UPI Deposit', 'UTR: ${utrC.text.trim()}', amt, true, 'SUBMITTED');
                setState(() {
                  _wallet += amt;
                  _txns.insert(0, t);
                });
                Navigator.pop(ctx);
                await _saveTxn(t);
                await http.post(Uri.parse('$kDbUrl/deposits.json?auth=${widget.token}'), body: jsonEncode({'uid': widget.uid, 'ign': _ign, 'amt': amt, 'utr': utrC.text.trim()}));
                _msg('₹$amt Added!');
              },
              child: const Text('Add Money', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _withdraw() {
    final upiC = TextEditingController(), amtC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Withdraw to UPI', style: TextStyle(fontSize: 15)),
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
              final t = TxnItem('UPI Withdrawal', upiC.text.trim(), v, false, 'PENDING');
              setState(() {
                _wallet -= v;
                _txns.insert(0, t);
              });
              Navigator.pop(ctx);
              await _saveTxn(t);
              await http.post(Uri.parse('$kDbUrl/withdrawals.json?auth=${widget.token}'), body: jsonEncode({'uid': widget.uid, 'ign': _ign, 'upi': upiC.text.trim(), 'amt': v}));
              _msg('Withdrawal Request Sent!');
            },
            child: const Text('Withdraw', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editRoom(MatchItem m) {
    final idC = TextEditingController(text: m.rId), passC = TextEditingController(text: m.rPass);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Room Details: ${m.title}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: idC, decoration: const InputDecoration(labelText: 'Room ID', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: passC, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              setState(() {
                m.rId = idC.text.trim();
                m.rPass = passC.text.trim();
              });
              Navigator.pop(ctx);
              await http.patch(Uri.parse('$kDbUrl/matches/${m.id}.json?auth=${widget.token}'), body: jsonEncode({'rId': m.rId, 'rPass': m.rPass}));
              _msg('Live Room ID & Pass Updated!');
            },
            child: const Text('Save Live', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          Icon(Icons.sports_esports, color: Color(0xFFFF9800)),
          SizedBox(width: 8),
          Text('SK ESPORTS', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _sync),
          GestureDetector(
            onTap: () => setState(() => _tab = 1),
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF9800))),
              child: Center(child: Text('₹$_wallet', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676)))),
            ),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800))) : [_matchesTab(), _walletTab(), _profileTab()][_tab],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF161B22),
        currentIndex: _tab,
        selectedItemColor: const Color(0xFFFF9800),
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _matchesTab() {
    final isAdmin = widget.email.toLowerCase() == kAdmin.toLowerCase();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _matches.length,
      itemBuilder: (_, i) {
        final m = _matches[i], left = m.slots - m.joined;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: m.isJoined ? const Color(0xFF00E676) : Colors.transparent)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(m.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x33FF9800), borderRadius: BorderRadius.circular(6)),
                  child: Text('${m.map} • ${m.mode}', style: const TextStyle(color: Color(0xFFFF9800), fontSize: 11)),
                ),
              ]),
  
