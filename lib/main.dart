import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';


const String kApiKey = 'AIzaSyDdXPfU6_RkgFXyq58nUeEFIQI3JI_nVf0';
const String kDbUrl = 'https://sk-esports-live-default-rtdb.asia-southeast1.firebasedatabase.app';
const String kAdmin = 'sahidkhanmewati02@gmail.com';

void main() => runApp(MaterialApp(
      title: 'SK ESPORTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        cardColor: const Color(0xFF161B22),
      ),
      home: const AuthScreen(),
    ));

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _pass = TextEditingController();
  bool _isLogin = true, _showPass = false, _loading = false, _checking = true;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future _autoLogin() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final rt = sp.getString('rt'), email = sp.getString('email');
      if (rt != null && email != null) {
        final res = await http.post(
          Uri.parse('https://securetoken.googleapis.com/v1/token?key=$kApiKey'),
          body: {'grant_type': 'refresh_token', 'refresh_token': rt},
        );
        final d = jsonDecode(res.body);
        if (res.statusCode == 200 && mounted) {
          await sp.setString('rt', d['refresh_token']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(uid: d['user_id'], token: d['id_token'], email: email),
            ),
          );
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future _forgotPass() async {
    final e = _email.text.trim();
    if (!e.contains('@')) return _msg('Pehle upar apna Email dalein!');
    try {
      final res = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$kApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': e}),
      );
      final d = jsonDecode(res.body);
      if (res.statusCode != 200) throw Exception(d['error']?['message'] ?? 'Failed');
      _msg('Password reset link aapke Email par bhej diya gaya hai!');
    } catch (err) {
      _msg(err.toString().replaceAll('Exception: ', ''));
    }
  }

  Future _submit() async {
    final e = _email.text.trim(), p = _pass.text.trim();
    if (!e.contains('@') || !RegExp(r'^.{6,}$').hasMatch(p)) {
      return _msg('Sahi Email aur 6+ digit Password dalein!');
    }
    if (!_isLogin && _name.text.trim().isEmpty) {
      return _msg('Apna Naam dalein!');
    }
    setState(() => _loading = true);
    try {
      final ep = _isLogin ? 'accounts:signInWithPassword' : 'accounts:signUp';
      final res = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/$ep?key=$kApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': e, 'password': p, 'returnSecureToken': true}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error']?['message'] ?? 'Auth Failed');
      }
      final String uid = data['localId'], token = data['idToken'];
      final sp = await SharedPreferences.getInstance();
      await sp.setString('rt', data['refreshToken']);
      await sp.setString('email', e);

      if (!_isLogin) {
        await http.put(
          Uri.parse('$kDbUrl/users/$uid.json?auth=$token'),
          body: jsonEncode({
            'email': e,
            'ign': _name.text.trim(),
            'bgmiId': 'Not Set',
            'wallet': 0,
          }),
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(uid: uid, token: token, email: e),
        ),
      );
    } catch (err) {
      _msg(err.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF9800))));
    }
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
                TextField(
                  controller: _pass,
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    labelText: 'Password (6+ chars)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPass ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                ),
                                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPass,
                      child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFFF9800))),
                    ),
                  ),

                  const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          _isLogin ? 'LOGIN' : 'SIGN UP',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'New Player? Sign Up' : 'Already have account? Login'),
                ),
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool get isAdmin => widget.email.toLowerCase() == kAdmin.toLowerCase();
  int _tab = 0, _wallet = 0;
  String _ign = 'Player', _bgmiId = 'Not Set', _upiId = 'skesports@upi', _qrUrl = '';
  bool _loading = true;
  List _matches = [], _txns = [], _deps = [], _withs = [], _users = [];
  final _upiC = TextEditingController(), _qrC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  int _num(dynamic v) => int.tryParse('$v') ?? 0;

  Future _sync() async {
    setState(() => _loading = true);
    try {
      final cRes = await http.get(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'));
      if (cRes.statusCode == 200 && cRes.body != 'null') {
        final c = jsonDecode(cRes.body);
        _upiId = c['upiId'] ?? 'skesports@upi';
        _qrUrl = c['qrUrl'] ?? '';
      }
      _upiC.text = _upiId;
      _qrC.text = _qrUrl;

      final uRes = await http.get(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'));
      if (uRes.statusCode == 200 && uRes.body != 'null') {
        final d = jsonDecode(uRes.body);
        _ign = d['ign'] ?? 'SK_Player';
        _bgmiId = d['bgmiId'] ?? 'Not Set';
        _wallet = _num(d['wallet']);
        if (d['txns'] is Map) {
          _txns = (d['txns'] as Map).values.toList().reversed.toList();
        }
      }

      final mRes = await http.get(Uri.parse('$kDbUrl/matches.json?auth=${widget.token}'));
      if (mRes.statusCode == 200 && mRes.body != 'null') {
        final list = [];
        (jsonDecode(mRes.body) as Map).forEach((k, v) {
          if (v is Map) {
            list.add({
              ...v,
              'id': k,
              'isJoined': v['players'] is Map && (v['players'] as Map).containsKey(widget.uid),
            });
          }
        });
        _matches = list;
      } else {
        final def = {'m1': {
            'title': 'SK ESPORTS Solo Rush #1',
            'map': 'Erangel',
            'mode': 'SOLO',
            'time': 'Today, 08:00 PM',
            'fee': 30,
            'kill': 20,
            'win': 175,
            'slots': 100,
            'joined': 0,
            'rId': '15 min before match',
            'rPass': '****',
          }
        };
        await http.put(Uri.parse('$kDbUrl/matches.json?auth=${widget.token}'), body: jsonEncode(def));
        _matches = [{'id': 'm1', ...def['m1']!, 'isJoined': false}];
      }

      if (isAdmin) {
        final dRes = await http.get(Uri.parse('$kDbUrl/deposits.json?auth=${widget.token}'));
        final deps = [];
        if (dRes.statusCode == 200 && dRes.body != 'null') {
          (jsonDecode(dRes.body) as Map).forEach((k, v) {
            if (v is Map && v['status'] == 'PENDING') deps.add({...v, 'id': k});
          });
        }
        _deps = deps.reversed.toList();

        final wRes = await http.get(Uri.parse('$kDbUrl/withdrawals.json?auth=${widget.token}'));
        final withs = [];
        if (wRes.statusCode == 200 && wRes.body != 'null') {
          (jsonDecode(wRes.body) as Map).forEach((k, v) {
            if (v is Map && (v['status'] ?? 'PENDING') == 'PENDING') {
              withs.add({...v, 'id': k});
            }
          });
        }
        _withs = withs.reversed.toList();

        final allRes = await http.get(Uri.parse('$kDbUrl/users.json?auth=${widget.token}'));
        final usrs = [];
        if (allRes.statusCode == 200 && allRes.body != 'null') {
          (jsonDecode(allRes.body) as Map).forEach((k, v) {
            if (v is Map) usrs.add({...v, 'uid': k});
          });
        }
        _users = usrs;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future _saveTxn(String uid, int bal, String title, String sub, int amt, String status) async {
    final now = DateTime.now();
    final dt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final t = {'title': title, 'sub': '$sub • $dt', 'amt': amt, 'status': status, 'time': dt};
    if (uid == widget.uid) setState(() => _txns.insert(0, t));
    await http.patch(Uri.parse('$kDbUrl/users/$uid.json?auth=${widget.token}'), body: jsonEncode({'wallet': bal}));
    await http.post(Uri.parse('$kDbUrl/users/$uid/txns.json?auth=${widget.token}'), body: jsonEncode(t));
  }
        void _showHistory([Map? player]) {
    final list = [];
    final target = player == null ? _users : [player];
    for (final u in target) {
      if (u['txns'] is Map) {
        (u['txns'] as Map).forEach((_, v) {
          if (v is Map) list.add({...v, 'ign': u['ign'] ?? 'Player'});
        });
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(player == null ? 'All Players History (${list.length})' : '${player['ign']} History (${list.length})', style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: list.isEmpty
              ? const Center(child: Text('Koi history nahi mili'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    return ListTile(
                      dense: true,
                      title: Text('${player == null ? '${t['ign']} • ' : ''}${t['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${t['sub'] ?? ''} • ${t['status'] ?? ''}', style: const TextStyle(fontSize: 11)),
                      trailing: Text('₹${t['amt']}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }


  void _join(Map m) {
    final ignC = TextEditingController(text: _ign),
        idC = TextEditingController(text: _bgmiId == 'Not Set' ? '' : _bgmiId);
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
              if (ignC.text.trim().isEmpty || !RegExp(r'^\d{8,}$').hasMatch(idC.text.trim())) {
                return _msg('Sahi IGN aur ID dalein!');
              }
              final fee = _num(m['fee']);
              if ((_wallet - fee).isNegative) {
                Navigator.pop(ctx);
                setState(() => _tab = 1);
                return _msg('Balance kam hai!');
              }
              final j = _num(m['joined']) + 1;
              setState(() {
                _ign = ignC.text.trim();
                _bgmiId = idC.text.trim();
                _wallet = _wallet - fee;
                m['joined'] = j;
                m['isJoined'] = true;
              });
              Navigator.pop(ctx);
              await http.patch(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'), body: jsonEncode({'ign': _ign, 'bgmiId': _bgmiId}));
              await _saveTxn(widget.uid, _wallet, 'Joined: ${m['title']}', 'IGN: $_ign', fee, 'PAID');
              await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'), body: jsonEncode({'joined': j}));
              await http.put(Uri.parse('$kDbUrl/matches/${m['id']}/players/${widget.uid}.json?auth=${widget.token}'), body: jsonEncode({'ign': _ign, 'bgmiId': _bgmiId}));
              _msg('Slot Confirmed!');
            },
            child: Text('Pay ₹${m['fee']}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deposit() {
        final amtC = TextEditingController(text: '50');

    final utrC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
                 final amt = int.tryParse(amtC.text.trim()) ?? 0;

          final autoQr = 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent('upi://pay?pa=$_upiId&pn=SK%20ESPORTS&am=$amt&cu=INR')}';
          final img = _qrUrl.trim().isNotEmpty ? _qrUrl.trim() : autoQr;
          return AlertDialog(
            title: const Text('Add Money (Scan & Pay)', style: TextStyle(fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                                TextField(
                controller: amtC,
                keyboardType: TextInputType.number,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(labelText: 'Enter Amount (₹)', border: OutlineInputBorder()),
              ),

                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    img,
                    height: 150,
                    width: 150,
                    errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 120, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _upiId));
                    _msg('UPI Copied!');
                  },
                  child: Text(
                    'UPI: $_upiId (Tap Copy)',
                    style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(controller: utrC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '12-Digit UTR Number', border: OutlineInputBorder())),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                onPressed: () async {
                                              if (amt < 10) {
                          return _msg('Kam se kam ₹10 dalein!');
                                              }

                                          final utr = utrC.text.trim();
                        if (!RegExp(r'^\d{12}$').hasMatch(utr)) {
                          return _msg('Sahi 12-Digit UTR dalein!');
                        }
                        final chk = await http.get(Uri.parse('$kDbUrl/deposits.json?auth=${widget.token}'));
                        if (chk.statusCode == 200 && chk.body != 'null') {
                          final allDeps = jsonDecode(chk.body) as Map<String, dynamic>;
                          if (allDeps.values.any((d) => d is Map && d['utr']?.toString() == utr && d['status'] != 'REJECTED')) {
                            return _msg('Ye UTR pehle hi use ho chuka hai!');
                          }
                        }

                  Navigator.pop(ctx);
                  await _saveTxn(widget.uid, _wallet, 'Deposit Request', 'UTR: ${utrC.text.trim()}', amt, 'PENDING');
                  await http.post(
                    Uri.parse('$kDbUrl/deposits.json?auth=${widget.token}'),
                    body: jsonEncode({
                      'uid': widget.uid,
                      'ign': _ign,
                      'amt': amt,
                      'utr': utrC.text.trim(),
                      'status': 'PENDING',
                    }),
                  );
                  _msg('UTR Submitted! Admin verify karte hi add hoga.');
                },
                child: const Text('Submit UTR', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          TextField(controller: upiC, decoration: const InputDecoration(labelText: 'Your UPI ID', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Min ₹50)', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              final v = _num(amtC.text.trim());
              if (!upiC.text.contains('@') || (v - 50).isNegative || (_wallet - v).isNegative) {
                return _msg('Valid UPI aur balance check karein!');
              }
              setState(() => _wallet = _wallet - v);
              Navigator.pop(ctx);
              await _saveTxn(widget.uid, _wallet, 'UPI Withdrawal', upiC.text.trim(), v, 'PENDING');
              await http.post(
                Uri.parse('$kDbUrl/withdrawals.json?auth=${widget.token}'),
                body: jsonEncode({'uid': widget.uid,
                  'ign': _ign,
                  'upi': upiC.text.trim(),
                  'amt': v,
                  'status': 'PENDING',
                }),
              );
              _msg('Withdrawal Sent!');
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editRoom(Map m) {
    final idC = TextEditingController(text: '${m['rId']}'),
        passC = TextEditingController(text: '${m['rPass']}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Room ID & Pass', style: TextStyle(fontSize: 15)),
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
              setState(() {
                m['rId'] = idC.text.trim();
                m['rPass'] = passC.text.trim();
              });
              Navigator.pop(ctx);
              await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'), body: jsonEncode({'rId': m['rId'], 'rPass': m['rPass']}));
              _msg('Room Updated!');
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

    void _addMatch() {
    final tC = TextEditingController(),
        mapC = TextEditingController(text: 'Erangel'),
        modeC = TextEditingController(text: 'SOLO'),
        timeC = TextEditingController(text: 'Today, 08:30 PM'),
        feeC = TextEditingController(text: '30'),
        killC = TextEditingController(text: '20'),
        winC = TextEditingController(text: '175');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Match', style: TextStyle(fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: tC, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: mapC, decoration: const InputDecoration(labelText: 'Map (Erangel/Miramar/Vikendi/Livik)')),
            TextField(controller: modeC, decoration: const InputDecoration(labelText: 'Mode (SOLO/SQUAD)')),
            TextField(controller: timeC, decoration: const InputDecoration(labelText: 'Time')),
            TextField(controller: feeC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Entry Fee')),
            TextField(controller: killC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per Kill')),
            TextField(controller: winC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chicken Dinner Prize')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              if (tC.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('$kDbUrl/matches.json?auth=${widget.token}'),
                body: jsonEncode({
                  'title': tC.text.trim(),
                  'map': mapC.text.trim(),
                  'mode': modeC.text.trim(),
                  'time': timeC.text.trim(),
                  'fee': _num(feeC.text),
                  'kill': _num(killC.text),
                  'win': _num(winC.text),
                  'slots': mapC.text.trim().toLowerCase().contains('livik') ? 52 : 100,
                              'joined': 0,
            'rId': '15 min before match',
            'rPass': '****',


                }),
              );
              _msg('Match Live!');
              _sync();
            },
            child: const Text('Publish', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendPrize(Map u) {
    final amtC = TextEditingController(), noteC = TextEditingController(text: 'Winning Prize');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send Prize to ${u['ign']}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
          TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              final add = _num(amtC.text);
              if (add == 0) return;
              Navigator.pop(ctx);
              await _saveTxn('${u['uid']}', _num(u['wallet']) + add, noteC.text.trim(), 'SK ESPORTS Admin', add, 'CREDITED');
              _msg('₹$add Sent!');
              _sync();
            },
            child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  void _showPlayers(Map m) {
    final pMap = m['players'] is Map ? m['players'] as Map : {};
    final list = pMap.entries.toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Players (${list.length}/${m['slots']})', style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? const Text('Abhi kisi ne join nahi kiya hai.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final uid = list[i].key.toString();
                    final p = list[i].value is Map ? list[i].value as Map : {};
                    final u = _users.firstWhere(
                      (x) => x['uid'] == uid,
                      orElse: () => {'uid': uid, 'ign': p['ign'] ?? 'Player', 'wallet': 0},
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${i + 1}. ${p['ign'] ?? u['ign'] ?? 'Player'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('ID: ${p['bgmiId'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), padding: const EdgeInsets.symmetric(horizontal: 10)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendPrize(u);
                        },
                        child: const Text('Send Prize', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _matches.length,
        itemBuilder: (_, i) {
          final m = _matches[i],
              joined = m['isJoined'] == true,
              isFull = _num(m['joined']) >= _num(m['slots']);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(
                      '${m['title']} (${m['map']} • ${m['mode']})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        await http.delete(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'));
                        _sync();
                      },
                    ),
                ]),
                Text(
                  'Time: ${m['time']} | Entry: ₹${m['fee']} | Kill: ₹${m['kill']} | Win: ₹${m['win']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (joined || isAdmin) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      'Room: ${m['rId']} | Pass: ${m['rPass']}',
                      style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFFFF9800)),
                        onPressed: () => _editRoom(m),
                      ),
                  ]),
                ],
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

                                       if (isAdmin)
                        OutlinedButton(
                          onPressed: () => _showPlayers(m),
                          child: const Text('Players', style: TextStyle(color: Color(0xFFFF9800))),
                        ),

                      Text('${m['joined']}/${m['slots']} Joined', style: const TextStyle(color: Colors.grey)),
                  ElevatedButton( 

                    style: ElevatedButton.styleFrom(
                      backgroundColor: joined ? const Color(0xFF00E676) : const Color(0xFFFF9800),
                    ),
                    onPressed: (joined || isFull) ? null : () => _join(m),
                    child: Text(
                      joined ? 'JOINED ✓' : (isFull ? 'FULL' : 'Join ₹${m['fee']}'),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
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
          Card(
            child: ListTile(
              title: const Text('Wallet Balance'),
              trailing: Text(
                '₹$_wallet',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
              ),
            ),
          ),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
        onPressed: _deposit,
                child: const Text('Add Money', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: _withdraw, child: const Text('Withdraw'))),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _txns.length,
              itemBuilder: (_, i) => ListTile(
                title: Text('${_txns[i]['title']}'),
                subtitle: Text('${_txns[i]['sub']} • ${_txns[i]['status']}'),
                trailing: Text('₹${_txns[i]['amt']}'),
              ),
            ),
          ),
        ]),
      ),
      ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(title: Text(_ign), subtitle: Text('BGMI ID: $_bgmiId\n${widget.email}'))),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text('RULES:\n• BGMI Level 30+ ID required.\n• Room ID & Pass 15 min pehle milega.'),
          ),
        ),
        ElevatedButton(
                                onPressed: () async {
                        final url = Uri.parse('https://t.me/SK_ESPORTSOFFICIAL');
                        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                          Clipboard.setData(const ClipboardData(text: 'https://t.me/SK_ESPORTSOFFICIAL'));
                          _msg('Telegram Copied!');
                        }
                      },

          child: const Text('Join Telegram (@SK_ESPORTSOFFICIAL)'),
        ),
                OutlinedButton(
          onPressed: () async {
            await (await SharedPreferences.getInstance()).clear();
            if (!context.mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
          },
          child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
        ),

      ]),
      if (isAdmin)
        ListView(padding: const EdgeInsets.all(14), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CHANGE PAYMENT QR & UPI', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                const SizedBox(height: 8),
                TextField(controller: _upiC, decoration: const InputDecoration(labelText: 'Your UPI ID (Auto QR)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: _qrC, decoration: const InputDecoration(labelText: 'Custom QR Image URL (Optional)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), minimumSize: const Size.fromHeight(42)),
                  onPressed: () async {
                    _upiId = _upiC.text.trim();
                    _qrUrl = _qrC.text.trim();
                    await http.put(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'), body: jsonEncode({'upiId': _upiId, 'qrUrl': _qrUrl}));
                    _msg('New Payment QR Live!');
                  },
                  child: const Text('Update QR Live', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('Create New Match', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: _addMatch,
          ),
          const SizedBox(height: 12),
                  Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF00E676)),
            title: Text('Pending UTR Deposits (${_deps.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Tap karke Approve / Reject karein', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Pending UTR Deposits (${_deps.length})', style: const TextStyle(fontSize: 15)),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 350,
                  child: _deps.isEmpty
                      ? const Center(child: Text('Koi pending deposit nahi hai'))
                      : ListView.builder(
                          itemCount: _deps.length,
                          itemBuilder: (_, i) {
                            final d = _deps[i];
                            return Card(
                              child: ListTile(
                                title: Text('${d['ign']} • ₹${d['amt']}'),
                                subtitle: Text('UTR: ${d['utr']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Color(0xFF00E676)),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        final u = _users.firstWhere((e) => e['uid'] == d['uid'], orElse: () => {});
                                        if (u.isNotEmpty) {
                                          await _saveTxn('${d['uid']}', _num(u['wallet']) + _num(d['amt']), 'Wallet Deposit', 'UTR: ${d['utr']}', _num(d['amt']), 'APPROVED');
                                        }
                                        await http.patch(Uri.parse('$kDbUrl/deposits/${d['id']}.json?auth=${widget.token}'), body: jsonEncode({'status': 'APPROVED'}));
                                        _msg('Approved!');
                                        _sync();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await http.patch(Uri.parse('$kDbUrl/deposits/${d['id']}.json?auth=${widget.token}'), body: jsonEncode({'status': 'REJECTED'}));
                                        _sync();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments, color: Color(0xFFFF9800)),
            title: Text('Pending Withdrawals (${_withs.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Tap karke UPI copy aur Paid mark karein', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Pending Withdrawals (${_withs.length})', style: const TextStyle(fontSize: 15)),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 350,
                  child: _withs.isEmpty
                      ? const Center(child: Text('Koi pending withdrawal nahi hai'))
                      : ListView.builder(
                          itemCount: _withs.length,
                          itemBuilder: (_, i) {
                            final wd = _withs[i];
                            return Card(
                              child: ListTile(
                                title: Text('${wd['ign']} • ₹${wd['amt']}'),
                                subtitle: Text('UPI: ${wd['upi']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, color: Colors.lightBlueAccent),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: '${wd['upi']}'));
                                        _msg('Player UPI Copied!');
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Color(0xFF00E676)),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await http.patch(Uri.parse('$kDbUrl/withdrawals/${wd['id']}.json?auth=${widget.token}'), body: jsonEncode({'status': 'PAID'}));
                                        final tRes = await http.get(Uri.parse('$kDbUrl/users/${wd['uid']}/txns.json?auth=${widget.token}'));
                                        if (tRes.statusCode == 200 && tRes.body != 'null') {
                                          final tMap = jsonDecode(tRes.body) as Map<String, dynamic>;
                                          for (final e in tMap.entries.toList().reversed) {

                                            if (e.value is Map && e.value['title'] == 'UPI Withdrawal' && e.value['status'] == 'PENDING' && _num(e.value['amt']) == _num(wd['amt'])) {
                                              await http.patch(Uri.parse('$kDbUrl/users/${wd['uid']}/txns/${e.key}.json?auth=${widget.token}'), body: jsonEncode({'status': 'SUCCESS'}));
                                              break;
                                            }
                                          }
                                        }
                                        _msg('Marked as Paid!');
                                        _sync();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ),
            ),
          ),
        ),


          const SizedBox(height: 12),
                  Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('PLAYERS (History & Prize)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
            TextButton.icon(
              onPressed: () => _showHistory(),
              icon: const Icon(Icons.history, size: 18, color: Color(0xFFFF9800)),
              label: const Text('All History', style: TextStyle(color: Color(0xFFFF9800))),
            ),
          ],
        ),
        ..._users.map((u) => Card(
              child: ListTile(
                title: Text('${u['ign']} (₹${u['wallet']})'),
                subtitle: Text('${u['email']} • ID: ${u['bgmiId']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.history, color: Colors.lightBlueAccent), onPressed: () => _showHistory(u)),
                    IconButton(icon: const Icon(Icons.emoji_events, color: Color(0xFFFF9800)), onPressed: () => _sendPrize(u)),
                  ],
                ),
              ),
            )),

    ]),
]; 
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('SK ESPORTS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _sync),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '₹$_wallet',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676), fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : pages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tab,
        selectedItemColor: const Color(0xFFFF9800),
        onTap: (i) => setState(() => _tab = i),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Matches'),
          const BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          if (isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
    );
  }
}
