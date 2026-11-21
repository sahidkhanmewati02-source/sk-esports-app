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
  State createState() => _AuthScreenState();
}

class _AuthScreenState extends State {
  bool _isLogin = true, _loading = false;
  final _email = TextEditingController(), _pass = TextEditingController(), _name = TextEditingController();

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future _submit() async {
    final e = _email.text.trim(), p = _pass.text.trim();
    if (!e.contains('@') || !RegExp(r'^.{6,}$').hasMatch(p)) return _msg('Sahi Email aur 6+ digit Password dalein!');
    if (!_isLogin && _name.text.trim().isEmpty) return _msg('Apna Naam dalein!');
    setState(() => _loading = true);
    try {
      final ep = _isLogin ? 'accounts:signInWithPassword' : 'accounts:signUp';
      final res = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/$ep?key=$kApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': e, 'password': p, 'returnSecureToken': true}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) throw Exception(data['error']?['message'] ?? 'Auth Failed');
      final String uid = data['localId'], token = data['idToken'];
      if (!_isLogin) {
        await http.put(Uri.parse('$kDbUrl/users/$uid.json?auth=$token'),
            body: jsonEncode({'email': e, 'ign': _name.text.trim(), 'bgmiId': 'Not Set', 'wallet': 0}));
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(uid: uid, token: token, email: e)));
    } catch (err) {
      _msg(err.toString().replaceAll('Exception: ', ''));
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sports_esports, size: 52, color: Color(0xFFFF9800)),
                const Text('SK ESPORTS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(_isLogin ? 'Player Login' : 'Create Account', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 14),
                if (!_isLogin) ...[
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                ],
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password (6+ chars)', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), minimumSize: const Size.fromHeight(46)),
                  onPressed: _loading ? null : _submit,
                  child: _loading ? const CircularProgressIndicator(color: Colors.black) : Text(_isLogin ? 'LOGIN' : 'SIGN UP', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                TextButton(onPressed: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? 'New Player? Sign Up' : 'Already have account? Login')),
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
  bool isJoined = false;
  String rId = '15 min before match', rPass = '****';
  MatchItem(this.id, this.title, this.map, this.mode, this.time, this.fee, this.kill, this.win, this.slots, this.joined);
}

class HomeScreen extends StatefulWidget {
  final String uid, token, email;
  const HomeScreen({super.key, required this.uid, required this.token, required this.email});
  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  HomeScreen get w => widget as HomeScreen;
  int _tab = 0, _wallet = 0;
  String _ign = 'Player', _bgmiId = 'Not Set';
  bool _loading = true;
  List _txns = [];
  final List _matches = [
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

  Future _sync() async {
    setState(() => _loading = true);
    try {
      final uRes = await http.get(Uri.parse('$kDbUrl/users/${w.uid}.json?auth=${w.token}'));
      if (uRes.statusCode == 200 && uRes.body != 'null') {
        final d = jsonDecode(uRes.body);
        _ign = d['ign'] ?? 'SK_Player';
        _bgmiId = d['bgmiId'] ?? 'Not Set';
        _wallet = int.tryParse(d['wallet'].toString()) ?? 0;
        if (d['txns'] is Map) _txns = (d['txns'] as Map).values.toList().reversed.toList();
      }
      final mRes = await http.get(Uri.parse('$kDbUrl/matches.json?auth=${w.token}'));
      if (mRes.statusCode == 200 && mRes.body != 'null') {
        final mMap = jsonDecode(mRes.body);
        for (final m in _matches) {
          if (mMap[m.id] != null) {
            m.joined = mMap[m.id]['joined'] ?? m.joined;
            m.rId = mMap[m.id]['rId'] ?? m.rId;
            m.rPass = mMap[m.id]['rPass'] ?? m.rPass;
            if (mMap[m.id]['players'] is Map && (mMap[m.id]['players'] as Map).containsKey(w.uid)) m.isJoined = true;
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future _saveTxn(String title, String sub, int amt, bool credit, String status) async {
    final t = {'title': title, 'sub': sub, 'amt': amt, 'credit': credit, 'status': status};
    setState(() => _txns.insert(0, t));
    await http.patch(Uri.parse('$kDbUrl/users/${w.uid}.json?auth=${w.token}'), body: jsonEncode({'wallet': _wallet, 'ign': _ign, 'bgmiId': _bgmiId}));
    await http.post(Uri.parse('$kDbUrl/users/${w.uid}/txns.json?auth=${w.token}'), body: jsonEncode(t));
  }

  void _join(dynamic m) {
    final ignC = TextEditingController(text: _ign);
    final idC = TextEditingController(text: _bgmiId == 'Not Set' ? '' : _bgmiId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Join ${m.title}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Rule: Minimum BGMI Level 30+ ID required.', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
          const SizedBox(height: 8),
          TextField(controller: ignC, decoration: const InputDecoration(labelText: 'BGMI Name (IGN)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: idC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'BGMI ID (10 Digits)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              if (ignC.text.trim().isEmpty || !RegExp(r'^\d{8,}$').hasMatch(idC.text.trim())) return _msg('Sahi BGMI Name aur ID dalein!');
              final int fee = m.fee;
              if ((_wallet - fee).isNegative) { Navigator.pop(ctx); setState(() => _tab = 1); return _msg('Balance kam hai!'); }
              setState(() { _ign = ignC.text.trim(); _bgmiId = idC.text.trim(); _wallet = _wallet - fee; m.joined++; m.isJoined = true; });
              Navigator.pop(ctx);
              await _saveTxn('Joined: ${m.title}', 'IGN: $_ign', fee, false, 'PAID');
              await http.patch(Uri.parse('$kDbUrl/matches/${m.id}.json?auth=${w.token}'), body: jsonEncode({'joined': m.joined}));
              await http.put(Uri.parse('$kDbUrl/matches/${m.id}/players/${w.uid}.json?auth=${w.token}'), body: jsonEncode({'ign': _ign, 'bgmiId': _bgmiId}));
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
          title: const Text('Add Money (UPI QR)', style: TextStyle(fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 6, children: [20, 30, 50, 100].map((v) => ChoiceChip(label: Text('₹$v'), selected: amt == v, onSelected: (_) => setS(() => amt = v))).toList()),
            const Icon(Icons.qr_code_2, size: 76, color: Color(0xFF00E676)),
            TextField(controller: utrC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '12-Digit UTR Number', border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () async {
                if (!RegExp(r'^\d{6,}$').hasMatch(utrC.text.trim())) return _msg('Sahi UTR dalein!');
                setState(() => _wallet = _wallet + amt);
                Navigator.pop(ctx);
                await _saveTxn('UPI Deposit', 'UTR: ${utrC.text.trim()}', amt, true, 'SUBMITTED');
                await http.post(Uri.parse('$kDbUrl/deposits.json?auth=${w.token}'), body: jsonEncode({'uid': w.uid, 'ign': _ign, 'amt': amt, 'utr': utrC.text.trim()}));
                _msg('₹$amt Added!');
              },
              child: const Text('Add', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _editRoom(dynamic m) {
    final idC = TextEditingController(text: m.rId), passC = TextEditingController(text: m.rPass);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Room ID & Pass', style: TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: idC, decoration: const InputDecoration(labelText: 'Room ID', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: passC, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              setState(() { m.rId = idC.text.trim(); m.rPass = passC.text.trim(); });
              Navigator.pop(ctx);
              await http.patch(Uri.parse('$kDbUrl/matches/${m.id}.json?auth=${w.token}'), body: jsonEncode({'rId': m.rId, 'rPass': m.rPass}));
              _msg('Live Room Updated!');
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = w.email.toLowerCase() == kAdmin.toLowerCase();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('SK ESPORTS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _sync),
          Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('₹$_wallet', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676), fontSize: 16)))),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : [
        ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _matches.length,
          itemBuilder: (_, i) {
            final m = _matches[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m.title} (${m.map} • ${m.mode})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Time: ${m.time} | Entry: ₹${m.fee} | Kill: ₹${m.kill} | Win: ₹${m.win}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (m.isJoined || isAdmin) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Room: ${m.rId} | Pass: ${m.rPass}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                      if (isAdmin) IconButton(icon: const Icon(Icons.edit, color: Color(0xFFFF9800)), onPressed: () => _editRoom(m)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${m.joined}/${m.slots} Joined', style: const TextStyle(color: Colors.grey)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: m.isJoined ? const Color(0xFF00E676) : const Color(0xFFFF9800)),
                      onPressed: m.isJoined ? null : () => _join(m),
                      child: Text(m.isJoined ? 'JOINED ✓' : 'Join ₹${m.fee}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ]),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Card(child: ListTile(title: const Text('Wallet Balance'), trailing: Text('₹$_wallet', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00E676))))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), minimumSize: const Size.fromHeight(44)), onPressed: _deposit, child: const Text('Add Money (UPI QR)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            Expanded(child: ListView.builder(itemCount: _txns.length, itemBuilder: (_, i) => ListTile(title: Text('${_txns[i]['title']}'), subtitle: Text('${_txns[i]['sub']}'), trailing: Text('₹${_txns[i]['amt']}')))),
          ]),
        ),
        ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: ListTile(title: Text(_ign), subtitle: Text('BGMI ID: $_bgmiId\n${w.email}'))),
          const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('RULES:\n• BGMI Level 30+ required.\n• Room ID & Pass 15 min pehle milega.'))),
          ElevatedButton(onPressed: () { Clipboard.setData(const ClipboardData(text: 'https://t.me/SK_ESPORTSOFFICIAL')); _msg('Telegram Link Copied!'); }, child: const Text('Join Telegram (@SK_ESPORTSOFFICIAL)')),
          OutlinedButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen())), child: const Text('Logout', style: TextStyle(color: Colors.redAccent))),
        ]),
      ][_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        selectedItemColor: const Color(0xFFFF9800),
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
