import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';


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

Uri? _resolveAdTarget(String raw) {
  final value = raw.trim();
  if (value.startsWith('intent://')) {
    final fallback = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(value);
    if (fallback != null) {
      final decoded = Uri.decodeComponent(fallback.group(1)!);
      final parsed = Uri.tryParse(decoded);
      if (parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http')) return parsed;
    }
    final hostPath = value.substring('intent://'.length).split('#Intent;').first;
    return Uri.tryParse('https://$hostPath');
  }
  if (value.startsWith('market://')) {
    final market = Uri.tryParse(value);
    final packageId = market?.queryParameters['id'];
    if (packageId != null && packageId.isNotEmpty) {
      return Uri.parse('https://play.google.com/store/apps/details?id=${Uri.encodeComponent(packageId)}');
    }
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) return uri;
  return null;
}

Future<void> _openAdTargetOnce(String raw) async {
  final uri = _resolveAdTarget(raw);
  if (uri == null) return;
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    try { await launchUrl(uri, mode: LaunchMode.platformDefault); } catch (_) {}
  }
}

class AdViewerDialog extends StatefulWidget {
  final String title, url;
  final int? seconds;
  final VoidCallback onContinue;
  final bool openExternalOnClose;
  const AdViewerDialog({super.key, required this.title, required this.url, required this.seconds, required this.onContinue, this.openExternalOnClose = false});
  @override
  State<AdViewerDialog> createState() => _AdViewerDialogState();
}

class _AdViewerDialogState extends State<AdViewerDialog> {
  late final WebViewController _controller;
  Timer? _timer;
  int _remaining = 0;
  bool _finished = false;
  String? _lastHttpUrl;
  String? _pendingExternalUrl;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds ?? 0;
    _lastHttpUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('AdExternal', onMessageReceived: (message) {
        final target = _resolveAdTarget(message.message);
        if (target != null) _pendingExternalUrl = target.toString();
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          try {
            await _controller.runJavaScript('''
              (function() {
                if (window.__skEspAdsHooked) return;
                window.__skEspAdsHooked = true;
                window.open = function(target) {
                  if (target) AdExternal.postMessage(String(target));
                  return null;
                };
                document.addEventListener('click', function(event) {
                  var anchor = event.target && event.target.closest ? event.target.closest('a') : null;
                  if (anchor && anchor.href && anchor.target === '_blank') {
                    event.preventDefault();
                    AdExternal.postMessage(anchor.href);
                  }
                }, true);
              })();
            ''');
          } catch (_) {}
        },
        onNavigationRequest: (request) {
          final raw = request.url;
          final uri = Uri.tryParse(raw);
          if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
            if (request.isMainFrame) _lastHttpUrl = raw;
            return NavigationDecision.navigate;
          }
          if (raw.startsWith('intent://') || raw.startsWith('market://')) {
            final target = _resolveAdTarget(raw);
            if (target != null) _pendingExternalUrl = target.toString();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    if (widget.seconds != null && widget.seconds! > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _finished) { timer.cancel(); return; }
        if (_remaining <= 1) {
          timer.cancel();
          setState(() => _remaining = 0);
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  Future<void> _finishAd() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    final destination = _pendingExternalUrl ?? _lastHttpUrl ?? widget.url;
    if (mounted) Navigator.of(context).pop();
    if (widget.openExternalOnClose) await _openAdTargetOnce(destination);
    widget.onContinue();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
    onWillPop: () async {
      if (widget.seconds == null || _remaining == 0) {
        await _finishAd();
      }
      return false;
    },
    child: Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: const Color(0xFF0D1117),
      child: SizedBox.expand(
        child: Column(children: [
          Container(
            color: const Color(0xFF161B22),
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                Expanded(child: Text(
                  widget.seconds == null ? 'Sponsored Ad' : (_remaining > 0 ? 'Ad: Please wait ${_remaining}s...' : 'Ad: Ready to continue'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )),
                ElevatedButton(
                  onPressed: (widget.seconds == null || _remaining == 0) ? _finishAd : null,
                  child: Text(widget.seconds == null ? 'Close / Skip' : 'Continue'),
                ),
              ]),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ]),
      ),
    ),
  );
}

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

  Future<void> _sendVerificationEmail(String idToken) async {
    final res = await http.post(
      Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$kApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'requestType': 'VERIFY_EMAIL', 'idToken': idToken}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['error']?['message'] ?? 'Verification email send nahi hua.');
    }
  }


  Future<void> _recoverMissingProfile({required String uid, required String token, required String email}) async {
    final profileUrl = Uri.parse('$kDbUrl/users/$uid.json?auth=$token');
    final existing = await http.get(profileUrl).timeout(const Duration(seconds: 20));
    if (existing.statusCode != 200) throw Exception('Profile check failed (HTTP ${existing.statusCode}). Firebase Rules check karein; existing data untouched hai.');
    if (existing.body.trim() != 'null') return;
    final recoveredName = email.split('@').first.trim();
    final profile = <String, dynamic>{'email': email, 'ign': recoveredName.isEmpty ? 'SK_Player' : recoveredName, 'bgmiId': 'Not Set', 'wallet': 0};
    final save = await http.put(profileUrl, body: jsonEncode(profile)).timeout(const Duration(seconds: 20));
    if (save.statusCode < 200 || save.statusCode >= 300) throw Exception('Auth account mil gaya, lekin missing profile create nahi hua (HTTP ${save.statusCode}). Existing profile overwrite nahi kiya.');
    final verify = await http.get(profileUrl).timeout(const Duration(seconds: 20));
    if (verify.statusCode != 200 || verify.body.trim() == 'null') throw Exception('Profile recovery verify nahi hui. Firebase data ko dobara check karein.');
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
      if (_isLogin) {
        // Login requires valid Email + Password only.
        // Keep profile recovery for Auth accounts whose RTDB profile is genuinely missing.
        await _recoverMissingProfile(uid: uid, token: token, email: e);
      }
      final sp = await SharedPreferences.getInstance();
      await sp.setString('rt', data['refreshToken']);
      await sp.setString('email', e);

      if (!_isLogin) {
        // Registration profile keeps the same Firebase UID. Require Gmail verification
        // before saving a persistent app session or entering the tournament app.
        await _sendVerificationEmail(token);
        await sp.remove('rt');
        await sp.remove('email');
        if (!mounted) return;
        setState(() => _isLogin = true);
        _msg('Registration ho gaya! Gmail inbox/Spam mein verification link bheja hai. Link verify karke isi Email aur Password se login karein.');
        return;
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
                const SizedBox(height: 12),
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

class AdsterraBanner extends StatefulWidget {
  final String code;
  const AdsterraBanner({super.key, required this.code});
  @override
  State<AdsterraBanner> createState() => _AdsterraBannerState();
}
class _AdsterraBannerState extends State<AdsterraBanner> {
  late final WebViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..addJavaScriptChannel('ExternalLink', onMessageReceived: (message) async {
        final uri = Uri.tryParse(message.message);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          if (request.isMainFrame && uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http')) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadHtmlString(_buildAdHtml(widget.code), baseUrl: 'https://sahidkhanmewati02-source.github.io');
  }
  String _buildAdHtml(String code) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<style>
html,body{margin:0;padding:0;width:320px;height:50px;overflow:hidden;background:transparent}
#ad-slot{width:320px;height:50px;overflow:hidden;display:flex;align-items:center;justify-content:center}
</style></head><body style="margin:0;padding:0;background:transparent;display:flex;justify-content:center;align-items:center;">
<div id="ad-slot">$code</div>
<script>
(function(){
  window.open=function(url){if(url)ExternalLink.postMessage(String(url));return null;};
  document.addEventListener('click',function(event){
    var link=event.target&&event.target.closest?event.target.closest('a'):null;
    if(link&&link.href){event.preventDefault();ExternalLink.postMessage(link.href);}
  },true);
})();
</script></body></html>
''';
  @override
  Widget build(BuildContext context) => SizedBox(
    width:320,height:50,child:WebViewWidget(controller:_controller));
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
  String _adsterraBannerCode = '';
  bool _promoEnabled = false, _autoBannerAdEnabled = true;
  bool _loading = true;
  String _superAdminUid = '';
  DateTime _clock = DateTime.now();
  Timer? _matchTicker;
  List _matches = [], _txns = [], _deps = [], _withs = [], _users = [], _chatMessages = [], _aboutLinks = [], _matchAccounts = [];
  String _rulesText = 'BGMI Level 30+ ID required.\nRoom ID & Password match se 15 minute pehle milega.\nChat mein abuse, spam aur personal details share na karein.\nEntry fee aur withdrawal ke liye sahi UTR/UPI details dein.';
  final _chatC = TextEditingController(), _aboutLinksC = TextEditingController(), _rulesC = TextEditingController();
  final _upiC = TextEditingController(), _qrC = TextEditingController();
  final _joinAdUrlController = TextEditingController(text: 'https://example.com');
  final _roomAdUrlController = TextEditingController(text: 'https://example.com');
  final _promoImageUrlController = TextEditingController();
  final _promoClickUrlController = TextEditingController();
  final _adsterraBannerCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _matchTicker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _clock = DateTime.now()); });
    _sync();
  }

  @override
  void dispose() {
    _matchTicker?.cancel();
    _upiC.dispose(); _qrC.dispose(); _joinAdUrlController.dispose(); _roomAdUrlController.dispose(); _promoImageUrlController.dispose(); _promoClickUrlController.dispose(); _adsterraBannerCodeController.dispose();
    _chatC.dispose(); _aboutLinksC.dispose(); _rulesC.dispose();
    super.dispose();
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  int _num(dynamic v) => int.tryParse('$v') ?? 0;

  int _matchStartTimestamp(Map m) {
    final direct = _num(m['startAt'] ?? m['startTime'] ?? m['scheduledAt']);
    if (direct > 0) return direct < 100000000000 ? direct * 1000 : direct;
    final raw = (m['startDateTime'] ?? m['scheduledDateTime'] ?? m['time'] ?? '').toString().trim();
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return parsed?.millisecondsSinceEpoch ?? 0x7fffffffffffffff;
  }

  int _compareMatches(Map a, Map b) {
    final aDone = _isMatchCompleted(a), bDone = _isMatchCompleted(b);
    if (aDone != bDone) return aDone ? 1 : -1;
    final byStart = _matchStartTimestamp(a).compareTo(_matchStartTimestamp(b));
    if (byStart != 0) return byStart;
    return _num(b['createdAt']).compareTo(_num(a['createdAt']));
  }

  void _sortMatches() => _matches.sort((a, b) => _compareMatches(a as Map, b as Map));
  int _teamSize(Map m) {
    final mode = (m['mode'] ?? 'SOLO').toString().toUpperCase();
    if (mode.contains('SQUAD')) return 4;
    if (mode.contains('DUO')) return 2;
    return 1;
  }

  int _matchPlayerCount(Map m) {
    final players = m['players'];
    if (players is Map) return players.length;
    if (players is List) return players.length;
    return 0;
  }

  int _slotNumberFor(Map m, String uid) {
    final players = m['players'];
    if (players is Map) {
      final player = players[uid];
      if (player is Map) {
        final saved = _num(player['slotNumber']);
        if (saved > 0) return saved;
      }
      // Legacy roster entries may not have a persisted slotNumber.
      // Use their existing roster order for display without attempting a
      // Firebase write (which can fail under deployed RTDB rules).
      var position = 0;
      for (final key in players.keys) {
        position++;
        if (key.toString() == uid) return position;
      }
    } else if (players is List) {
      final index = players.indexWhere((entry) => entry is Map && (entry['uid'] ?? entry['userId'] ?? '').toString() == uid);
      if (index >= 0) return index + 1;
    }
    return 0;
  }

  int _nextSlotNumber(Map m) {
    final players = m['players'];
    var highest = players is Map ? players.length : (players is List ? players.length : 0);
    if (players is Map) {
      for (final value in players.values) {
        if (value is Map) highest = math.max(highest, _num(value['slotNumber']));
      }
    }
    return highest + 1;
  }

  int _rosterCollection(Map match, Map hisaab) {
    final fee = _num(match['fee']);
    final players = match['players'];
    var rosterTotal = 0;
    var rosterCount = 0;
    if (players is Map) {
      for (final p in players.values) {
        if (p is Map) {
          rosterCount++;
          rosterTotal += p['feePaid'] == null ? fee : _num(p['feePaid']);
        }
      }
    } else if (players is List) {
      for (final p in players) {
        if (p is Map) {
          rosterCount++;
          rosterTotal += p['feePaid'] == null ? fee : _num(p['feePaid']);
        }
      }
    }
    final joinedCount = _num(match['joined']);
    final missingRosterSlots = joinedCount > rosterCount ? joinedCount - rosterCount : 0;
    final calculated = rosterTotal + missingRosterSlots * fee;
    final saved = _num(hisaab['collection']);
    return calculated > saved ? calculated : saved;
  }

  Future<Map<String, dynamic>> _refreshMatchHisaabFromRoster(Map match) async {
    final id = match['id'].toString();
    final title = match['title']?.toString() ?? 'Match';
    final data = await _readMatchHisaab(id, title);
    final collection = _rosterCollection(match, data);
    if (collection != _num(data['collection'])) {
      final res = await http.patch(
        Uri.parse('$kDbUrl/match_hisaab/$id.json?auth=${widget.token}'),
        body: jsonEncode({'title': title, 'collection': collection, 'updatedAt': DateTime.now().millisecondsSinceEpoch}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('Roster se match collection update nahi hua.');
      data['collection'] = collection;
    }
    return data;
  }


  Future<void> _recoverMissingProfileInHome() async {
    final profileUrl = Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}');
    final before = await http.get(profileUrl).timeout(const Duration(seconds: 20));
    if (before.statusCode != 200) throw Exception('Profile check failed HTTP ${before.statusCode}: ${before.body}');
    if (before.body.trim() != 'null') return;
    final recoveredName = widget.email.split('@').first.trim();
    final profile = <String, dynamic>{'email': widget.email, 'ign': recoveredName.isEmpty ? 'SK_Player' : recoveredName, 'bgmiId': 'Not Set', 'wallet': 0};
    final save = await http.put(profileUrl, body: jsonEncode(profile)).timeout(const Duration(seconds: 20));
    if (save.statusCode < 200 || save.statusCode >= 300) throw Exception('Missing profile create reject HTTP ${save.statusCode}: ${save.body}. Existing data overwrite nahi hua.');
    final verify = await http.get(profileUrl).timeout(const Duration(seconds: 20));
    if (verify.statusCode != 200 || verify.body.trim() == 'null') throw Exception('Profile recovery verify failed HTTP ${verify.statusCode}: ${verify.body}');
  }

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
        _adsterraBannerCode = c['adsterraBannerCode']?.toString() ?? '';
        _autoBannerAdEnabled = c['autoBannerAdEnabled'] != false;
        _adsterraBannerCodeController.text = _adsterraBannerCode;
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
      if (uRes.statusCode != 200) throw Exception('Profile read failed (${uRes.statusCode}); UID/session ya Rules mismatch ho sakta hai. Data overwrite nahi kiya.');
      var profileBody = uRes.body;
      if (profileBody.trim() == 'null') {
        await _recoverMissingProfileInHome();
        final recovered = await http.get(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'));
        if (recovered.statusCode != 200 || recovered.body.trim() == 'null') {
          throw Exception('Is UID ka profile abhi bhi nahi mila. Recovery result: HTTP ${recovered.statusCode} ${recovered.body}');
        }
        profileBody = recovered.body;
      }
      {
        final d = jsonDecode(profileBody);
        _ign = d['ign'] ?? 'SK_Player';
        _bgmiId = d['bgmiId'] ?? 'Not Set';
        _wallet = _num(d['wallet']);
        _isCoAdmin = !isSuperAdmin && d['role'] == 'coadmin';
        if (d['txns'] is Map) {
          _txns = (d['txns'] as Map).entries
              .where((entry) => entry.value is Map)
              .map((entry) => <String, dynamic>{'id': entry.key.toString(), ...Map<String, dynamic>.from(entry.value as Map)})
              .toList()
            ..sort((a, b) => _historyTimestamp(b).compareTo(_historyTimestamp(a)));
        } else {
          _txns = [];
        }
      }

      final mRes = await http.get(Uri.parse('$kDbUrl/matches.json?auth=${widget.token}'));
      if (mRes.statusCode != 200) throw Exception('Matches read failed (${mRes.statusCode}); matches ko write/reset nahi kiya gaya.');
      if (mRes.body != 'null') {
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
        // Legacy slots are derived from roster order for display. Do not
        // write them during screen refresh: deployed RTDB rules may reject
        // these migration writes and block the admin workflow.
        _sortMatches();
      } else {
        // Empty is displayed as empty. Never seed/overwrite the matches node here.
        _matches = [];
      }

      if (isSuperAdmin) {
        final hRes = await http.get(Uri.parse('$kDbUrl/match_hisaab.json?auth=${widget.token}'));
        final raw = hRes.statusCode == 200 && hRes.body != 'null' ? jsonDecode(hRes.body) as Map : <String, dynamic>{};
        final accounts = <Map>[];
        for (final match in _matches) {
          final id = match['id'].toString();
          final saved = raw[id] is Map ? Map<String, dynamic>.from(raw[id]) : <String, dynamic>{};
          if (saved.isEmpty) {
            final fresh = {'title': match['title'] ?? 'Match', 'collection': 0, 'prizeSent': 0, 'settled': false, 'status': 'OPEN', 'updatedAt': DateTime.now().millisecondsSinceEpoch};
            await http.put(Uri.parse('$kDbUrl/match_hisaab/$id.json?auth=${widget.token}'), body: jsonEncode(fresh));
            accounts.add({'id': id, ...fresh});
          } else {
            accounts.add({'id': id, ...saved, 'title': saved['title'] ?? match['title'] ?? 'Match'});
          }
        }
        // Keep settled records visible even if a match is no longer in the active matches list.
        raw.forEach((id, value) {
          if (value is Map && !accounts.any((a) => a['id'].toString() == id.toString())) accounts.add({'id': id.toString(), ...value});
        });
        accounts.sort((a,b) => (a['settled'] == true ? 1 : 0).compareTo(b['settled'] == true ? 1 : 0));
        _matchAccounts = accounts;
      } else {
        _matchAccounts = [];
      }

      if (isAdmin) {
        final chatRes = await http.get(Uri.parse('$kDbUrl/chat.json?auth=${widget.token}'));
        if (chatRes.statusCode != 200) throw Exception('Chat read failed (${chatRes.statusCode}); chat ko empty nahi maana gaya.');
        final chats = <Map>[];
        if (chatRes.statusCode == 200 && chatRes.body != 'null') (jsonDecode(chatRes.body) as Map).forEach((k, v) { if (v is Map) chats.add({...v, 'id': k}); });
        _chatMessages = chats;
        final dRes = await http.get(Uri.parse('$kDbUrl/deposits.json?auth=${widget.token}'));
        if (dRes.statusCode != 200) throw Exception('Deposits read failed (${dRes.statusCode}); records ko empty nahi maana gaya.');
        final deps = [];
        if (dRes.statusCode == 200 && dRes.body != 'null') {
          (jsonDecode(dRes.body) as Map).forEach((k, v) {
            if (v is Map && v['status'] == 'PENDING') deps.add({...v, 'id': k});
          });
        }
        _deps = deps.reversed.toList();

        final wRes = await http.get(Uri.parse('$kDbUrl/withdrawals.json?auth=${widget.token}'));
        if (wRes.statusCode != 200) throw Exception('Withdrawals read failed (${wRes.statusCode}); records ko empty nahi maana gaya.');
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
        if (allRes.statusCode != 200) throw Exception('All players read failed (${allRes.statusCode}); players ko empty nahi maana gaya.');
        final usrs = [];
        if (allRes.statusCode == 200 && allRes.body != 'null') {
          (jsonDecode(allRes.body) as Map).forEach((k, v) {
            if (v is Map) usrs.add({...v, 'uid': k});
          });
        }
        _users = usrs;
        if (isSuperAdmin) await _refreshAdminDirectory();
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
    } catch (e) {
      if (mounted) _msg('Data load ruk gaya: ${e.toString().replaceAll('Exception: ', '')}');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<Map<String, dynamic>> _readMatchHisaab(String matchId, String title) async {
    final uri = Uri.parse('$kDbUrl/match_hisaab/$matchId.json?auth=${widget.token}');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Match hisaab read nahi hua.');
    if (res.body == 'null') {
      final fresh = <String, dynamic>{'title': title, 'collection': 0, 'prizeSent': 0, 'settled': false, 'status': 'OPEN', 'updatedAt': DateTime.now().millisecondsSinceEpoch};
      final put = await http.put(uri, body: jsonEncode(fresh));
      if (put.statusCode < 200 || put.statusCode >= 300) throw Exception('Match hisaab create nahi hua.');
      return fresh;
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<void> _addMatchCollection(String matchId, String title, int amount) async {
    final data = await _readMatchHisaab(matchId, title);
    if (data['settled'] == true) throw Exception('Yeh match already settled hai; collection accept nahi ho sakta.');
    final total = _num(data['collection']) + amount;
    final res = await http.patch(Uri.parse('$kDbUrl/match_hisaab/$matchId.json?auth=${widget.token}'), body: jsonEncode({'title': title, 'collection': total, 'prizeSent': _num(data['prizeSent']), 'updatedAt': DateTime.now().millisecondsSinceEpoch}));
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('Match collection update nahi hua.');
    if (mounted && isSuperAdmin) setState(() {
      final i = _matchAccounts.indexWhere((x) => x['id'].toString() == matchId);
      final row = {'id': matchId, ...data, 'title': title, 'collection': total};
      if (i >= 0) _matchAccounts[i] = row; else _matchAccounts.insert(0, row);
    });
  }

  Future<void> _addMatchPrize(String matchId, String title, int amount) async {
    if (!isSuperAdmin) throw Exception('Prize sirf Super Admin bhej sakta hai.');
    final data = await _readMatchHisaab(matchId, title);
    if (data['settled'] == true) throw Exception('Match settled hai; prize entry lock hai.');
    final total = _num(data['prizeSent']) + amount;
    final res = await http.patch(Uri.parse('$kDbUrl/match_hisaab/$matchId.json?auth=${widget.token}'), body: jsonEncode({'title': title, 'collection': _num(data['collection']), 'prizeSent': total, 'updatedAt': DateTime.now().millisecondsSinceEpoch}));
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('Prize hisaab update nahi hua.');
    if (mounted && isSuperAdmin) setState(() {
      final i = _matchAccounts.indexWhere((x) => x['id'].toString() == matchId);
      final row = {'id': matchId, ...data, 'title': title, 'prizeSent': total};
      if (i >= 0) _matchAccounts[i] = row; else _matchAccounts.insert(0, row);
    });
  }

  Future<void> _transferMatchProfit(Map account) async {
    if (!isSuperAdmin) return;
    final id = account['id'].toString();
    try {
      final match = _matches.firstWhere((m) => m['id'].toString() == id, orElse: () => account['match'] is Map ? Map.from(account['match']) : <String, dynamic>{'id': id, 'title': account['title'], 'fee': 0, 'joined': 0, 'players': {}});
      final data = await _refreshMatchHisaabFromRoster(match);
      final expenses = _matchExpenses(data);
      final netProfit = _num(data['collection']) - _num(data['prizeSent']) - expenses;
      final skShare = netProfit > 0 ? (netProfit * 0.75).round() : 0;
      final alreadyTransferred = _num(data['transferredAmount']);
      final availableProfit = skShare - alreadyTransferred;
      if (availableProfit <= 0) return _msg('Koi naya Net Profit transfer ke liye available nahi hai.');
      final walletRes = await http.get(Uri.parse('$kDbUrl/users/${widget.uid}.json?auth=${widget.token}'));
      if (walletRes.statusCode != 200 || walletRes.body == 'null') throw Exception('Super Admin wallet read nahi hua.');
      final userData = jsonDecode(walletRes.body) as Map;
      final newBalance = _num(userData['wallet']) + availableProfit;
      final txnId = DateTime.now().microsecondsSinceEpoch.toString();
      final now = DateTime.now();
      final dt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final newTransferred = alreadyTransferred + availableProfit;
      final fullyTransferred = newTransferred >= skShare;
      final patch = <String, dynamic>{
        'users/${widget.uid}/wallet': newBalance,
        'users/${widget.uid}/txns/$txnId': {'title': 'Match Profit Transfer', 'sub': '${data['title'] ?? account['title']} • $dt', 'amt': availableProfit, 'status': 'CREDITED', 'time': dt},
        'match_hisaab/$id/transferred': fullyTransferred,
        'match_hisaab/$id/transferredAmount': newTransferred,
        'match_hisaab/$id/transferredAt': now.millisecondsSinceEpoch,
        'match_hisaab/$id/settled': fullyTransferred,
        'match_hisaab/$id/status': fullyTransferred ? 'Settled ✅' : 'PARTIALLY TRANSFERRED',
      };
      final transferRes = await http.patch(Uri.parse('$kDbUrl/.json?auth=${widget.token}'), body: jsonEncode(patch));
      if (transferRes.statusCode < 200 || transferRes.statusCode >= 300) throw Exception('Profit transfer atomic update fail hua (${transferRes.statusCode}). Wallet/settlement update nahi hua.');
      if (mounted) setState(() { _wallet = newBalance; _txns.insert(0, {'id': txnId, 'title': 'Match Profit Transfer', 'sub': '${data['title'] ?? account['title']} • $dt', 'amt': availableProfit, 'status': 'CREDITED', 'time': dt}); });
      _msg('₹$availableProfit main wallet mein transfer ho gaya.');
      await _sync();
    } catch (e) { _msg(e.toString().replaceAll('Exception: ', '')); }
  }

  Future<void> _confirmDeleteMatchAccount(Map account) async {
    if (!isSuperAdmin) return;
    final id = account['id']?.toString() ?? '';
    if (id.isEmpty) return _msg('Match record ID nahi mila.');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Match Hisaab?'),
        content: Text("${account['title'] ?? 'Match'} ka collection/profit record permanently delete ho jayega."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await http.delete(Uri.parse('$kDbUrl/match_hisaab/$id.json?auth=${widget.token}'));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (mounted) setState(() => _matchAccounts.removeWhere((x) => x['id'].toString() == id));
      _msg('Match hisaab record delete ho gaya.');
    } else {
      _msg('Record delete nahi hua. Firebase Rules check karein.');
    }
  }


  Future<void> _showMatchHisaab(Map match) async {
    if (!isAdmin) return;
    final id = match['id'].toString();
    final title = match['title']?.toString() ?? 'Match';
    Map<String, dynamic> data;
    try {
      data = await _refreshMatchHisaabFromRoster(match);
    } catch (e) {
      _msg(e.toString().replaceAll('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    bool transferring = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final collection = _num(data['collection']);
          final prize = _num(data['prizeSent']);
          final profit = collection - prize - _matchExpenses(data);
          final skShare = profit > 0 ? (profit * 0.75).round() : 0;
          final transferredAmount = _num(data['transferredAmount']);
          final available = skShare - transferredAmount;
          return AlertDialog(
            title: Text('₹ Hisaab • $title', style: const TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _hisaabRow('Total Collection', collection, const Color(0xFF00E676)),
                _hisaabRow('Prize Sent', prize, const Color(0xFFFF9800)),
                _hisaabRow('Match Expenses', _matchExpenses(data), Colors.redAccent),
                const Divider(),
                _hisaabRow('Net Profit', profit - _matchExpenses(data), profit - _matchExpenses(data) >= 0 ? const Color(0xFF00E676) : Colors.redAccent),
                _hisaabRow('Admins Pool • 25%', (profit - _matchExpenses(data)) > 0 ? ((profit - _matchExpenses(data)) * 0.25).round() : 0, Colors.amber),
                _hisaabRow('SK eSports Share • 75%', (profit - _matchExpenses(data)) > 0 ? ((profit - _matchExpenses(data)) * 0.75).round() : 0, const Color(0xFF00E676)),
                if (transferredAmount > 0) _hisaabRow('Already Transferred', transferredAmount, Colors.lightBlueAccent),
                if (available > 0 && transferredAmount > 0) _hisaabRow('Available to Transfer', available, const Color(0xFF00E676)),
                if (data['transferred'] == true && available <= 0)
                  const Padding(padding: EdgeInsets.only(top: 8), child: Text('Profit transferred ✅', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold))),
                if (isSuperAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: available > 0 && !transferring ? () async {
                        setDialogState(() => transferring = true);
                        await _transferMatchProfit({'id': id, 'title': title, 'match': match});
                        try {
                          final latest = await _readMatchHisaab(id, title);
                          if (ctx.mounted) setDialogState(() { data = latest; transferring = false; });
                        } catch (_) {
                          if (ctx.mounted) setDialogState(() => transferring = false);
                        }
                      } : null,
                      icon: transferring ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.account_balance_wallet),
                      label: const Text('Transfer Profit to Main Wallet'),
                    ),
                  ),
                ],
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
          );
        },
      ),
    );
  }

  Widget _hisaabRow(String label, int amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text('₹$amount', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }


  Future<List<Map<String, dynamic>>> _loadRegisteredAdmins() async {
    final r = await http.get(Uri.parse('$kDbUrl/config/adminDirectory.json?auth=${widget.token}'));
    if (r.statusCode != 200 || r.body == 'null') throw Exception('Admin list unavailable. Super Admin app refresh karein.');
    final raw = jsonDecode(r.body);
    if (raw is! List) throw Exception('Admin directory invalid.');
    final list = raw.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).where((e) => (e['uid'] ?? '').toString().isNotEmpty && (e['isSuperAdmin'] == true || e['role'] == 'coadmin')).toList();
    if (list.isEmpty) throw Exception('Koi Admin/Co-Admin registered nahi hai.');
    return list;
  }

  Future<void> _refreshAdminDirectory() async {
    if (!isSuperAdmin) return;
    final list = <Map<String,dynamic>>[], seen = <String>{};
    for (final u in _users) {
      final uid = (u['uid'] ?? '').toString(), email = (u['email'] ?? '').toString();
      final sup = email.toLowerCase() == kAdmin.toLowerCase() || uid == widget.uid;
      if (uid.isEmpty || (!sup && u['role'] != 'coadmin') || !seen.add(uid)) continue;
      list.add({'uid':uid,'name':(u['ign'] ?? u['name'] ?? (sup ? 'SK eSports' : 'Admin')).toString(),'email':email,'role':sup ? 'superadmin' : 'coadmin','isSuperAdmin':sup});
    }
    if (!seen.contains(widget.uid)) list.insert(0, {'uid':widget.uid,'name':_ign,'email':widget.email,'role':'superadmin','isSuperAdmin':true});
    final r = await http.patch(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'), body: jsonEncode({'adminDirectory':list}));
    if (r.statusCode < 200 || r.statusCode >= 300) _msg('Admin directory update failed.');
  }

  int _matchIndividualPlayerCount(Map match) {
    final ps=match['players'] is Map?match['players'] as Map:<dynamic,dynamic>{};
    var total=0;
    for(final p in ps.values){if(p is Map){final members=p['members'];total+=members is List?members.length:1;}}
    return total;
  }

  List<Map<String,dynamic>> _adminLeaderboardRows(Map match) {
    final players = match['players'] is Map ? match['players'] as Map : <dynamic,dynamic>{};
    final groups = <String,Map<String,dynamic>>{}, ids = <String,int>{};
    for (final e in players.entries) {
      final p = e.value is Map ? Map<String,dynamic>.from(e.value as Map) : <String,dynamic>{};
      final members = p['members'] is List ? p['members'] as List : [p];
      for (final x in members) { if (x is Map) { final id=(x['bgmiId'] ?? '').toString(); if(id.isNotEmpty) ids[id]=(ids[id] ?? 0)+1; } }
      final aid=(p['selectedAdminUid'] ?? '').toString(); if(aid.isEmpty) continue;
      final row=groups.putIfAbsent(aid,()=>{'uid':aid,'name':p['selectedAdminName'] ?? 'Admin','count':0,'players':<Map<String,dynamic>>[]});
      row['count']=_num(row['count'])+members.length;
      (row['players'] as List).add({'ign':p['ign'] ?? 'Player','slot':p['slotNumber'] ?? 0,'members':members});
    }
    for(final row in groups.values) { for(final p in row['players'] as List) {
      p['duplicateIds']=(p['members'] as List).whereType<Map>().map((x)=>(x['bgmiId'] ?? '').toString()).where((id)=>id.isNotEmpty && (ids[id] ?? 0)>1).toSet().toList();
    }}
    return groups.values.toList()..sort((a,b)=>_num(b['count']).compareTo(_num(a['count'])));
  }

  void _showAdminSelectionLeaderboard(Map match) {
    if(!isAdmin) return;
    final rows=_adminLeaderboardRows(match);
    showDialog(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Admin Selection • '+(match['title'] ?? 'Match').toString()),
      content:SizedBox(width:double.maxFinite,height:430,child:rows.isEmpty?const Center(child:Text('No admin selection data yet.')):ListView(children:[
        Text('Total slots: '+_matchPlayerCount(match).toString()),
        ...rows.map((r)=>Card(child:Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(r['name'].toString(),style:const TextStyle(fontWeight:FontWeight.bold))),Text(r['count'].toString()+' Players',style:const TextStyle(color:Color(0xFF00E676)))]),
          const Divider(),
          ...(r['players'] as List).map((p)=>Text('Slot #'+p['slot'].toString()+' • '+p['ign'].toString()+'\n'+(p['members'] as List).whereType<Map>().map((x)=>x['ign'].toString()+' • '+x['bgmiId'].toString()+((p['duplicateIds'] as List).contains((x['bgmiId'] ?? '').toString())?' ⚠ DUPLICATE ID':'')).join('\n'),style:const TextStyle(fontSize:11))),
        ])))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))],
    ));
  }


  int _matchExpenses(Map h){final e=h['expenses'];if(e is Map)return e.values.whereType<Map>().fold<int>(0,(n,x)=>n+_num(x['amount']));return 0;}

  Future<void> _addMatchExpense(Map m) async {
    if(!isSuperAdmin)return;
    final a=TextEditingController(),n=TextEditingController(),p=TextEditingController();
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('Expense • '+(m['title']??'Match').toString()),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:a,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount ₹')),TextField(controller:n,decoration:const InputDecoration(labelText:'Reason')),TextField(controller:p,decoration:const InputDecoration(labelText:'UTR / Proof'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),ElevatedButton(onPressed:() async{final amount=_num(a.text),reason=n.text.trim();if(amount<=0||reason.isEmpty)return _msg('Amount and reason required.');final id=m['id'].toString(),h=await _readMatchHisaab(id,(m['title']??'Match').toString());if(h['settled']==true)return _msg('Match settled hai.');final r=await http.post(Uri.parse('$kDbUrl/match_hisaab/$id/expenses.json?auth=${widget.token}'),body:jsonEncode({'amount':amount,'note':reason,'proof':p.text.trim(),'createdAt':DateTime.now().millisecondsSinceEpoch}));if(r.statusCode<200||r.statusCode>=300)return _msg('Expense save failed.');if(ctx.mounted)Navigator.pop(ctx);await _sync();},child:const Text('Save Expense'))]));
    a.dispose();n.dispose();p.dispose();
  }

  Future<void> _payAdminShare(Map m,Map<String,dynamic> admin) async {
    if(!isSuperAdmin)return;
    final id=m['id'].toString(),uid=(admin['uid']??'').toString();
    try{final fresh=_matches.firstWhere((x)=>x['id'].toString()==id,orElse:()=>m),h=await _refreshMatchHisaabFromRoster(fresh),pays=h['adminPayments'] is Map?h['adminPayments'] as Map:<dynamic,dynamic>{};if(pays[uid] is Map&&pays[uid]['status']=='PAID')return _msg('Already Paid.');final row=_adminLeaderboardRows(fresh).firstWhere((x)=>x['uid'].toString()==uid,orElse:()=> <String,dynamic>{}),count=_num(row['count']),total=_matchIndividualPlayerCount(fresh),net=_num(h['collection'])-_num(h['prizeSent'])-_matchExpenses(h);if(count<=0||total<=0||net<=0)return _msg('Positive Net Profit required.');final amount=(net*.25*count/total).round(),ur=await http.get(Uri.parse('$kDbUrl/users/$uid.json?auth=${widget.token}'));if(ur.statusCode!=200||ur.body=='null')throw Exception('Admin wallet read failed.');final user=jsonDecode(ur.body) as Map,now=DateTime.now(),txn=DateTime.now().microsecondsSinceEpoch.toString();final payment={'uid':uid,'name':admin['name']??row['name']??'Admin','playerCount':count,'totalPlayers':total,'netProfitPercent':25*count/total,'amount':amount,'status':'PAID','paidAt':now.millisecondsSinceEpoch,'paidBy':widget.uid};final patch=<String,dynamic>{'users/$uid/wallet':_num(user['wallet'])+amount,'users/$uid/txns/$txn':{'title':'Match Admin Share','sub':(fresh['title']??'Match').toString(),'amt':amount,'status':'CREDITED','createdAt':now.millisecondsSinceEpoch},'match_hisaab/$id/adminPayments/$uid':payment};final r=await http.patch(Uri.parse('$kDbUrl/.json?auth=${widget.token}'),body:jsonEncode(patch));if(r.statusCode<200||r.statusCode>=300)throw Exception('Payout failed '+r.body);_msg('₹'+amount.toString()+' credited.');await _sync();}catch(e){_msg(e.toString().replaceAll('Exception: ',''));}
  }



  Widget _walletPage() {
    final creditedStatuses = {'CREDITED','APPROVED','SUCCESS','COMPLETED'};
    final debitStatuses = {'DEBITED','WITHDRAWN','WITHDRAWAL'};
    int credits = 0, debits = 0, monthCredits = 0;
    final now = DateTime.now();
    final monthly = <String, int>{};
    for (final t in _txns) {
      final amount = _num(t['amt']).round();
      final status = (t['status'] ?? '').toString().toUpperCase();
      final title = (t['title'] ?? '').toString().toLowerCase();
      final isCredit = creditedStatuses.contains(status) || title.contains('reward') || title.contains('prize') || title.contains('referral') || title.contains('win') || title.contains('share') || title.contains('credit');
      final isDebit = debitStatuses.contains(status) || title.contains('entry fee') || title.contains('withdraw');
      final stamp = _historyTimestamp(t);
      if (isCredit) {
        credits += amount;
        if (stamp > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(stamp);
          final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}';
          monthly[key] = (monthly[key] ?? 0) + amount;
          if (dt.year == now.year && dt.month == now.month) monthCredits += amount;
        }
      } else if (isDebit) { debits += amount; }
    }
    final monthKeys = monthly.keys.toList()..sort((a,b)=>b.compareTo(a));
    String monthLabel(String key) {
      final parts = key.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${names[dt.month-1]} ${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('AVAILABLE WALLET BALANCE', style: TextStyle(color: Colors.grey, fontSize: 11)),
          Text('₹$_wallet', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
        ]))),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: _deposit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)), child: const Text('Add Money', style: TextStyle(color: Colors.black)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: _withdraw, child: const Text('Withdraw'))),
          const SizedBox(width: 8),
          IconButton(tooltip: 'UPI / QR', onPressed: isSuperAdmin ? _showPaymentSettingsDialog : _deposit, icon: const Icon(Icons.qr_code_2, color: Color(0xFFFF9800))),
        ]),
        Row(children: [
          Expanded(child: _walletMetric('All-time Credits', '₹$credits', Icons.trending_up, const Color(0xFF00E676))),
          const SizedBox(width: 8),
          Expanded(child: _walletMetric('This Month', '₹$monthCredits', Icons.calendar_month, const Color(0xFFFF9800))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _walletMetric('Total Debits', '₹$debits', Icons.trending_down, Colors.redAccent)),
          const SizedBox(width: 8),
          Expanded(child: _walletMetric('Transactions', _txns.length.toString(), Icons.receipt_long, Colors.lightBlueAccent)),
        ]),
        if (monthKeys.isNotEmpty) ...[
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 14,bottom: 5), child: Text('MONTH-WISE EARNINGS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))))),
          SizedBox(height: 64, child: ListView(scrollDirection: Axis.horizontal, children: monthKeys.map((k)=>Container(width: 126, margin: const EdgeInsets.only(right: 8), child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(mainAxisAlignment: MainAxisAlignment.center,crossAxisAlignment: CrossAxisAlignment.start,children:[Text(monthLabel(k),style: const TextStyle(fontSize: 12,color: Colors.grey)),const SizedBox(height: 4),Text('₹${monthly[k]}',style: const TextStyle(fontWeight: FontWeight.bold,color: Color(0xFF00E676),fontSize: 17))]))))).toList())),
        ],
        const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 12,bottom: 6), child: Text('ALL TRANSACTION HISTORY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))))),
        Expanded(child: _txns.isEmpty ? const Center(child: Text('Abhi koi wallet transaction nahi hai.')) : ListView.builder(itemCount: _txns.length,itemBuilder: (_,i)=>ListTile(leading: const Icon(Icons.receipt_long,color: Color(0xFFFF9800)),title: Text('${_txns[i]['title'] ?? 'Wallet Transaction'}'),subtitle: Text('${_txns[i]['sub'] ?? ''} • ${_txns[i]['status'] ?? ''}\\n${_formatHistoryDateTime(_txns[i])}'),trailing: Text('₹${_txns[i]['amt'] ?? 0}')))),
      ]),
    );
  }

  Widget _walletMetric(String title, String value, IconData icon, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
      Icon(icon,color:color,size:20), const SizedBox(width:8),
      Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(fontSize:10,color:Colors.grey),maxLines:1,overflow:TextOverflow.ellipsis),
        Text(value,style:TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:color)),
      ])),
    ])));
  }

  Future<void> _showFinanceDashboard() async {
    if (!isSuperAdmin || !mounted) return;
    var tab = 0;
    var loading = true;
    String? loadError;
    StateSetter? refreshFinance;
    final accounts = <Map>[];
    final deposits = <Map>[];
    final withdrawals = <Map>[];
    final routeFuture = Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('SK eSports Finance', style: TextStyle(color: Color(0xFFFF9800))),
            backgroundColor: const Color(0xFF161B22),
          ),
          body: StatefulBuilder(
            builder: (ctx, setD) {
              refreshFinance = setD;
              if (loading) return const Center(child: CircularProgressIndicator());
              if (loadError != null && accounts.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, color: Colors.orange, size: 36),
                    const SizedBox(height: 12),
                    Text('Finance load failed: $loadError', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () => _showFinanceDashboard(), child: const Text('Retry')),
                  ]),
                ));
              }
              final collection = accounts.fold<int>(0, (n, a) => n + _num(a['collection']));
          final prizes = accounts.fold<int>(0, (n, a) => n + _num(a['prizeSent']));
          final expenses = accounts.fold<int>(0, (n, a) => n + _matchExpenses(a));
          final net = collection - prizes - expenses;
          final players = <Map<String, dynamic>>[];
          for (final a in accounts) {
            final m = a['match'] as Map;
            final roster = m['players'] is Map ? m['players'] as Map : <dynamic, dynamic>{};
            for (final e in roster.entries) {
              final p = e.value is Map ? Map<String, dynamic>.from(e.value as Map) : <String, dynamic>{};
              players.add({'match': a['title'], ...p});
            }
          }
          Widget metric(String label, String value) {
            return Card(child: ListTile(title: Text(label), trailing: Text(value, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold))));
          }
          Widget page;
          if (tab == 0) {
            page = ListView(children: [
              metric('Total Collection', '₹' + collection.toString()),
              metric('Player Prizes', '₹' + prizes.toString()),
              metric('Expenses', '₹' + expenses.toString()),
              metric('Net Profit', '₹' + net.toString()),
              metric('Admins Pool • 25%', '₹' + (net > 0 ? net * .25 : 0).toStringAsFixed(2)),
              metric('SK eSports • 75%', '₹' + (net > 0 ? net * .75 : 0).toStringAsFixed(2)),
            ]);
          } else if (tab == 1) {
            final widgets = <Widget>[];
            for (final a in accounts) {
              final m = a['match'] as Map;
              final profit = _num(a['collection']) - _num(a['prizeSent']) - _matchExpenses(a);
              final total = _matchIndividualPlayerCount(m);
              final paid = a['adminPayments'] is Map ? a['adminPayments'] as Map : <dynamic, dynamic>{};
              final rows = _adminLeaderboardRows(m);
              final adminWidgets = <Widget>[];
              for (final r in rows) {
                final count = _num(r['count']);
                final amount = profit > 0 ? (profit * .25 * count / (total == 0 ? 1 : total)).round() : 0;
                final status = paid[r['uid']] is Map ? paid[r['uid']]['status'] : 'PENDING';
                adminWidgets.add(ListTile(
                  dense: true,
                  title: Text(r['name'].toString() + ' • ' + count.toString() + ' players'),
                  subtitle: Text((total == 0 ? 0 : 25 * count / total).toStringAsFixed(2) + '% of Net Profit • ₹' + amount.toString() + ' • ' + status.toString()),
                  trailing: status == 'PAID' ? const Text('PAID') : TextButton(onPressed: () => _payAdminShare(m, Map<String, dynamic>.from(r)), child: const Text('Add to Wallet')),
                ));
              }
              widgets.add(Card(child: Column(children: [
                ListTile(title: Text(a['title'].toString()), subtitle: Text('Collection ₹' + a['collection'].toString() + ' • Net ₹' + profit.toString())),
                ...adminWidgets,
                if (isSuperAdmin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _configureMatchVotingAdmins(m),
                        icon: const Icon(Icons.how_to_vote),
                        label: Text(m['adminSelectionEnabled'] == true ? 'MANAGE VOTING ADMINS' : 'ADD ADMINS FOR THIS MATCH'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _showAdminSelectionLeaderboard(m); }, icon: const Icon(Icons.poll, size: 16), label: const Text('Admin Picks')),
                      OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _addMatchExpense(m); }, icon: const Icon(Icons.add, size: 16), label: const Text('Add Expense')),
                      OutlinedButton.icon(onPressed: () { Navigator.pop(ctx); _showMatchHisaab(m); }, icon: const Icon(Icons.receipt_long, size: 16), label: const Text('Hisaab')),
                    ],
                  ),
                ),
              ])));
            }
            page = ListView(children: widgets);
          } else if (tab == 2) {
            final widgets = <Widget>[];
            for (final p in players) {
              final members = p['members'] is List ? p['members'] as List : [p];
              final ids = members.whereType<Map>().map((x) => (x['bgmiId'] ?? '').toString()).where((x) => x.isNotEmpty).toList();
              widgets.add(ListTile(
                title: Text((p['ign'] ?? 'Player').toString() + ' • ' + p['match'].toString()),
                subtitle: Text('Admin: ' + (p['selectedAdminName'] ?? '-').toString() + ' • Kills: ' + (p['kills'] ?? 0).toString() + ' • Entry: ₹' + (p['feePaid'] ?? 0).toString() + ' • Reward: ₹' + (p['reward'] ?? 0).toString() + '\n' + (ids.toSet().length != ids.length ? 'Duplicate ID' : 'ID OK') + ' • ' + (p['refundStatus'] ?? 'No refund').toString()),
              ));
            }
            page = ListView(children: widgets);
          } else if (tab == 3) {
            final widgets = <Widget>[];
            for (final a in accounts) {
              widgets.add(ListTile(title: Text(a['title'].toString()), trailing: Text('₹' + _matchExpenses(a).toString())));
              if (a['expenses'] is Map) {
                for (final x in (a['expenses'] as Map).values.whereType<Map>()) {
                  widgets.add(ListTile(title: Text((x['note'] ?? 'Expense').toString() + ' • ₹' + (x['amount'] ?? 0).toString()), subtitle: Text('UTR / Proof: ' + (x['proof'] ?? '-').toString())));
                }
              }
              widgets.add(TextButton(onPressed: () { Navigator.pop(ctx); _addMatchExpense(a['match'] as Map); }, child: const Text('Add Expense')));
            }
            page = ListView(children: widgets);
          } else {
            final widgets = <Widget>[const ListTile(title: Text('Admin Share Payments'))];
            for (final a in accounts) {
              if (a['adminPayments'] is Map) {
                for (final payment in (a['adminPayments'] as Map).values.whereType<Map>()) {
                  widgets.add(ListTile(title: Text((payment['name'] ?? 'Admin').toString() + ' • ' + a['title'].toString()), subtitle: Text((payment['status'] ?? 'PENDING').toString() + ' • UTR / Proof: ' + (payment['utr'] ?? payment['proof'] ?? 'Wallet credit').toString()), trailing: Text('₹' + (payment['amount'] ?? 0).toString())));
                }
              }
            }
            widgets.add(const Divider());
            widgets.add(const ListTile(title: Text('Deposits / Withdrawals • UTR / Proof')));
            for (final p in deposits) {
              widgets.add(ListTile(dense: true, title: Text('Deposit • ' + (p['status'] ?? 'PENDING').toString() + ' • ₹' + (p['amt'] ?? p['amount'] ?? 0).toString()), subtitle: Text('UTR: ' + (p['utr'] ?? '-').toString() + ' • Proof: ' + (p['proof'] ?? p['screenshot'] ?? '-').toString())));
            }
            for (final p in withdrawals) {
              widgets.add(ListTile(dense: true, title: Text('Withdrawal • ' + (p['status'] ?? 'PENDING').toString() + ' • ₹' + (p['amt'] ?? 0).toString()), subtitle: Text('UTR: ' + (p['utr'] ?? '-').toString())));
            }
            page = ListView(children: widgets);
          }
          return Column(children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(['Overview', 'Match Manager', 'All Players', 'Expenses', 'Payments'][i]), selected: tab == i, onSelected: (_) => setD(() => tab = i))),
            ])),
            Expanded(child: page),
          ]);
        },
      ),
      ),
      ),
    );
    Future<void>(() async {
      try {
        final matchJobs = _matches.map((m) async {
          final h = await _refreshMatchHisaabFromRoster(m);
          return <String, dynamic>{
            'id': m['id'].toString(),
            'title': m['title'] ?? 'Match',
            'match': m,
            ...h,
          };
        }).toList();
        final results = await Future.wait<dynamic>([
          ...matchJobs,
          http.get(Uri.parse('$kDbUrl/deposits.json?auth=${widget.token}')),
          http.get(Uri.parse('$kDbUrl/withdrawals.json?auth=${widget.token}')),
        ]);
        final matchCount = matchJobs.length;
        for (var i = 0; i < matchCount; i++) {
          accounts.add(results[i] as Map);
        }
        final d = results[matchCount] as http.Response;
        if (d.statusCode == 200 && d.body != 'null') {
          final data = jsonDecode(d.body);
          if (data is Map) data.forEach((k, v) { if (v is Map) deposits.add({'id': k, ...v}); });
        }
        final w = results[matchCount + 1] as http.Response;
        if (w.statusCode == 200 && w.body != 'null') {
          final data = jsonDecode(w.body);
          if (data is Map) data.forEach((k, v) { if (v is Map) withdrawals.add({'id': k, ...v}); });
        }
      } catch (e) {
        loadError = e.toString();
      }
      loading = false;
      refreshFinance?.call(() {});
    });
    await routeFuture;
  }


  Future _saveTxn(String uid, int bal, String title, String sub, int amt, String status) async {
    final now = DateTime.now();
    final dt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final t = {
      'title': title,
      'sub': '$sub • $dt',
      'amt': amt,
      'status': status,
      'time': dt,
      'createdAt': now.millisecondsSinceEpoch,
    };
    final txnId = now.microsecondsSinceEpoch.toString();
    final patch = <String, dynamic>{
      'users/$uid/wallet': bal,
      'users/$uid/txns/$txnId': t,
    };
    final res = await http.patch(Uri.parse('$kDbUrl/.json?auth=${widget.token}'), body: jsonEncode(patch));
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('Wallet/transaction atomic update failed (${res.statusCode}). Firebase Rules check karein.');
    if (uid == widget.uid && mounted) setState(() { _wallet = bal; _txns.insert(0, {'id': txnId, ...t}); });
  }


  String _dateTimeInput(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  Future<void> _pickDateTime(TextEditingController c) async {
    final now = DateTime.now();
    final seed = DateTime.tryParse(c.text.trim().replaceFirst(' ', 'T')) ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(context: context, initialDate: seed, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(now.year + 5));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(seed));
    if (time == null || !mounted) return;
    c.text = _dateTimeInput(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
  String _smartMatchTime(Map m) {
    final ms = _num(m['startAt']);
    if (ms <= 0) return (m['time'] ?? 'Not set').toString();
    final d = DateTime.fromMillisecondsSinceEpoch(ms), now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day), date = DateTime(d.year, d.month, d.day);
    final diff = date.difference(today).inDays;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final day = diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : '${weekdays[d.weekday - 1]}, ${d.day}');
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$day, ${d.day} ${months[d.month - 1]} • ${hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool _matchClosed(Map m) { final c = _num(m['closeAt']); return m['status'] == 'CLOSED' || (c > 0 && _clock.millisecondsSinceEpoch >= c); }
  bool _isMatchCompleted(Map m) => m['status'] == 'COMPLETED' || m['completed'] == true;
  int _roomReleaseTime(Map m) {
    final start = _num(m['startAt']);
    if (start > 0) return start - const Duration(minutes: 15).inMilliseconds;
    return _num(m['roomReleaseAt']);
  }
  bool _roomAvailable(Map m) {
    // Credentials saved by Admin/Co-Admin are visible immediately.
    // Match start time and the old 15-minute release timestamp do not hide them.
    return (m['rId'] ?? '').toString().trim().isNotEmpty &&
        (m['rPass'] ?? '').toString().trim().isNotEmpty;
  }
  String _timeLabel(dynamic raw) { final ms = _num(raw); if (ms <= 0) return 'Not set'; final d = DateTime.fromMillisecondsSinceEpoch(ms); return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }

  void _editMatchTiming(Map m) {
    final now = DateTime.now();
    final start = DateTime.fromMillisecondsSinceEpoch(_num(m['startAt']) > 0 ? _num(m['startAt']) : now.add(const Duration(hours: 1)).millisecondsSinceEpoch);
    final room = DateTime.fromMillisecondsSinceEpoch(_num(m['roomReleaseAt']) > 0 ? _num(m['roomReleaseAt']) : now.add(const Duration(minutes: 45)).millisecondsSinceEpoch);
    final startC = TextEditingController(text: _dateTimeInput(start));
    final roomC = TextEditingController(text: _dateTimeInput(room));
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Edit Match Date & Time'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: startC, readOnly: true, onTap: () => _pickDateTime(startC), decoration: const InputDecoration(labelText: 'Match Date & Time', suffixIcon: Icon(Icons.calendar_month))),
      const SizedBox(height: 8),
      const Text('Registration auto-close isi selected match date & time par hoga.', style: TextStyle(fontSize: 11, color: Colors.amber)),
      TextField(controller: roomC, readOnly: true, onTap: () => _pickDateTime(roomC), decoration: const InputDecoration(labelText: 'Room ID Release Date & Time', suffixIcon: Icon(Icons.schedule))),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () async {
      final st = DateTime.tryParse(startC.text.trim().replaceFirst(' ', 'T')), rm = DateTime.tryParse(roomC.text.trim().replaceFirst(' ', 'T'));
      if (st == null || rm == null) return _msg('Date/time select karein.');
      final data = {'startAt': st.millisecondsSinceEpoch, 'closeAt': st.millisecondsSinceEpoch, 'roomReleaseAt': st.millisecondsSinceEpoch - const Duration(minutes: 15).inMilliseconds, 'time': _smartMatchTime({'startAt': st.millisecondsSinceEpoch})};
      final res = await http.patch(Uri.parse('$kDbUrl/matches/' + m['id'].toString() + '.json?auth=' + widget.token), body: jsonEncode(data));
      if (res.statusCode >= 200 && res.statusCode < 300) { m.addAll(data); if (mounted) setState(() => _sortMatches()); Navigator.pop(ctx); _msg('Match date/time aur auto-close update ho gaya.'); } else { _msg('Timer save nahi hua. Firebase Rules check karein.'); }
    }, child: const Text('Save Timer'))]));
  }
  Future<void> _toggleMatchHold(Map m) async {
    final hold = m['hold'] != true;
    final res = await http.patch(Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'), body: jsonEncode({'hold': hold}));
    if (res.statusCode >= 200 && res.statusCode < 300) { setState(() => m['hold'] = hold); _msg(hold ? 'Match HOLD par hai; room release ruk gaya.' : 'Match resume kar diya.'); } else { _msg('Hold status save nahi hua.'); }
  }
  void _showPendingDepositsDialog() {
    if (!isSuperAdmin) return _msg('Deposits sirf Super Admin manage kar sakta hai.');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Pending UTR Deposits (${_deps.length})', style: const TextStyle(fontSize: 15)),
      content: SizedBox(width: double.maxFinite, height: 350, child: _deps.isEmpty ? const Center(child: Text('Koi pending deposit nahi hai')) : ListView.builder(itemCount: _deps.length, itemBuilder: (_, i) {
        final d = _deps[i];
        return Card(child: ListTile(title: Text('${d['ign']} • ₹${d['amt']}'), subtitle: Text('UTR: ${d['utr']}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF00E676)), onPressed: () async {
            if (!isSuperAdmin) return _msg('Deposit approve karne ka access sirf Super Admin ko hai.');
            final uid = d['uid'].toString();
            final depositCheck = await http.get(Uri.parse('$kDbUrl/deposits/${d['id']}.json?auth=${widget.token}'));
            if (depositCheck.statusCode != 200 || depositCheck.body.trim() == 'null') return _msg('Deposit record verify nahi hua; approval roki gayi.');
            final liveDeposit = jsonDecode(depositCheck.body);
            if (liveDeposit is! Map || (liveDeposit['status'] ?? '').toString() != 'PENDING') return _msg('Ye deposit pehle hi process ho chuka hai.');
            final userCheck = await http.get(Uri.parse('$kDbUrl/users/$uid.json?auth=${widget.token}'));
            if (userCheck.statusCode != 200 || userCheck.body.trim() == 'null') return _msg('Player wallet record nahi mila.');
            final u = jsonDecode(userCheck.body) as Map;
            final amt = _num(liveDeposit['amt']);
            if (amt <= 0) return _msg('Deposit amount invalid hai.');
            Navigator.pop(ctx);
            final txnId = DateTime.now().microsecondsSinceEpoch.toString();
            final now = DateTime.now();
            final dt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            final patch = <String, dynamic>{
              'users/$uid/wallet': _num(u['wallet']) + amt,
              'users/$uid/txns/$txnId': {'title': 'Wallet Deposit', 'sub': 'UTR: ${d['utr']} • $dt', 'amt': amt, 'status': 'APPROVED', 'time': dt},
              'deposits/${d['id']}/status': 'APPROVED',
              'deposits/${d['id']}/approvedAt': DateTime.now().millisecondsSinceEpoch,
            };
            final res = await http.patch(Uri.parse('$kDbUrl/.json?auth=${widget.token}'), body: jsonEncode(patch));
            if (res.statusCode < 200 || res.statusCode >= 300) return _msg('Deposit approval fail hui. Firebase Rules check karein.');
            _msg('Approved!'); _sync();
          }),
          IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: () async { if (!isSuperAdmin) return _msg('Deposit reject karne ka access sirf Super Admin ko hai.'); Navigator.pop(ctx); await http.patch(Uri.parse('$kDbUrl/deposits/${d['id']}.json?auth=${widget.token}'), body: jsonEncode({'status': 'REJECTED'})); _sync(); }),
        ])));
      })),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  void _showPendingWithdrawalsDialog() {
    if (!isSuperAdmin) return _msg('Withdrawals sirf Super Admin manage kar sakta hai.');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Pending Withdrawals (${_withs.length})', style: const TextStyle(fontSize: 15)),
      content: SizedBox(width: double.maxFinite, height: 350, child: _withs.isEmpty ? const Center(child: Text('Koi pending withdrawal nahi hai')) : ListView.builder(itemCount: _withs.length, itemBuilder: (_, i) {
        final wd = _withs[i];
        return Card(child: ListTile(title: Text('${wd['ign']} • ₹${wd['amt']}'), subtitle: Text('UPI: ${wd['upi']}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.copy, color: Colors.lightBlueAccent), onPressed: () { Clipboard.setData(ClipboardData(text: '${wd['upi']}')); _msg('Player UPI Copied!'); }),
          IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF00E676)), onPressed: () async {
            if (!isSuperAdmin) return _msg('Withdrawal mark paid karne ka access sirf Super Admin ko hai.');
            Navigator.pop(ctx);
            final uid = wd['uid'].toString();
            final u = _users.firstWhere((e) => e['uid'] == uid, orElse: () => {});
            final amt = _num(wd['amt']);
            if (u.isEmpty || _num(u['wallet']) < amt) return _msg('Player wallet balance insufficient hai.');
            final txnId = DateTime.now().microsecondsSinceEpoch.toString();
            final now = DateTime.now();
            final dt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            final patch = <String, dynamic>{
              'users/$uid/wallet': _num(u['wallet']) - amt,
              'users/$uid/txns/$txnId': {'title': 'UPI Withdrawal', 'sub': wd['upi'].toString() + ' • $dt', 'amt': amt, 'status': 'PAID', 'time': dt},
              'withdrawals/${wd['id']}/status': 'PAID',
              'withdrawals/${wd['id']}/approvedAt': now.millisecondsSinceEpoch,
            };
            final res = await http.patch(Uri.parse('$kDbUrl/.json?auth=${widget.token}'), body: jsonEncode(patch));
            if (res.statusCode < 200 || res.statusCode >= 300) return _msg('Withdrawal approval fail hui. Firebase Rules check karein.');
            _msg('Marked Paid; wallet deduction aur txn save hue.'); _sync();
          }),
        ])));
      })),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Future<void> _markMatchCompleted(Map m) async {
    if (!isAdmin || _isMatchCompleted(m)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Match Completed?'),
        content: Text('${m['title'] ?? 'Match'} ko completed mark karna hai?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark Completed')),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await http.patch(
      Uri.parse('$kDbUrl/matches/${m['id']}.json?auth=${widget.token}'),
      body: jsonEncode({'status': 'COMPLETED', 'completed': true, 'completedAt': DateTime.now().millisecondsSinceEpoch}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (mounted) setState(() { m['status'] = 'COMPLETED'; m['completed'] = true; _sortMatches(); });
      _msg('Match COMPLETED mark ho gaya.');
    } else {
      _msg('Match complete mark nahi hua. Firebase Rules check karein.');
    }
  }

  Widget _adminQuickActions() {
    final width = (MediaQuery.of(context).size.width - 44) / 3;
    final completed = _matches.where((dynamic m) => m is Map && _isMatchCompleted(m)).map((dynamic m) => m as Map).toList()
      ..sort((a, b) => _num(b['startAt']).compareTo(_num(a['startAt'])));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (isSuperAdmin) SizedBox(width: width, child: _quickAction(Icons.account_balance_wallet, 'Deposits', _deps.length, _showPendingDepositsDialog)),
          if (isSuperAdmin) SizedBox(width: width, child: _quickAction(Icons.payments, 'Withdrawals', _withs.length, _showPendingWithdrawalsDialog)),
          SizedBox(width: width, child: _quickAction(Icons.groups, 'All Players', _users.length, _showAllPlayersDialog)),
          if (isSuperAdmin) SizedBox(width: width, child: _quickAction(Icons.admin_panel_settings, 'Co-Admin', _activeCoAdminCount, _showCoAdminDialog)),
          SizedBox(width: width, child: _quickAction(Icons.add, '+ Create', null, _addMatch)),
          SizedBox(width: width, child: _quickAction(Icons.check_circle, 'Completed', completed.length, () => _showCompletedMatchesDialog(completed), iconColor: const Color(0xFF00E676), badgeColor: const Color(0xFF00E676))),
        ],
      ),
    );
  }

  void _showCompletedMatchesDialog(List<Map> completed) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Completed Matches (${completed.length})', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 440,
        child: completed.isEmpty
            ? const Center(child: Text('Abhi koi completed match nahi hai.'))
            : ListView.builder(
                itemCount: completed.length,
                itemBuilder: (_, i) {
                  final m = completed[i];
                  final count = _matchPlayerCount(m);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${m['title'] ?? 'Match'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${m['map'] ?? '-'} • ${m['mode'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_smartMatchTime(m), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF00E676).withOpacity(.16), borderRadius: BorderRadius.circular(8)), child: const Text('COMPLETED', style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 8),
                          Text('$count/${_num(m['slots'])} Players', style: const TextStyle(fontSize: 11)),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          OutlinedButton(onPressed: () => _showPlayers(m), child: const Text('Players')),
                          OutlinedButton(onPressed: () => _showMatchHisaab(m), child: const Text('Hisaab')),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Widget _quickAction(IconData icon, String label, int? count, VoidCallback onTap, {Color iconColor = const Color(0xFFFF9800), Color badgeColor = const Color(0xFFFF9800)}) => Card(margin: EdgeInsets.zero, child: InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 19, color: iconColor), if (count != null) ...[const SizedBox(width: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)), child: Text('$count', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)))] ]),
      const SizedBox(height: 4), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    ])),
  ));

  void _showAllPlayersDialog() {
    if (!isAdmin) return;
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                              final ign = (u['ign'] ?? 'Player').toString();
                              final wallet = _num(u['wallet']);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ign,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '₹$wallet',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (u['email'] ?? '-').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                      Text(
                                        'BGMI ID: ${u['bgmiId'] ?? '-'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                      const SizedBox(height: 7),
                                      Row(
                                        children: [
                                          if (isSuperAdmin) Expanded(
                                            child: TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFF00E676),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                                                visualDensity: VisualDensity.compact,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.add_circle, size: 16),
                                              label: const Text('Add Balance', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11)),
                                              onPressed: () => _addManualBalance(u),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.lightBlueAccent,
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                                                visualDensity: VisualDensity.compact,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.history, size: 16),
                                              label: const Text('History', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11)),
                                              onPressed: () => _showHistory(u),
                                            ),
                                          ),
                                          if (isSuperAdmin) Expanded(
                                            child: TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFFFF9800),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                                                visualDensity: VisualDensity.compact,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.emoji_events, size: 16),
                                              label: const Text('Prize', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11)),
                                              onPressed: () => _sendPrize(u),
                                            ),
                                          ),
                                        ],
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

  int _historyTimestamp(Map entry) {
    for (final key in ['createdAt', 'timestamp', 'timeStamp', 'updatedAt', 'date']) {
      final value = entry[key];
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed < 100000000000 ? parsed * 1000 : parsed;
      if (value is String) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
    }
    final rawTime = (entry['time'] ?? '').toString().trim();
    final parsedTime = DateTime.tryParse(rawTime);
    if (parsedTime != null) return parsedTime.millisecondsSinceEpoch;
    // Legacy history strings use dd/MM/yyyy HH:mm.
    final dateAndTime = rawTime.split(' ');
    if (dateAndTime.length == 2) {
      final dateParts = dateAndTime[0].split('/');
      final timeParts = dateAndTime[1].split(':');
      if (dateParts.length == 3 && timeParts.length == 2) {
        final day = int.tryParse(dateParts[0]);
        final month = int.tryParse(dateParts[1]);
        final year = int.tryParse(dateParts[2]);
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (day != null && month != null && year != null && hour != null && minute != null &&
            month >= 1 && month <= 12 && day >= 1 && day <= 31 && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return DateTime(year, month, day, hour, minute).millisecondsSinceEpoch;
        }
      }
    }
    // Wallet transaction keys are generated from microsecondsSinceEpoch.
    final id = int.tryParse((entry['id'] ?? '').toString());
    if (id != null && id > 0) return id > 100000000000000 ? id ~/ 1000 : id;
    return 0;
  }

  String _formatHistoryDateTime(Map entry) {
    final millis = _historyTimestamp(entry);
    if (millis <= 0) return 'Date/time unavailable';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString().padLeft(4, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _showHistory([Map? player]) {
    final list = [];
    final target = player == null ? _users : [player];
    for (final u in target) {
      if (u['txns'] is Map) {
        (u['txns'] as Map).forEach((txnKey, v) {
          if (v is Map) list.add({
            ...Map<String, dynamic>.from(v),
            'id': txnKey.toString(),
            'ign': u['ign'] ?? 'Player',
            '_historyKind': 'wallet',
          });
        });
      }
    }
    list.sort((a, b) => _historyTimestamp(b).compareTo(_historyTimestamp(a)));
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
                      subtitle: Text(
                        '${t['sub'] ?? ''} • ${t['status'] ?? ''}\n${_formatHistoryDateTime(t)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text('₹${t['amt']}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }


  Future<void> _showTimedAd({required String title, required String url, required int? seconds, required VoidCallback onContinue}) async {
    final trimmedUrl = url.trim();
    final uri = _resolveAdTarget(trimmedUrl);
    if (trimmedUrl.isEmpty || uri == null) {
      if (seconds == null) {
        _msg('Reward Ad link valid nahi hai. Admin se valid Adsterra URL set karwayein.');
        return;
      }
      onContinue();
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdViewerDialog(title: title, url: uri.toString(), seconds: seconds, onContinue: onContinue, openExternalOnClose: seconds == null),
    );
  }

  void _startJoinAd(Map m) {
    _showTimedAd(title: 'Sponsored Link', url: _joinAdUrl, seconds: 10, onContinue: () => _join(m));
  }

  void _showRoomAfterAd(Map m) {
    // Room details are shown directly; the match release-time check remains active.
    if (!mounted) return;
      if (!_roomAvailable(m)) {
        showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Room ID / Password'),
          content: const Text('Room ID & Password match start hone se 15 minutes pehle yahin show hoga.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ));
        return;
      }
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Match Room Details'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_slotNumberFor(m, widget.uid) > 0)
            Align(alignment: Alignment.centerLeft, child: Text('Your Slot: #${_slotNumberFor(m, widget.uid)}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: SelectableText('Room ID: ${m['rId']}')),
            TextButton.icon(onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '${m['rId'] ?? ''}'));
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Room ID copied!')));
            }, icon: const Icon(Icons.copy, size: 16), label: const Text('Copy')),
          ]),
          Row(children: [
            Expanded(child: SelectableText('Password: ${m['rPass']}')),
            TextButton.icon(onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '${m['rPass'] ?? ''}'));
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password copied!')));
            }, icon: const Icon(Icons.copy, size: 16), label: const Text('Copy')),
          ]),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
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
      'adsterraBannerCode': _adsterraBannerCodeController.text.trim(),
      'autoBannerAdEnabled': _autoBannerAdEnabled,
    };
    _adsterraBannerCode = _adsterraBannerCodeController.text.trim();
    final res = await http.patch(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'), body: jsonEncode(data));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _msg('Join/Room Ads aur Promo settings saved!');
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
    final found = !privileged && badWords.any((w) => RegExp(r'(^|[^a-z])' + RegExp.escape(w) + r'([^a-z]|$)', caseSensitive:false).hasMatch(msg));
    if (found) {
      final strikes = _num(mod['strikes']) + 1;
      if (strikes == 1) return _msg('Warning 1/3: abusive language allowed nahi hai.');
      return _msg('Abusive language allowed nahi hai. Agla message bhejne se pehle language change karein.');
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
    // reverse:true ke saath newest message index 0 par rakhein.
    final sorted = [..._chatMessages]..sort((a,b) => _num(b['createdAt']).compareTo(_num(a['createdAt'])));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(10), child: Row(children: [const Expanded(child: Text('SK ESPORTS Community Chat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800)))), IconButton(onPressed: _loadChat, icon: const Icon(Icons.refresh))])),
      Expanded(child: sorted.isEmpty ? const Center(child: Text('Abhi chat khaali hai. Pehla message bhejein!')) : ListView.builder(
        reverse: true,
        shrinkWrap: false,
        itemCount: sorted.length,
        itemBuilder: (_, i) {
        final m = sorted[i];
        final ign = m['ign']?.toString() ?? 'Player';
        return Card(child: ListTile(
          leading: CircleAvatar(child: Text(ign.isNotEmpty ? ign[0].toUpperCase() : 'P')),
          title: Row(children: [Expanded(child: Text(ign, style: const TextStyle(fontWeight: FontWeight.bold))), if (m['pinned'] == true) const Icon(Icons.push_pin, color: Colors.amber, size: 16)]),
          subtitle: Text(m['message']?.toString() ?? ''),
          trailing: isSuperAdmin ? PopupMenuButton<String>(onSelected: (v) => _chatAction(m, v), itemBuilder: (_) => [PopupMenuItem(value: 'pin', child: Text(m['pinned'] == true ? 'Unpin' : 'Pin')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]) : null,
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
  int get _activeCoAdminCount => _users.where((u) => u['email']?.toString().toLowerCase() != kAdmin.toLowerCase() && u['role'] == 'coadmin').length;


  void _showCoAdminDialog() {
    if (!isSuperAdmin) return;
    final searchC = TextEditingController();
    int selectedTab = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = searchC.text.trim().toLowerCase();
          final players = _users.where((u) {
            if (u['email']?.toString().toLowerCase() == kAdmin.toLowerCase()) return false;
            final name = (u['name'] ?? '').toString().toLowerCase();
            final ign = (u['ign'] ?? '').toString().toLowerCase();
            final email = (u['email'] ?? '').toString().toLowerCase();
            return q.isEmpty || name.contains(q) || ign.contains(q) || email.contains(q);
          }).toList();
          final coAdmins = players.where((u) => u['role'] == 'coadmin').toList();
          final active = coAdmins.length;
          final visibleUsers = selectedTab == 0 ? players : coAdmins;

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text('Co-Admin Management ($active)', style: const TextStyle(fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              height: 460,
              child: Column(
                children: [
                  TextField(
                    controller: searchC,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search Name, IGN or Email...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('All Players'),
                          selected: selectedTab == 0,
                          onSelected: (_) => setDialogState(() => selectedTab = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('Co-Admins ($active)'),
                          selected: selectedTab == 1,
                          onSelected: (_) => setDialogState(() => selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: visibleUsers.isEmpty
                        ? Center(
                            child: Text(
                              selectedTab == 1 ? 'No Co-Admins added yet' : 'Koi player nahi mila',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: visibleUsers.length,
                            itemBuilder: (_, i) {
                              final u = visibleUsers[i];
                              final isCoAdmin = u['role'] == 'coadmin';
                              final ign = (u['ign'] ?? u['name'] ?? 'Player').toString();
                              final email = (u['email'] ?? '').toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 7),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ign,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          if (isCoAdmin)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF9800).withOpacity(0.18),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'CO-ADMIN',
                                                maxLines: 1,
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF9800)),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              await _toggleCoAdmin(u);
                                              if (ctx.mounted) setDialogState(() {});
                                            },
                                            child: Text(selectedTab == 1 ? 'Remove' : (isCoAdmin ? 'Remove' : 'Make Co-Admin')),
                                          ),
                                        ],
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
    ).then((_) => searchC.dispose());
  }

  Future<void> _configureMatchVotingAdmins(Map match) async {
    if (!isSuperAdmin) return _msg('Voting Admins sirf Super Admin set kar sakta hai.');
    List<Map<String,dynamic>> available;
    try {
      available = await _loadRegisteredAdmins();
    } catch (e) {
      return _msg(e.toString().replaceAll('Exception: ', ''));
    }
    final existing = match['votingAdmins'] is List
        ? List<Map<String,dynamic>>.from((match['votingAdmins'] as List).whereType<Map>().map((x) => Map<String,dynamic>.from(x)))
        : <Map<String,dynamic>>[];
    final selected = <String>{...existing.map((x) => (x['uid'] ?? '').toString()).where((x) => x.isNotEmpty)};
    bool enabled = match['adminSelectionEnabled'] == true || existing.isNotEmpty;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text('Voting Admins • ${match['title'] ?? 'Match'}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 440,
            child: Column(children: [
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Admin Voting ON / OFF'), subtitle: const Text('ON: Player must select one admin before joining. OFF: Selection not required.'), value: enabled, onChanged: (v) => setDialogState(() => enabled = v)),
              const Divider(),
              const Align(alignment: Alignment.centerLeft, child: Text('Select admins for this match:', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 6),
              const SizedBox(height: 6),
              Expanded(child: ListView(
                children: available.map((a) {
                  final uid = (a['uid'] ?? '').toString();
                  final checked = selected.contains(uid);
                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    title: Text((a['name'] ?? 'Admin').toString()),
                    subtitle: Text(a['isSuperAdmin'] == true ? 'Super Admin' : 'Co-Admin'),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        selected.add(uid);
                        enabled = true;
                      } else {
                        selected.remove(uid);
                      }
                    }),
                  );
                }).toList(),
              )),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final chosen = available.where((a) => selected.contains((a['uid'] ?? '').toString())).map((a) => {'uid': a['uid'], 'name': a['name'], 'role': a['role'], 'isSuperAdmin': a['isSuperAdmin'] == true}).toList();
                if (enabled && chosen.isEmpty) return _msg('Voting ON karne ke liye kam se kam ek admin select karein.');
                // Keep the selected admin list when voting is OFF, so it can be
                // re-enabled without selecting every admin again.
                final payload = {'adminSelectionEnabled': enabled, 'votingAdmins': chosen};
                final res = await http.patch(
                  Uri.parse('$kDbUrl/matches/${match['id']}.json?auth=${widget.token}'),
                  body: jsonEncode(payload),
                );
                if (res.statusCode < 200 || res.statusCode >= 300) return _msg('Voting Admin settings save nahi hui. Firebase Rules check karein.');
                match.addAll(payload);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
                _msg(enabled ? '${chosen.length} Voting Admins saved. Player join se pehle admin select karega.' : 'Admin Voting OFF saved.');
              },
              child: const Text('Save Match Admins'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _join(Map m) async {
    // Always read the latest match settings from Firebase before showing Join.
    // The match card can contain stale data if Super Admin changed voting settings
    // after this player's match list was loaded.
    final matchId = (m['id'] ?? '').toString();
    if (matchId.isEmpty) return _msg('Match ID nahi mila. Refresh karke dobara try karein.');
    try {
      final latest = await http.get(Uri.parse('$kDbUrl/matches/$matchId.json?auth=${widget.token}')).timeout(const Duration(seconds: 15));
      if (latest.statusCode != 200 || latest.body.trim() == 'null') {
        return _msg('Latest match settings load nahi hui (HTTP ${latest.statusCode}). Refresh karke try karein.');
      }
      final latestData = jsonDecode(latest.body);
      if (latestData is! Map) return _msg('Match settings invalid hain. Super Admin ko inform karein.');
      m.addAll(Map<String, dynamic>.from(latestData));
      m['id'] = matchId;
    } catch (e) {
      return _msg('Match settings load nahi hui: ${e.toString().replaceAll('Exception: ', '')}');
    }
    final adminOptions = m['votingAdmins'] is List
        ? List<Map<String,dynamic>>.from((m['votingAdmins'] as List).whereType<Map>().map((x) => Map<String,dynamic>.from(x)).where((x) => (x['uid'] ?? '').toString().isNotEmpty))
        : <Map<String,dynamic>>[];
    // Any configured admin list makes voting compulsory, even on older match records.
    // Explicit OFF must be respected even when a saved admin list is retained.
    // Older matches without the flag but with a saved list remain voting-enabled.
    final adminSelectionEnabled = m.containsKey('adminSelectionEnabled')
        ? m['adminSelectionEnabled'] == true
        : adminOptions.isNotEmpty;
    if (adminSelectionEnabled && adminOptions.isEmpty) {
      _msg('Is match ke Voting Admins Super Admin ne abhi set nahi kiye. Admin se configure karwayein.');
      return;
    }
    String selectedAdminUid = '';
    final teamSize = _teamSize(m);
    final mode = (m['mode'] ?? 'SOLO').toString().toUpperCase();
    final nameControllers = List.generate(teamSize, (i) => TextEditingController(text: i == 0 ? _ign : ''));
    final idControllers = List.generate(teamSize, (i) => TextEditingController(text: i == 0 && _bgmiId != 'Not Set' ? _bgmiId : ''));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final fee = _num(m['fee']);
          final baseTotal = fee * teamSize;
          final payable = baseTotal;
          return AlertDialog(
            title: Text('Join $mode • ${m['title']}', style: const TextStyle(fontSize: 15)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Rule: Har teammate ki BGMI Level 30+ ID required.', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
                  const SizedBox(height: 8),
                  if (adminSelectionEnabled) ...[
                    DropdownButtonFormField<String>(
                      value: selectedAdminUid.isEmpty ? null : selectedAdminUid,
                      decoration: const InputDecoration(labelText: 'Select Admin (Required)', border: OutlineInputBorder()),
                      items: adminOptions.map((x) => DropdownMenuItem<String>(value:x['uid'].toString(),child:Text((x['name'] ?? 'Admin').toString()+(x['isSuperAdmin']==true?' • Super Admin':' • Co-Admin'),overflow:TextOverflow.ellipsis))).toList(),
                      onChanged:(v)=>setDialogState(()=>selectedAdminUid=v ?? ''),
                    ),
                    const SizedBox(height:10),
                  ],
                  for (var i = 0; i < teamSize; i++) ...[
                    Align(alignment: Alignment.centerLeft, child: Text(i == 0 ? 'Team Leader' : 'Teammate ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800)))),
                    const SizedBox(height: 5),
                    TextField(controller: nameControllers[i], decoration: InputDecoration(labelText: 'BGMI Name (IGN) • ${i + 1}', border: const OutlineInputBorder())),
                    const SizedBox(height: 7),
                    TextField(controller: idControllers[i], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'BGMI ID • ${i + 1}', border: const OutlineInputBorder())),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Entry Fee: ₹$baseTotal',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                onPressed: () async {
                  if(adminSelectionEnabled && selectedAdminUid.isEmpty) return _msg('Join confirm se pehle Admin select karein.');
                  final selectedAdmin = adminSelectionEnabled
                      ? adminOptions.firstWhere((x)=>x['uid'].toString()==selectedAdminUid)
                      : <String,dynamic>{};
                  final members = <Map<String, dynamic>>[];
                  for (var i = 0; i < teamSize; i++) {
                    final ign = nameControllers[i].text.trim();
                    final bgmiId = idControllers[i].text.trim();
                    if (ign.isEmpty || bgmiId.length < 10 || bgmiId.length > 11 || !RegExp(r'^\d{10,11}$').hasMatch(bgmiId)) {
                      return _msg('Teammate ${i + 1} ka sahi BGMI Name aur 10–11 digit ID dalein.');
                    }
                    members.add({'ign': ign, 'bgmiId': bgmiId});
                  }
                  if (_matchClosed(m) || _matchPlayerCount(m) >= _num(m['slots'])) {
                    Navigator.pop(ctx);
                    return _msg('Join band ho chuka hai ya team slots full hain.');
                  }
                  if (_wallet < payable) {
                    Navigator.pop(ctx);
                    setState(() => _tab = 1);
                    return _msg('Main Wallet balance kam hai!');
                  }
                  final oldBalance = _wallet;
                  final playerBalance = oldBalance - payable;
                  final now = DateTime.now();
                  final txnId = now.microsecondsSinceEpoch.toString();
                  final dt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                  final leader = members.first;
                  final slotNumber = _nextSlotNumber(m);
                  final roster = <String, dynamic>{
                    'slotNumber': slotNumber,
                    'ign': leader['ign'],
                    'bgmiId': leader['bgmiId'],
                    'members': members,
                    'teamSize': teamSize,
                    'joinedAt': now.millisecondsSinceEpoch,
                    'feePaid': payable,
                    'baseFee': baseTotal,
                    if (adminSelectionEnabled) 'selectedAdminUid': selectedAdminUid,
                    if (adminSelectionEnabled) 'selectedAdminName': (selectedAdmin['name'] ?? 'Admin').toString(),
                  };
                  final txn = {
                    'title': 'Joined: ${m['title']}',
                    'sub': '$mode • $teamSize member(s) • Entry ₹$baseTotal • $dt',
                    'amt': payable,
                    'status': 'PAID',
                    'time': dt,
                  };
                  Navigator.pop(ctx);
                  try {
                    final patch = <String, dynamic>{
                      'users/${widget.uid}/wallet': playerBalance,
                      'users/${widget.uid}/ign': leader['ign'],
                      'users/${widget.uid}/bgmiId': leader['bgmiId'],
                      'users/${widget.uid}/txns/$txnId': txn,
                      'matches/${m['id']}/players/${widget.uid}': roster,
                      };

                    final res = await http.patch(Uri.parse('$kDbUrl/.json?auth=${widget.token}'), body: jsonEncode(patch));
                    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('Atomic join fail hua (${res.statusCode}): ${res.body}. Wallet/slot update nahi hua.');
                    if (mounted) setState(() {
                      _ign = leader['ign'].toString();
                      _bgmiId = leader['bgmiId'].toString();
                      _wallet = playerBalance;
                      _txns.insert(0, {'id': txnId, ...txn});
                      final players = m['players'] is Map ? Map<String, dynamic>.from(m['players']) : <String, dynamic>{};
                      players[widget.uid] = roster;
                      m['players'] = players;
                      m['joined'] = players.length;
                      m['isJoined'] = true;
                    });
                    _msg('Team slot confirmed! Main Wallet ₹$payable paid.');
                  } catch (err) {
                    _msg(err.toString().replaceAll('Exception: ', ''));
                    _sync();
                  }
                },
                child: const Text('CONFIRM JOIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      for (final c in nameControllers) { c.dispose(); }
      for (final c in idControllers) { c.dispose(); }
    });
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
                        final depositId = DateTime.now().microsecondsSinceEpoch.toString();
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final patch = <String, dynamic>{
                          'usedUtrs/$utr': {'uid': widget.uid, 'depositId': depositId, 'createdAt': now},
                          'deposits/$depositId': {
                            'uid': widget.uid,
                            'ign': _ign,
                            'amt': amt,
                            'utr': utr,
                            'status': 'PENDING',
                            'createdAt': now,
                          },
                        };
                        Navigator.pop(ctx);
                        final res = await http.patch(Uri.parse('$kDbUrl/.json?auth=${widget.token}'), body: jsonEncode(patch));
                        if (res.statusCode < 200 || res.statusCode >= 300) {
                          return _msg('UTR submit nahi hua. Ho sakta hai ye UTR pehle use ho chuka ho.');
                        }
                        _msg('UTR Submitted! Admin verify karte hi wallet mein add hoga.');
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
              final requestId = DateTime.now().microsecondsSinceEpoch.toString();
              Navigator.pop(ctx);
              final res = await http.put(
                Uri.parse('$kDbUrl/withdrawals/$requestId.json?auth=${widget.token}'),
                body: jsonEncode({
                  'uid': widget.uid,
                  'ign': _ign,
                  'upi': upiC.text.trim(),
                  'amt': v,
                  'status': 'PENDING',
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                }),
              );
              if (res.statusCode < 200 || res.statusCode >= 300) return _msg('Withdrawal request save nahi hui.');
              _msg('Withdrawal request bhej di. Wallet deduction Super Admin approval par hoga.');
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
        feeC = TextEditingController(text: '30'),
        killC = TextEditingController(text: '20'),
        winC = TextEditingController(text: '175'),
        startC = TextEditingController(text: _dateTimeInput(DateTime.now().add(const Duration(hours: 1)))),
        roomC = TextEditingController(text: _dateTimeInput(DateTime.now().add(const Duration(minutes: 45))));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Match', style: TextStyle(fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: tC, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: mapC, decoration: const InputDecoration(labelText: 'Map (Erangel/Miramar/Vikendi/Livik)')),
            TextField(controller: modeC, decoration: const InputDecoration(labelText: 'Mode (SOLO/SQUAD)')),
            TextField(controller: startC, readOnly: true, onTap: () => _pickDateTime(startC), decoration: const InputDecoration(labelText: 'Match Date & Time', suffixIcon: Icon(Icons.calendar_month))),
            const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('Registration auto-close selected match date & time par hoga.', style: TextStyle(fontSize: 11, color: Colors.amber))),
            TextField(controller: roomC, readOnly: true, onTap: () => _pickDateTime(roomC), decoration: const InputDecoration(labelText: 'Room ID Release Date & Time', suffixIcon: Icon(Icons.schedule))),
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
              final st = parseTime(startC.text), rm = parseTime(roomC.text);
              if (st == null || rm == null) return _msg('Calendar se match date/time aur room release select karein.');
              Navigator.pop(ctx);
              final created = await http.post(
                Uri.parse('$kDbUrl/matches.json?auth=${widget.token}'),
                body: jsonEncode({
                  'title': tC.text.trim(),
                  'map': mapC.text.trim(),
                  'mode': modeC.text.trim().toUpperCase(),
                  'time': _smartMatchTime({'startAt': st.millisecondsSinceEpoch}),
                  'startAt': st.millisecondsSinceEpoch,
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                  'closeAt': st.millisecondsSinceEpoch,
                  'roomReleaseAt': st.millisecondsSinceEpoch - const Duration(minutes: 15).inMilliseconds,
                  'hold': false,
                  'status': 'OPEN',
                  'fee': _num(feeC.text),
                  'kill': _num(killC.text),
                  'win': _num(winC.text),
                  'slots': (mapC.text.trim().toLowerCase().contains('livik') ? 52 : 100) ~/ ((modeC.text.trim().toUpperCase().contains('SQUAD')) ? 4 : (modeC.text.trim().toUpperCase().contains('DUO') ? 2 : 1)),
                              'joined': 0,
            'rId': '15 min before match',
            'rPass': '****',


                }),
              );
              if (created.statusCode >= 200 && created.statusCode < 300) {
                final key = (jsonDecode(created.body) as Map)['name']?.toString();
                if (key != null) {
                  final fresh = {'title': tC.text.trim(), 'collection': 0, 'prizeSent': 0, 'settled': false, 'status': 'OPEN', 'updatedAt': DateTime.now().millisecondsSinceEpoch};
                  await http.put(Uri.parse('$kDbUrl/match_hisaab/$key.json?auth=${widget.token}'), body: jsonEncode(fresh));
                }
              }
              _msg('Match Live!');
              _sync();
            },
            child: const Text('Publish', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addManualBalance(Map u) {
    if (!isSuperAdmin) return _msg('Add Balance ka access sirf Super Admin ko hai.');
    final amountC = TextEditingController();
    final reasonC = TextEditingController(text: 'Manual Bonus / Refund');
    final uid = (u['uid'] ?? '').toString();
    if (uid.isEmpty) return _msg('Player UID nahi mila.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Balance • ${u['ign'] ?? 'Player'}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Current balance: ₹${_num(u['wallet'])}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
          TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Add Amount (₹)')),
          TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Reason (Bonus / Refund / Test)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () async {
              if (!isSuperAdmin) return _msg('Add Balance ka access sirf Super Admin ko hai.');
              final amount = _num(amountC.text.trim());
              final reason = reasonC.text.trim();
              if (amount <= 0 || reason.isEmpty) return _msg('Valid amount aur reason dalein.');
              Navigator.pop(ctx);
              try {
                final latest = await http.get(Uri.parse('$kDbUrl/users/$uid.json?auth=${widget.token}'));
                if (latest.statusCode != 200 || latest.body == 'null') throw Exception('Player account nahi mila.');
                final player = jsonDecode(latest.body) as Map;
                final oldBalance = _num(player['wallet']);
                final newBalance = oldBalance + amount;
                await _saveTxn(uid, newBalance, reason, 'Manual credit by SK ESPORTS Admin', amount, 'CREDITED');
                _msg('₹$amount ${u['ign'] ?? 'Player'} ke wallet mein add ho gaye.');
                await _sync();
              } catch (e) {
                _msg(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Add Balance', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  void _sendPrize(Map u, {Map? match}) {
    if (!isSuperAdmin) return _msg('Prize bhejne ka access sirf Super Admin ko hai.');
    final amtC = TextEditingController(), noteC = TextEditingController(text: 'Winning Prize');
    final uid = (u['uid'] ?? '').toString().trim();
    if (uid.isEmpty) return _msg('Recipient UID nahi mila.');
    final eligible = match != null
        ? <Map>[if (match['players'] is Map && (match['players'] as Map).containsKey(uid)) match]
        : _matches.where((m) => m is Map && m['players'] is Map && (m['players'] as Map).containsKey(uid)).cast<Map>().toList();
    if (eligible.isEmpty) return _msg('Is exact player/team UID ka selected match roster mein nahi mila.');
    String selectedId = eligible.first['id'].toString();
    final boundMatchId = match?['id']?.toString();
    final roster = match != null && match['players'] is Map ? (match['players'] as Map)[uid] : null;
    final rosterIgn = roster is Map ? (roster['ign'] ?? u['ign'] ?? 'Player').toString() : (u['ign'] ?? 'Player').toString();
    final slot = roster is Map ? _num(roster['slotNumber']) : 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Send Prize to $rosterIgn${slot > 0 ? ' • Slot #$slot' : ''}', style: const TextStyle(fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: selectedId,
            decoration: const InputDecoration(labelText: 'Select Match'),
            items: eligible.map((m) => DropdownMenuItem<String>(value: m['id'].toString(), child: Text((m['title'] ?? 'Match').toString(), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: boundMatchId != null ? null : (v) { if (v != null) setDialogState(() => selectedId = v); },
          ),
          Text('Recipient UID: $uid', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
          TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () async {
              if (!isSuperAdmin) return _msg('Prize bhejne ka access sirf Super Admin ko hai.');
              final add = _num(amtC.text);
              if (add <= 0) return _msg('Valid prize amount dalein.');
              final chosen = eligible.firstWhere((m) => m['id'].toString() == selectedId);
              if (boundMatchId != null && chosen['id'].toString() != boundMatchId) return _msg('Selected match binding mismatch. Dobara Players list kholein.');
              final selectedRoster = chosen['players'] is Map ? (chosen['players'] as Map)[uid] : null;
              if (selectedRoster is! Map) return _msg('Is match mein ye exact UID ab joined nahi hai.');
              Navigator.pop(ctx);
              try {
                final latest = await http.get(Uri.parse('$kDbUrl/users/$uid.json?auth=${widget.token}'));
                if (latest.statusCode != 200 || latest.body == 'null') throw Exception('Selected recipient account nahi mila.');
                final latestUser = jsonDecode(latest.body) as Map;
                final bal = _num(latestUser['wallet']) + add;
                final exactIgn = (selectedRoster['ign'] ?? latestUser['ign'] ?? 'Player').toString();
                await _saveTxn(uid, bal, noteC.text.trim(), 'SK ESPORTS Admin • ${chosen['title']} • $exactIgn', add, 'CREDITED');
                await _addMatchPrize(selectedId, chosen['title'].toString(), add);
                _msg('₹$add prize $exactIgn (UID matched) ke wallet mein credit ho gaya.');
                await _sync();
              } catch (e) { _msg(e.toString().replaceAll('Exception: ', '')); }
            },
            child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      )),
    );
  }
  void _showPlayers(Map m) {
    final pMap = m['players'] is Map ? m['players'] as Map : {};
    final originalEntries = pMap.entries.toList();
    final originalPositions = <String, int>{for (var i = 0; i < originalEntries.length; i++) originalEntries[i].key.toString(): i + 1};
    final list = originalEntries..sort((a, b) {
      final ap = a.value is Map ? _num((a.value as Map)['slotNumber']) : 0;
      final bp = b.value is Map ? _num((b.value as Map)['slotNumber']) : 0;
      final aSlot = ap > 0 ? ap : (originalPositions[a.key.toString()] ?? 0);
      final bSlot = bp > 0 ? bp : (originalPositions[b.key.toString()] ?? 0);
      return aSlot.compareTo(bSlot);
    });
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
                      title: Text('Slot #${_num(p['slotNumber']) > 0 ? p['slotNumber'] : i + 1} • ${p['ign'] ?? u['ign'] ?? 'Player'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        p['members'] is List
                          ? (p['members'] as List).asMap().entries.map((e) => '${e.key + 1}. ${(e.value as Map)['ign'] ?? '-'} • ID: ${(e.value as Map)['bgmiId'] ?? '-'}').join('\n')
                          : 'ID: ${p['bgmiId'] ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isSuperAdmin ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), padding: const EdgeInsets.symmetric(horizontal: 10)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendPrize({'uid': uid, 'ign': p['ign'] ?? u['ign'] ?? 'Player'}, match: m);
                        },
                        child: const Text('Send Prize', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                      ) : null,
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showPaymentSettingsDialog() {
    if (!isSuperAdmin) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PAYMENT METHOD / UPI DETAILS', style: TextStyle(color: Color(0xFFFF9800), fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _upiC, decoration: const InputDecoration(labelText: 'Your UPI ID (Auto QR)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _qrC, decoration: const InputDecoration(labelText: 'Custom QR Image URL (Optional)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), minimumSize: const Size.fromHeight(42)),
                onPressed: () async {
                  _upiId = _upiC.text.trim();
                  _qrUrl = _qrC.text.trim();
                  final res = await http.patch(Uri.parse('$kDbUrl/config.json?auth=${widget.token}'), body: jsonEncode({'upiId': _upiId, 'qrUrl': _qrUrl}));
                  if (res.statusCode < 200 || res.statusCode >= 300) return _msg('Payment details save nahi hue.');
                  _msg('New Payment QR Live!');
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Update QR Live', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget build(BuildContext context) {
    final showPromo = _promoEnabled && _promoImageUrl.isNotEmpty;
    final showAutoAd = _autoBannerAdEnabled && _adsterraBannerCode.trim().isNotEmpty;
    final showBanner = showPromo;
    final showQuickActions = isAdmin;
    final leadingItems = (showBanner ? 1 : 0) + (showQuickActions ? 1 : 0);
    final pages = [
      Column(children: [
        Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _matches.length + leadingItems,
        itemBuilder: (_, i) {
          if (showPromo && i == 0) {
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
          final quickIndex = showPromo ? 1 : 0;
          if (showQuickActions && i == quickIndex) return _adminQuickActions();
          final m = _matches[i - leadingItems],
              joined = m['isJoined'] == true,
              isFull = _matchPlayerCount(m) >= _num(m['slots']),
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
                  'Time: ${_smartMatchTime(m)} | Entry: ₹${m['fee']} | Kill: ₹${m['kill']} | Win: ₹${m['win']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_isMatchCompleted(m)) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF00E676).withOpacity(.16), borderRadius: BorderRadius.circular(8)), child: const Text('COMPLETED', style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Text('${_matchPlayerCount(m)}/${_num(m['slots'])} Players', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                ],
                Text('Join: ${_isMatchCompleted(m) ? 'COMPLETED' : (closed ? 'CLOSED' : 'OPEN')} • Room: ${m['hold'] == true ? 'HOLD' : (roomReady ? 'RELEASED' : '15 min before match')}', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                if (joined || isAdmin) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    ElevatedButton(
                      onPressed: () => _showRoomAfterAd(m),
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

                                      if (isAdmin) ...[
                        OutlinedButton(
                          onPressed: () => _showPlayers(m),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                          child: const Text('Players', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        if (isSuperAdmin) OutlinedButton.icon(
                          onPressed: () => _configureMatchVotingAdmins(m),
                          icon: const Icon(Icons.how_to_vote, size: 14),
                          label: Text(m['adminSelectionEnabled'] == true ? 'Edit Voting Admins' : 'Set Voting Admins', style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(onPressed: () => _showAdminSelectionLeaderboard(m), child: const Text('Admin Picks', style: TextStyle(fontSize: 11))),
                        const SizedBox(width: 6),
                        if (!_isMatchCompleted(m)) OutlinedButton(
                          onPressed: () => _markMatchCompleted(m),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero, foregroundColor: const Color(0xFF00E676)),
                          child: const Text('Complete', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        if (isSuperAdmin) OutlinedButton.icon(
                          onPressed: () => _showMatchHisaab(m),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00E676),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            minimumSize: Size.zero,
                            side: const BorderSide(color: Color(0xFF00E676)),
                          ),
                          icon: const Icon(Icons.account_balance_wallet, size: 14),
                          label: const Text('₹ Hisaab', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      const Spacer(),
                      Text('${_matchPlayerCount(m)}/${m['slots']} Joined', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ElevatedButton( 

                    style: ElevatedButton.styleFrom(
                      backgroundColor: joined ? const Color(0xFF00E676) : const Color(0xFFFF9800),
                    ),
                    onPressed: (joined || isFull || closed || isSuperAdmin) ? null : () => _startJoinAd(m),
                    child: Text(
                      joined ? 'JOINED ✓${_slotNumberFor(m, widget.uid) > 0 ? '  •  SLOT #${_slotNumberFor(m, widget.uid)}' : ''}' : (closed ? 'CLOSED' : (isFull ? 'FULL' : (isSuperAdmin ? 'SUPER ADMIN' : 'Join ₹${m['fee']}'))),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
        )),
        if (showAutoAd)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: SizedBox(width: 320, height: 50,
                  child: AdsterraBanner(code: _adsterraBannerCode)),
              ),
            ),
          ),
      ]),
      _walletPage(),
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

          ],
          if (isSuperAdmin) Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ADSTERRA & PROMO SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                const SizedBox(height: 8),
                TextField(controller: _joinAdUrlController, decoration: const InputDecoration(labelText: 'Join Ad Direct Link (10 sec)')),
                const SizedBox(height: 8),
                TextField(controller: _roomAdUrlController, decoration: const InputDecoration(labelText: 'Legacy Room Ad URL (unused)')),
                const SizedBox(height: 8),
                TextField(controller: _promoImageUrlController, decoration: const InputDecoration(labelText: 'Promo Image URL')),
                const SizedBox(height: 8),
                TextField(controller: _promoClickUrlController, decoration: const InputDecoration(labelText: 'Promo Click URL')),
                const SizedBox(height: 8),
                TextField(
                  controller: _adsterraBannerCodeController,
                  minLines: 4,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Adsterra Banner Code / Key (320×50)',
                    hintText: 'Paste the complete Adsterra HTML / JavaScript banner code',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto Banner Ad ON / OFF'),
                  subtitle: const Text('Personal promo ON hone par automatic banner hide rahega.'),
                  value: _autoBannerAdEnabled,
                  onChanged: (v) => setState(() => _autoBannerAdEnabled = v),
                ),
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
                const Text('Join button ad link yahin se control hota hai. Custom promo top par aur Adsterra banner bottom par dikhega.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
          ),
          if (isSuperAdmin) ...[
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ABOUT LINKS & RULES EDITOR', style: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('Har line: Button Name | https://link', style: TextStyle(fontSize: 11, color: Colors.grey)), TextField(controller: _aboutLinksC, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Social / Support Links', border: OutlineInputBorder())), const SizedBox(height: 8), TextField(controller: _rulesC, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Rules (BGMI Level 30+ etc.)', border: OutlineInputBorder())), ElevatedButton(onPressed: _saveAboutRules, child: const Text('Save About & Rules'))]))),
          ],
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          if (isSuperAdmin) ...[
          TextButton.icon(
            onPressed: _showHistory,
            icon: const Icon(Icons.history, size: 18, color: Color(0xFFFF9800)),
            label: const Text('All Players History', style: TextStyle(color: Color(0xFFFF9800))),
          ),
          ],

    ]),
]; 
    // Keep Wallet in its original second-tab position for players and Co-Admins.
    // Super Admin gets the Finance dashboard in that same second-tab position.
    final navPages = isSuperAdmin
        ? [pages[0], pages[1], pages[3], pages[4], pages[2]]
        : isAdmin
            ? [pages[0], pages[1], pages[3], pages[4], pages[2]]
            : [pages[0], pages[1], pages[3], pages[2]];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('SK ESPORTS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _sync),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('My Wallet & Earnings'),
                      backgroundColor: const Color(0xFF161B22),
                    ),
                    body: pages[1],
                  )));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.account_balance_wallet, color: Color(0xFF00E676), size: 18), const SizedBox(width: 4), Text('₹$_wallet', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676), fontSize: 17))]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : navPages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tab,
        selectedItemColor: const Color(0xFFFF9800),
        onTap: (i) {
          if (isSuperAdmin && i == 1) {
            _showFinanceDashboard();
            return;
          }
          setState(() => _tab = i);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Matches'),
          BottomNavigationBarItem(
            icon: Icon(isSuperAdmin ? Icons.analytics : Icons.account_balance_wallet),
            label: isSuperAdmin ? 'Finance' : 'Wallet',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          if (isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

}
