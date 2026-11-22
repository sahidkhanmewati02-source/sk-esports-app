import 'dart:async';
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
  bool get isSuperAdmin => widget.email.toLowerCase() == kAdmin.toLowerCase();
  bool _isCoAdmin = false;
  bool get isAdmin => isSuperAdmin || _isCoAdmin;
  int _tab = 0, _wallet = 0;
  String _ign = 'Player', _bgmiId = 'Not Set', _upiId = 'skesports@upi', _qrUrl = '';
  String _joinAdUrl = 'https://example.com', _roomAdUrl = 'https://example.com';
  String _promoImageUrl = '', _promoClickUrl = '';
  bool _promoEnabled = false;
  bool _loading = true;
  String _superAdminUid = '';
  DateTime _clock = DateTime.now();
  Timer? _matchTicker;
  List _matches = [], _txns = [], _deps = [], _withs = [], _users = [], _chatMessages = [], _aboutLinks = [];
  String _rulesText = 'BGMI Level 30+ ID required.\nRoom ID & Password match se 15 minute pehle milega.\nChat mein abuse, spam aur personal details share na karein.\nEntry fee aur withdrawal ke liye sahi UTR/UPI details dein.';
  final _chatC = TextEditingController(), _aboutLinksC = TextEditingController(), _rulesC = TextEditingController();
  final _upiC = TextEditingController(), _qrC = TextEditingController();
  final _joinAdUrlController = TextEditingController(text: 'https://example.com');
  final _roomAdUrlController = TextEditingController(text: 'https://example.com');
  final _promoImageUrlController = TextEditingController();
  final _promoClickUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _matchTicker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _clock = DateTime.now()); });
    _sync();
  }

  @override
  void dispose() {
    _matchTicker?.cancel();
    _upiC.dispose(); _qrC.dispose(); _joinAdUrlController.dispose(); _roomAdUrlController.dispose(); _promoImageUrlController.dispose(); _promoClickUrlController.dispose();
    _chatC.dispose(); _aboutLinksC.dispose(); _rulesC.dispose();
    super.dispose();
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
        _joinAdUrl = c['joinAdUrl'] ?? 'https://example.com';
        _roomAdUrl = c['roomAdUrl'] ?? 'https://example.com';
        _promoImageUrl = c['promoImageUrl'] ?? '';
        _promoClickUrl = c['promoClickUrl'] ?? '';
        _promoEnabled = c['promoEnabled'] == true;
        _superAdminUid = '${c['superAdminUid'] ?? ''}';
        _joinAdUrlController.text = _joinAdUrl;
        _roomAdUrlController.text = _roomAdUrl;
        _promoImageUrlController.text = _promoImageUrl;
        _promoClickUrlController.text = _promoClickUrl;
      }
      if (isSuperAdmin) {
        _superAdminUid = widget.uid;
        await http.patch(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'), body: jsonEncode({'superAdminUid': widget.uid}));
      }
      _upiC.text = _upiId;
      _qrC.text = _qrUrl;

      final uRes = await http.get(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'));
      if (uRes.statusCode == 200 && uRes.body != 'null') {
        final d = jsonDecode(uRes.body);
        _ign = d['ign'] ?? 'SK_Player';
        _bgmiId = d['bgmiId'] ?? 'Not Set';
        _wallet = _num(d['wallet']);
        _isCoAdmin = !isSuperAdmin && d['role'] == 'coadmin';
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
        final chatRes = await http.get(Uri.parse('$kDbUrl/chat.json?auth=${widget.token}'));
        final chats = <Map>[];
        if (chatRes.statusCode == 200 && chatRes.body != 'null') (jsonDecode(chatRes.body) as Map).forEach((k, v) { if (v is Map) chats.add({...v, 'id': k}); });
        _chatMessages = chats;
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
      } else {
        final chatRes = await http.get(Uri.parse('$kDbUrl/chat.json?auth=${widget.token}'));
        final chats = <Map>[];
        if (chatRes.statusCode == 200 && chatRes.body != 'null') (jsonDecode(chatRes.body) as Map).forEach((k, v) { if (v is Map) chats.add({...v, 'id': k}); });
        _chatMessages = chats;
      }
      final cfgRes = await http.get(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'));
      if (cfgRes.statusCode == 200 && cfgRes.body != 'null') {
        final cfg = jsonDecode(cfgRes.body);
        _aboutLinks = cfg['aboutLinks'] is List ? List.from(cfg['aboutLinks']) : [{'label':'Support DM','url':'https://t.me/SK_EsportsSupport'},{'label':'Official Telegram','url':'https://t.me/SK_ESPORTSOFFICIAL'},{'label':'YouTube - SK Sahid YT','url':'https://youtube.com/@sk_sahidyt'},{'label':'Instagram','url':'https://www.instagram.com/'}];
        _rulesText = cfg['rulesText']?.toString() ?? _rulesText;
      } else if (_aboutLinks.isEmpty) {
        _aboutLinks = [{'label':'Support DM','url':'https://t.me/SK_EsportsSupport'},{'label':'Official Telegram','url':'https://t.me/SK_ESPORTSOFFICIAL'},{'label':'YouTube - SK Sahid YT','url':'https://youtube.com/@sk_sahidyt'},{'label':'Instagram','url':'https://www.instagram.com/'}];
      }
      _aboutLinksC.text = _aboutLinks.map((e) => e['label'].toString() + ' | ' + e['url'].toString()).join('\n');
      _rulesC.text = _rulesText;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future _saveTxn(String uid, int bal, String title, String sub, int amt, String status) async {
    final now = DateTime.now();
    final dt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final t = {'title': title, 'sub': '$sub • $dt', 'amt': amt, 'status': status, 'time': dt};
    if (uid == widget.uid) setState(() => _txns.insert(0, t));
    final walletRes = await http.patch(Uri.parse('$kDbUrl/users/$uid.json?auth=${widget.token}'), body: jsonEncode({'wallet': bal}));
    if (walletRes.statusCode < 200 || walletRes.statusCode >= 300) throw Exception('Wallet update failed (${walletRes.statusCode}). Firebase Rules check karein.');
    final txnRes = await http.post(Uri.parse('$kDbUrl/users/$uid/txns.json?auth=${widget.token}'), body: jsonEncode(t));
    if (txnRes.statusCode < 200 || txnRes.statusCode >= 300) throw Exception('Transaction history save nahi hui (${txnRes.statusCode}).');
  }

  bool _matchClosed(Map m) { final c = _num(m['closeAt']); return m['status'] == 'CLOSED' || (c > 0 && _clock.millisecondsSinceEpoch >= c); }
  bool _roomAvailable(Map m) { final r = _num(m['roomReleaseAt']); return m['hold'] != true && (r <= 0 || _clock.millisecondsSinceEpoch >= r); }
  String _timeLabel(dynamic raw) { final ms = _num(raw); if (ms <= 0) return 'Not set'; final d = DateTime.fromMillisecondsSinceEpoch(ms); return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }

  void _editMatchTiming(Map m) {
    String fmt(int ms) { final d = DateTime.fromMillisecondsSinceEpoch(ms); return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }
    final now = DateTime.now();
    final startC = TextEditingController(text: fmt(_num(m['startAt']) > 0 ? _num(m['startAt']) : now.add(const Duration(hours: 1)).millisecondsSinceEpoch));
    final closeC = TextEditingController(text: fmt(_num(m['closeAt']) > 0 ? _num(m['closeAt']) : now.add(const Duration(hours: 1)).millisecondsSinceEpoch));
    final roomC = TextEditingController(text: fmt(_num(m['roomReleaseAt']) > 0 ? _num(m['roomReleaseAt']) : now.add(const Duration(minutes: 45)).millisecondsSinceEpoch));
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Match Timer & Room Release'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: startC, decoration: const InputDecoration(labelText: 'Match start (YYYY-MM-DD HH:MM)')), TextField(controller: closeC, decoration: const InputDecoration(labelText: 'Join auto-close (YYYY-MM-DD HH:MM)')), TextField(controller: roomC, decoration: const InputDecoration(labelText: 'Room ID release (YYYY-MM-DD HH:MM)')), const Text('24-hour local time format use karein.', style: TextStyle(fontSize: 11, color: Colors.grey))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () async {
      DateTime? parse(String v) => DateTime.tryParse(v.trim().replaceFirst(' ', 'T'));
      final st = parse(startC.text), cl = parse(closeC.text), rm = parse(roomC.text);
      if (st == null || cl == null || rm == null) return _msg('Date/time format sahi dalein.');
      final data = {'startAt': st.millisecondsSinceEpoch, 'closeAt': cl.millisecondsSinceEpoch, 'roomReleaseAt': rm.millisecondsSinceEpoch, 'time': fmt(st.millisecondsSinceEpoch)};
      final res = await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'), body: jsonEncode(data));
      if (res.statusCode >= 200 && res.statusCode < 300) { m.addAll(data); if (mounted) setState(() {}); Navigator.pop(ctx); _msg('Match timer update ho gaya.'); } else { _msg('Timer save nahi hua. Firebase Rules check karein.'); }
    }, child: const Text('Save Timer'))]));
  }

  Future<void> _toggleMatchHold(Map m) async {
    final hold = m['hold'] != true;
    final res = await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'), body: jsonEncode({'hold': hold}));
    if (res.statusCode >= 200 && res.statusCode < 300) { setState(() => m['hold'] = hold); _msg(hold ? 'Match HOLD par hai; room release ruk gaya.' : 'Match resume kar diya.'); } else { _msg('Hold status save nahi hua.'); }
  }
  void _showAllPlayersDialog() {
    final searchC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = searchC.text.trim().toLowerCase();
          final filtered = _users.where((u) {
            final ign = '${u['ign'] ?? ''}'.toLowerCase();
            final email = '${u['email'] ?? ''}'.toLowerCase();
            final bgmiId = '${u['bgmiId'] ?? ''}'.toLowerCase();
            return q.isEmpty || ign.contains(q) || email.contains(q) || bgmiId.contains(q);
          }).toList();
          return AlertDialog(
            title: Text('All Players (${_users.length})', style: const TextStyle(fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchC,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search Name, Email or BGMI ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Koi player nahi mila'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final u = filtered[i];
                              return Card(
                                child: ListTile(
                                  dense: true,
                                  title: Text('${u['ign'] ?? 'Player'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${u['email'] ?? '-'}\nBGMI ID: ${u['bgmiId'] ?? '-'}'),
                                  trailing: Wrap(
                                    spacing: 0,
                                    children: [
                                      IconButton(
                                        tooltip: 'History',
                                        icon: const Icon(Icons.history, color: Colors.lightBlueAccent),
                                        onPressed: () => _showHistory(u),
                                      ),
                                      IconButton(
                                        tooltip: 'Send Prize',
                                        icon: const Icon(Icons.emoji_events, color: Color(0xFFFF9800)),
                                        onPressed: () => _sendPrize(u),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
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


  Future<void> _showTimedAd({required String title, required String url, required int seconds, required VoidCallback onContinue}) async {
    var remaining = seconds;
    var finished = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (!finished && remaining == seconds) {
            Future.doWhile(() async {
              await Future.delayed(const Duration(seconds: 1));
              if (!ctx.mounted || finished) return false;
              setS(() => remaining--);
              if (remaining <= 0) { finished = true; setS(() {}); return false; }
              return true;
            });
          }
          return AlertDialog(
            title: Text(title),
            content: Text(finished ? 'Continue karne ke liye button dabayein.' : 'Please wait $remaining seconds...'),
            actions: [
              ElevatedButton(
                onPressed: finished ? () async {
                  Navigator.pop(ctx);
                  final uri = Uri.tryParse(url);
                  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
                  }
                  onContinue();
                } : null,
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startJoinAd(Map m) {
    _showTimedAd(title: 'Sponsored Link', url: _joinAdUrl, seconds: 10, onContinue: () => _join(m));
  }

  void _showRoomAfterAd(Map m) {
    _showTimedAd(title: 'Room Details', url: _roomAdUrl, seconds: 5, onContinue: () {
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Match Room Details'),
        content: SelectableText('Room ID: ${m['rId']}\\nPassword: ${m['rPass']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    });
  }

  void _saveAdAndPromoConfig() async {
    _joinAdUrl = _joinAdUrlController.text.trim();
    _roomAdUrl = _roomAdUrlController.text.trim();
    _promoImageUrl = _promoImageUrlController.text.trim();
    _promoClickUrl = _promoClickUrlController.text.trim();
    final data = {
      'joinAdUrl': _joinAdUrl,
      'roomAdUrl': _roomAdUrl,
      'promoImageUrl': _promoImageUrl,
      'promoClickUrl': _promoClickUrl,
      'promoEnabled': _promoEnabled,
    };
    final res = await http.patch(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'), body: jsonEncode(data));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _msg('Ad & Promo settings saved!');
      if (mounted) setState(() {});
    } else {
      _msg('Settings save nahi hui. Firebase permission check karein.');
    }
  }

  Future<void> _loadChat() async {
    final res = await http.get(Uri.parse('$kDbUrl/chat.json?auth=' + widget.token));
    if (res.statusCode == 200) {
      final list = <Map>[];
      if (res.body != 'null') (jsonDecode(res.body) as Map).forEach((k, v) { if (v is Map) list.add({...v, 'id': k}); });
      list.sort((a,b) { final p = (b['pinned'] == true ? 1 : 0).compareTo(a['pinned'] == true ? 1 : 0); return p != 0 ? p : _num(a['createdAt']).compareTo(_num(b['createdAt'])); });
      if (mounted) setState(() => _chatMessages = list);
    }
  }
  Future<void> _sendChat() async {
    final msg = _chatC.text.trim();
    if (msg.isEmpty) return;
    final modRes = await http.get(Uri.parse('$kDbUrl/chatModeration/' + widget.uid + '.json?auth=' + widget.token));
    final mod = modRes.statusCode == 200 && modRes.body != 'null' ? jsonDecode(modRes.body) as Map : <String,dynamic>{};
    final until = _num(mod['muteUntil']);
    if (until > DateTime.now().millisecondsSinceEpoch) return _msg('Aap muted hain. ' + (((until - DateTime.now().millisecondsSinceEpoch) / 60000).ceil()).toString() + ' minute baad try karein.');
    final privileged = isAdmin;
    final hasLink = RegExp(r'(https?://|www\.|t\.me/|discord\.gg/|chat\.whatsapp\.com/)', caseSensitive: false).hasMatch(msg);
    if (!privileged && hasLink) return _msg('Players chat mein links/invites allowed nahi hain.');
    final badWords = ['fuck','shit','bitch','asshole','madarchod','bhenchod','behenchod','chutiya','gandu','harami','randi','mc','bc'];
    final found = !privileged && badWords.any((w) => RegExp('(^|[^a-z])' + RegExp.escape(w) + '([^a-z]|$)', caseSensitive:false).hasMatch(msg));
    if (found) {
      final strikes = _num(mod['strikes']) + 1;
      final muteMs = strikes == 2 ? 15 * 60 * 1000 : (strikes >= 3 ? 2 * 60 * 60 * 1000 : 0);
      await http.patch(Uri.parse('$kDbUrl/chatModeration/' + widget.uid + '.json?auth=' + widget.token), body: jsonEncode({'strikes': strikes, 'muteUntil': muteMs == 0 ? 0 : DateTime.now().millisecondsSinceEpoch + muteMs}));
      if (strikes == 1) return _msg('Warning 1/3: abusive language allowed nahi hai.');
      if (strikes == 2) return _msg('2nd violation: 15 minute mute laga diya gaya.');
      return _msg('3rd violation: 2 ghante ka mute laga diya gaya.');
    }
    final data = {'uid': widget.uid, 'ign': _ign, 'email': widget.email, 'message': msg, 'createdAt': DateTime.now().millisecondsSinceEpoch, 'pinned': false, 'role': isSuperAdmin ? 'superadmin' : (_isCoAdmin ? 'coadmin' : 'player')};
    final res = await http.post(Uri.parse('$kDbUrl/chat.json?auth=' + widget.token), body: jsonEncode(data));
    if (res.statusCode >= 200 && res.statusCode < 300) { _chatC.clear(); await _loadChat(); } else { _msg('Message send nahi hua. Firebase Rules check karein.'); }
  }
  Future<void> _chatAction(Map m, String action) async {
    final path = '$kDbUrl/chat/' + m['id'].toString() + '.json?auth=' + widget.token;
    final res = action == 'delete' ? await http.delete(Uri.parse(path)) : await http.patch(Uri.parse(path), body: jsonEncode({'pinned': m['pinned'] != true}));
    if (res.statusCode >= 200 && res.statusCode < 300) await _loadChat(); else _msg('Chat action failed. Firebase Rules check karein.');
  }
  Widget _chatPage() {
    final sorted = [..._chatMessages]..sort((a,b) { final p = (b['pinned'] == true ? 1 : 0).compareTo(a['pinned'] == true ? 1 : 0); return p != 0 ? p : _num(a['createdAt']).compareTo(_num(b['createdAt'])); });
    return Column(children: [
      Padding(padding: const EdgeInsets.all(10), child: Row(children: [const Expanded(child: Text('SK ESPORTS Community Chat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800)))), IconButton(onPressed: _loadChat, icon: const Icon(Icons.refresh))])),
      Expanded(child: sorted.isEmpty ? const Center(child: Text('Abhi chat khaali hai. Pehla message bhejein!')) : ListView.builder(itemCount: sorted.length, itemBuilder: (_, i) {
        final m = sorted[i];
        final ign = m['ign']?.toString() ?? 'Player';
        return Card(child: ListTile(
          leading: CircleAvatar(child: Text(ign.isNotEmpty ? ign[0].toUpperCase() : 'P')),
          title: Row(children: [Expanded(child: Text(ign, style: const TextStyle(fontWeight: FontWeight.bold))), if (m['pinned'] == true) const Icon(Icons.push_pin, color: Colors.amber, size: 16)]),
          subtitle: Text(m['message']?.toString() ?? ''),
          trailing: isAdmin ? PopupMenuButton<String>(onSelected: (v) => _chatAction(m, v), itemBuilder: (_) => [PopupMenuItem(value: 'pin', child: Text(m['pinned'] == true ? 'Unpin' : 'Pin')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]) : null,
        ));
      })),
      SafeArea(child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: TextField(controller: _chatC, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Message as BGMI IGN', border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton(onPressed: _sendChat, icon: const Icon(Icons.send, color: Color(0xFFFF9800)))]))),
    ]);
  }
  Future<void> _saveAboutRules() async {
    final links = <Map<String,String>>[];
    for (final line in _aboutLinksC.text.split('\n')) {
      final parts = line.split('|');
      if (parts.length < 2) continue;
      final label = parts.first.trim(), url = parts.sublist(1).join('|').trim();
      if (label.isNotEmpty && (url.startsWith('https://') || url.startsWith('http://')) && Uri.tryParse(url) != null) links.add({'label': label, 'url': url});
    }
    final res = await http.patch(Uri.parse('$kDbUrl/config.json?auth=' + widget.token), body: jsonEncode({'aboutLinks': links, 'rulesText': _rulesC.text.trim()}));
    if (res.statusCode >= 200 && res.statusCode < 300) { setState(() { _aboutLinks = links; _rulesText = _rulesC.text.trim(); }); _msg('About & Rules save ho gaye.'); } else _msg('About & Rules save nahi hue. Firebase Rules check karein.');
  }
  Future<void> _toggleCoAdmin(Map user) async {
    if (!isSuperAdmin || user['email']?.toString().toLowerCase() == kAdmin.toLowerCase()) return;
    final make = user['role'] != 'coadmin';
    final res = await http.patch(Uri.parse('$kDbUrl/users/' + user['uid'].toString() + '.json?auth=' + widget.token), body: jsonEncode({'role': make ? 'coadmin' : 'player'}));
    if (res.statusCode >= 200 && res.statusCode < 300) { _msg(make ? 'Co-Admin bana diya.' : 'Co-Admin role hata diya.'); _sync(); } else _msg('Role update nahi hua. Firebase Rules check karein.');
  }
  Widget _roleManagementCard() => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('CO-ADMIN MANAGEMENT', style: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    ..._users.where((u) => u['email']?.toString().toLowerCase() != kAdmin.toLowerCase()).map((u) => ListTile(dense: true, title: Text(u['ign']?.toString() ?? 'Player'), subtitle: Text(u['email']?.toString() ?? ''), trailing: TextButton(onPressed: () => _toggleCoAdmin(u), child: Text(u['role'] == 'coadmin' ? 'Remove' : 'Make Co-Admin')))),
  ])));
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
              if (_matchClosed(m) || _num(m['joined']) >= _num(m['slots'])) { Navigator.pop(ctx); return _msg('Join band ho chuka hai ya slots full hain.'); }
              final fee = _num(m['fee']);
              if ((_wallet - fee).isNegative) {
                Navigator.pop(ctx);
                setState(() => _tab = 1);
                return _msg('Balance kam hai!');
              }
              if (_superAdminUid.isEmpty) { Navigator.pop(ctx); return _msg('Super Admin wallet setup nahi hua. Admin ek baar app open karke refresh karein.'); }
              final j = _num(m['joined']) + 1;
              final oldBalance = _wallet;
              Navigator.pop(ctx);
              try {
                final aRes = await http.get(Uri.parse('$kDbUrl/users/$_superAdminUid.json?auth=${widget.token}'));
                if (aRes.statusCode != 200 || aRes.body == 'null') throw Exception('Super Admin wallet read nahi hua.');
                final aData = jsonDecode(aRes.body) as Map;
                final aBalance = _num(aData['wallet']);
                final playerBalance = oldBalance - fee;
                final pRes = await http.patch(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'), body: jsonEncode({'wallet': playerBalance, 'ign': ignC.text.trim(), 'bgmiId': idC.text.trim()}));
                if (pRes.statusCode < 200 || pRes.statusCode >= 300) throw Exception('Player wallet update fail hua.');
                final cRes = await http.patch(Uri.parse('$kDbUrl/users/$_superAdminUid.json?auth=${widget.token}'), body: jsonEncode({'wallet': aBalance + fee}));
                if (cRes.statusCode < 200 || cRes.statusCode >= 300) {
                  await http.patch(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'), body: jsonEncode({'wallet': oldBalance}));
                  throw Exception('Super Admin wallet credit fail hua; player fee refund kar di gayi.');
                }
                await _saveTxn(widget.uid, playerBalance, 'Joined: ${m['title']}', 'Entry fee paid to SK ESPORTS', fee, 'PAID');
                await _saveTxn(_superAdminUid, aBalance + fee, 'Entry Fee Received', '${ignC.text.trim()} • ${m['title']}', fee, 'CREDITED');
                final mr = await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'), body: jsonEncode({'joined': j}));
                final pr = await http.put(Uri.parse('$kDbUrl/matches/${m['id']}/players/${widget.uid}.json?auth=${widget.token}'), body: jsonEncode({'ign': ignC.text.trim(), 'bgmiId': idC.text.trim(), 'joinedAt': DateTime.now().millisecondsSinceEpoch, 'feePaid': fee}));
                if (mr.statusCode < 200 || mr.statusCode >= 300 || pr.statusCode < 200 || pr.statusCode >= 300) throw Exception('Fee transfer ho gayi, par match registration save nahi hui. Dobara payment na karein; Admin se contact karein.');
                if (mounted) setState(() { _ign = ignC.text.trim(); _bgmiId = idC.text.trim(); _wallet = playerBalance; m['joined'] = j; m['isJoined'] = true; });
                _msg('Slot Confirmed! Entry fee Super Admin wallet mein credit ho gayi.');
              } catch (err) { _msg(err.toString().replaceAll('Exception: ', '')); _sync(); }
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
        winC = TextEditingController(text: '175'),
        startC = TextEditingController(text: DateTime.now().add(const Duration(hours: 1)).toIso8601String().substring(0, 16).replaceFirst('T', ' ')),
        closeC = TextEditingController(text: DateTime.now().add(const Duration(hours: 1)).toIso8601String().substring(0, 16).replaceFirst('T', ' ')),
        roomC = TextEditingController(text: DateTime.now().add(const Duration(minutes: 45)).toIso8601String().substring(0, 16).replaceFirst('T', ' '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Match', style: TextStyle(fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: tC, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: mapC, decoration: const InputDecoration(labelText: 'Map (Erangel/Miramar/Vikendi/Livik)')),
            TextField(controller: modeC, decoration: const InputDecoration(labelText: 'Mode (SOLO/SQUAD)')),
            TextField(controller: timeC, decoration: const InputDecoration(labelText: 'Time / Display label')),
            TextField(controller: startC, decoration: const InputDecoration(labelText: 'Start (YYYY-MM-DD HH:MM)')),
            TextField(controller: closeC, decoration: const InputDecoration(labelText: 'Join auto-close (YYYY-MM-DD HH:MM)')),
            TextField(controller: roomC, decoration: const InputDecoration(labelText: 'Room release (YYYY-MM-DD HH:MM)')),
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
              DateTime? parseTime(String v) => DateTime.tryParse(v.trim().replaceFirst(' ', 'T'));
              final st = parseTime(startC.text), cl = parseTime(closeC.text), rm = parseTime(roomC.text);
              if (st == null || cl == null || rm == null) return _msg('Timer date/time format sahi dalein.');
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('$kDbUrl/matches.json?auth=${widget.token}'),
                body: jsonEncode({
                  'title': tC.text.trim(),
                  'map': mapC.text.trim(),
                  'mode': modeC.text.trim(),
                  'time': timeC.text.trim().isEmpty ? startC.text.trim() : timeC.text.trim(),
                  'startAt': st.millisecondsSinceEpoch,
                  'closeAt': cl.millisecondsSinceEpoch,
                  'roomReleaseAt': rm.millisecondsSinceEpoch,
                  'hold': false,
                  'status': 'OPEN',
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
        itemCount: _matches.length + (_promoEnabled && _promoImageUrl.isNotEmpty ? 1 : 0),
        itemBuilder: (_, i) {
          if (_promoEnabled && _promoImageUrl.isNotEmpty && i == 0) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  final u = Uri.tryParse(_promoClickUrl);
                  if (u != null && (u.scheme == 'https' || u.scheme == 'http')) {
                    await launchUrl(u, mode: LaunchMode.externalApplication);
                  }
                },
                child: Image.network(_promoImageUrl, height: 110, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(16), child: Text('SK ESPORTS PROMO'),
                  ),
                ),
              ),
            );
          }
          final m = _matches[i - (_promoEnabled && _promoImageUrl.isNotEmpty ? 1 : 0)],
              joined = m['isJoined'] == true,
              isFull = _num(m['joined']) >= _num(m['slots']),
              closed = _matchClosed(m),
              roomReady = _roomAvailable(m);
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
                Text('Join: ${closed ? 'CLOSED' : 'OPEN'} • Room: ${m['hold'] == true ? 'HOLD' : (roomReady ? 'RELEASED' : 'WAITING UNTIL ${_timeLabel(m['roomReleaseAt'])}')}', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                if (joined || isAdmin) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    ElevatedButton(
                      onPressed: (roomReady || isAdmin) ? () => _showRoomAfterAd(m) : null,
                      child: const Text('View Room ID / Pass'),
                    ),
                    if (isAdmin) ...[
                      IconButton(icon: const Icon(Icons.edit, color: Color(0xFFFF9800)), onPressed: () => _editRoom(m)),
                      IconButton(icon: const Icon(Icons.schedule, color: Colors.lightBlueAccent), onPressed: () => _editMatchTiming(m)),
                      IconButton(icon: Icon(m['hold'] == true ? Icons.play_arrow : Icons.pause, color: Colors.amber), onPressed: () => _toggleMatchHold(m)),
                    ],
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
                    onPressed: (joined || isFull || closed || isAdmin) ? null : () => _startJoinAd(m),
                    child: Text(
                      joined ? 'JOINED ✓' : (closed ? 'CLOSED' : (isFull ? 'FULL' : (isAdmin ? 'ADMIN' : 'Join ₹${m['fee']}'))),
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
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('RULES:\n$_rulesText'))),
        ..._aboutLinks.map((link) => Padding(padding: const EdgeInsets.only(bottom: 7), child: OutlinedButton.icon(onPressed: () async { final uri = Uri.tryParse(link['url'].toString()); if (uri != null && !await launchUrl(uri, mode: LaunchMode.externalApplication)) { await Clipboard.setData(ClipboardData(text: link['url'].toString())); _msg('Link copied!'); } }, icon: const Icon(Icons.open_in_new), label: Text(link['label'].toString())))),
                OutlinedButton(
          onPressed: () async {
            await (await SharedPreferences.getInstance()).clear();
            if (!context.mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
          },
          child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
        ),

      ]),
      _chatPage(),
      if (isAdmin)
        ListView(padding: const EdgeInsets.all(14), children: [
          if (isSuperAdmin) ...[
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
                    await http.patch(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'), body: jsonEncode({'upiId': _upiId, 'qrUrl': _qrUrl}));
                    _msg('New Payment QR Live!');
                  },
                  child: const Text('Update QR Live', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('Create New Match', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: _addMatch,
          ),
          if (isSuperAdmin) Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ADSTERRA & PROMO SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                const SizedBox(height: 8),
                TextField(controller: _joinAdUrlController, decoration: const InputDecoration(labelText: 'Join Ad Direct Link (10 sec)')),
                const SizedBox(height: 8),
                TextField(controller: _roomAdUrlController, decoration: const InputDecoration(labelText: 'Room Ad Direct Link (5 sec)')),
                const SizedBox(height: 8),
                TextField(controller: _promoImageUrlController, decoration: const InputDecoration(labelText: 'Promo Image URL')),
                const SizedBox(height: 8),
                TextField(controller: _promoClickUrlController, decoration: const InputDecoration(labelText: 'Promo Click URL')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Top Promo Banner ON / OFF'),
                  value: _promoEnabled,
                  onChanged: (v) => setState(() => _promoEnabled = v),
                ),
                ElevatedButton(
                  onPressed: _saveAdAndPromoConfig,
                  child: const Text('Save Ad & Promo Settings'),
                ),
                const Text('Dummy URL abhi example.com hai. Real Adsterra link baad mein yahin paste karein.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
          ),
          if (isSuperAdmin) ...[
          Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF00E676)), title: const Text('Private Super Admin Wallet'), subtitle: const Text('Sirf Super Admin ko visible'), trailing: Text('₹$_wallet', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 18)))),
          _roleManagementCard(),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ABOUT LINKS & RULES EDITOR', style: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('Har line: Button Name | https://link', style: TextStyle(fontSize: 11, color: Colors.grey)), TextField(controller: _aboutLinksC, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Social / Support Links', border: OutlineInputBorder())), const SizedBox(height: 8), TextField(controller: _rulesC, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Rules (BGMI Level 30+ etc.)', border: OutlineInputBorder())), ElevatedButton(onPressed: _saveAboutRules, child: const Text('Save About & Rules'))]))),
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
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x22FF9800),
                child: Icon(Icons.groups, color: Color(0xFFFF9800)),
              ),
              title: const Text('All Players', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${_users.length} registered players'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showAllPlayersDialog,
            ),
          ),
          TextButton.icon(
            onPressed: _showHistory,
            icon: const Icon(Icons.history, size: 18, color: Color(0xFFFF9800)),
            label: const Text('All Players History', style: TextStyle(color: Color(0xFFFF9800))),
          ),
          ],

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
          const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          if (isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
    );
  }
}
