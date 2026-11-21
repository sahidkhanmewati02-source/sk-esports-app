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

class HomeScreen extends StatefulWidget {
  final String uid, token, email;
  const HomeScreen({super.key, required this.uid, required this.token, required this.email});
  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  HomeScreen get w => widget as HomeScreen;
  bool get isAdmin => w.email.toLowerCase() == kAdmin.toLowerCase();
  int _tab = 0, _wallet = 0;
  String _ign = 'Player', _bgmiId = 'Not Set', _upiId = 'skesports@upi', _qrUrl = '';
  bool _loading = true;
  List _matches = [], _txns = [], _pendingDeps = [], _allUsers = [];
  final _upiC = TextEditingController(), _qrUrlC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  int _num(dynamic v) => int.tryParse(v.toString()) ?? 0;

  Future _sync() async {
    setState(() => _loading = true);
    try {
      final cRes = await http.get(Uri.parse('$kDbUrl/config.json?auth=${w.token}'));
      if (cRes.statusCode == 200 && cRes.body != 'null') {
        final c = jsonDecode(cRes.body);
        _upiId = c['upiId'] ?? 'skesports@upi';
        _qrUrl = c['qrUrl'] ?? '';
      }
      _upiC.text = _upiId;
      _qrUrlC.text = _qrUrl;

      final uRes = await http.get(Uri.parse('$kDbUrl/users/${w.uid}.json?auth=${w.token}'));
      if (uRes.statusCode == 200 && uRes.body != 'null') {
        final d = jsonDecode(uRes.body);
        _ign = d['ign'] ?? 'SK_Player';
        _bgmiId = d['bgmiId'] ?? 'Not Set';
        _wallet = _num(d['wallet']);
        if (d['txns'] is Map) _txns = (d['txns'] as Map).values.toList().reversed.toList();
      }

      final mRes = await http.get(Uri.parse('$kDbUrl/matches.json?auth=${w.token}'));
      if (mRes.statusCode == 200 && mRes.body != 'null') {
        final mMap = jsonDecode(mRes.body) as Map;
        final list = [];
        mMap.forEach((k, v) {
          if (v is Map) {
            final item = Map.from(v);
            item['id'] = k;
            item['isJoined'] = v['players'] is Map && (v['players'] as Map).containsKey(w.uid);
            list.add(item);
          }
        });
        _matches = list;
      } else {
        final def = {
          'm1': {'title': 'SK ESPORTS Solo Rush #1', 'map': 'Erangel', 'mode': 'SOLO', 'time': 'Today, 08:00 PM', 'fee': 30, 'kill': 20, 'win': 175, 'slots': 100, 'joined': 0, 'rId': '15 min before match', 'rPass': '****'}
        };
        await http.put(Uri.parse('$kDbUrl/matches.json?auth=${w.token}'), body: jsonEncode(def));
        _matches = [{'id': 'm1', ...def['m1']!, 'isJoined': false}];
      }

      if (isAdmin) {
        final dRes = await http.get(Uri.parse('$kDbUrl/deposits.json?auth=${w.token}'));
        final deps = [];
        if (dRes.statusCode == 200 && dRes.body != 'null') {
          (jsonDecode(dRes.body) as Map).forEach((k, v) {
            if (v is Map && v['status'] == 'PENDING') {
              final item = Map.from(v);
              item['id'] = k;
              deps.add(item);
            }
          });
        }
        _pendingDeps = deps.reversed.toList();

        final allRes = await http.get(Uri.parse('$kDbUrl/users.json?auth=${w.token}'));
        final usrs = [];
        if (allRes.statusCode == 200 && allRes.body != 'null') {
          (jsonDecode(allRes.body) as Map).forEach((k, v) {
            if (v is Map) {
              final item = Map.from(v);
              item['uid'] = k;
              usrs.add(item);
            }
          });
        }
        _allUsers = usrs;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future _saveUserTxn(String targetUid, int newBal, String title, String sub, int amt, bool credit, String status) async {
    final t = {'title': title, 'sub': sub, 'amt': amt, 'credit': credit, 'status': status};
    if (targetUid == w.uid) setState(() => _txns.insert(0, t));
    await http.patch(Uri.parse('$kDbUrl/users/$targetUid.json?auth=${w.token}'), body: jsonEncode({'wallet': newBal}));
    await http.post(Uri.parse('$kDbUrl/users/$targetUid/txns.json?auth=${w.token}'), body: jsonEncode(t));
  }

  void _join(Map m) {
    final ignC = TextEditingController(text: _ign);
    final idC = TextEditingController(text: _bgmiId == 'Not Set' ? '' : _bgmiId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Join ${m['title']}', style: const TextStyle(fontSize: 15)),
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
              final fee = _num(m['fee']);
              if ((_wallet - fee).isNegative) { Navigator.pop(ctx); setState(() => _tab = 1); return _msg('Balance kam hai! Wallet mein add karein.'); }
              final newJoined = _num(m['joined']) + 1;
              setState(() { _ign = ignC.text.trim(); _bgmiId = idC.text.trim(); _wallet = _wallet - fee; m['joined'] = newJoined; m['isJoined'] = true; });
              Navigator.pop(ctx);
              await http.patch(Uri.parse('$kDbUrl/users/${w.uid}.json?auth=${w.token}'), body: jsonEncode({'ign': _ign, 'bgmiId': _bgmiId}));
              await _saveUserTxn(w.uid, _wallet, 'Joined: ${m['title']}', 'IGN: $_ign', fee, false, 'PAID');
              await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${w.token}'), body: jsonEncode({'joined': newJoined}));
              await http.put(Uri.parse('$kDbUrl/matches/${m['id']}/players/${w.uid}.json?auth=${w.token}'), body: jsonEncode({'ign': _ign, 'bgmiId': _bgmiId}));
              _msg('Slot Confirmed!');
            },
            child: Text('Pay ₹${m['fee']}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        builder: (ctx, setS) {
          final autoQr = 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent('upi://pay?pa=$_upiId&pn=SK%20ESPORTS&am=$amt&cu=INR')}';
          final img = _qrUrl.trim().isNotEmpty ? _qrUrl.trim() : autoQr;
          return AlertDialog(
            title: const Text('Add Money (Scan & Pay)', style: TextStyle(fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 6, children: [20, 30, 50, 100].map((v) => ChoiceChip(label: Text('₹$v'), selected: amt == v, onSelected: (_) => setS(() => amt = v))).toList()),
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(6),
                  child: Image.network(img, height: 150, width: 150, errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 120, color: Colors.black)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () { Clipboard.setData(ClipboardData(text: _upiId)); _msg('UPI ID Copied!'); },
                  child: Text('UPI: $_upiId (Tap to Copy)', style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                TextField(controller: utrC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '12-Digit UTR / Ref No.', border: OutlineInputBorder())),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                onPressed: () async {
                  if (!RegExp(r'^\d{6,}$').hasMatch(utrC.text.trim())) return _msg('Sahi 12-digit UTR dalein!');
                  Navigator.pop(ctx);
                  await _saveUserTxn(w.uid, _wallet, 'Deposit Request', 'UTR: ${utrC.text.trim()}', amt, true, 'PENDING');
                  await http.post(Uri.parse('$kDbUrl/deposits.json?auth=${w.token}'),
                      body: jsonEncode({'uid': w.uid, 'ign': _ign, 'amt': amt, 'utr': utrC.text.trim(), 'status': 'PENDING'}));
                  _msg('UTR Submitted! Admin approve karte hi balance add hoga.');
                },
                child: const Text('Submit UTR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _withdraw() {
    final upiC = TextEditingController(), amtC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Winnings', style: TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: upiC, decoration: const InputDecoration(labelText: 'Your UPI ID (e.g. name@ybl)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Min ₹50)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              final v = _num(amtC.text.trim());
              if (!upiC.text.contains('@') || (v - 50).isNegative || (_wallet - v).isNegative) return _msg('Valid UPI aur balance check karein!');
              setState(() => _wallet = _wallet - v);
              Navigator.pop(ctx);
              await _saveUserTxn(w.uid, _wallet, 'UPI Withdrawal', upiC.text.trim(), v, false, 'PENDING');
              await http.post(Uri.parse('$kDbUrl/withdrawals.json?auth=${w.token}'), body: jsonEncode({'uid': w.uid, 'ign': _ign, 'upi': upiC.text.trim(), 'amt': v, 'status': 'PENDING'}));
              _msg('Withdrawal Request Sent!');
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editRoom(Map m) {
    final idC = TextEditingController(text: '${m['rId']}'), passC = TextEditingController(text: '${m['rPass']}');
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
              setState(() { m['rId'] = idC.text.trim(); m['rPass'] = passC.text.trim(); });
              Navigator.pop(ctx);
              await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${w.token}'), body: jsonEncode({'rId': m['rId'], 'rPass': m['rPass']}));
              _msg('Live Room Updated!');
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPlayers(Map m) {
    final pMap = m['players'] is Map ? (m['players'] as Map).values.toList() : [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Players (${pMap.length})', style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          child: pMap.isEmpty
              ? const Text('Abhi kisi ne join nahi kiya.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pMap.length,
                  itemBuilder: (_, i) => ListTile(dense: true, title: Text('${pMap[i]['ign']}'), subtitle: Text('BGMI ID: ${pMap[i]['bgmiId']}')),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _addMatchDialog() {
    final tC = TextEditingController(), mapC = TextEditingController(text: 'Erangel'), modeC = TextEditingController(text: 'SOLO');
    final timeC = TextEditingController(text: 'Today, 08:30 PM'), feeC = TextEditingController(text: '30'), killC = TextEditingController(text: '20'), winC = TextEditingController(text: '175');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Match', style: TextStyle(fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: tC, decoration: const InputDecoration(labelText: 'Match Title (e.g. Solo Clash #2)')),
            TextField(controller: mapC, decoration: const InputDecoration(labelText: 'Map (Erangel / Livik / Miramar)')),
            TextField(controller: modeC, decoration: const InputDecoration(labelText: 'Mode (SOLO / SQUAD)')),
            TextField(controller: timeC, decoration: const InputDecoration(labelText: 'Match Time')),
            TextField(controller: feeC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Entry Fee (₹)')),
            TextField(controller: killC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per Kill (₹)')),
            TextField(controller: winC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Winner Prize (₹)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
    
