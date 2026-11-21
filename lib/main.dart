import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFF9800), secondary: Color(0xFF00E676)),
      ),
      home: const UserHomeScreen(),
    );
  }
}

class MatchModel {
  final String title, map, mode, time;
  final int entryFee, perKill, chickenDinner, maxSlots;
  int joinedCount;
  bool isJoined;
  String roomId, roomPass;

  MatchModel({
    required this.title, required this.map, required this.mode, required this.time,
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
  const UserHomeScreen({super.key});
  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _tab = 0, _wallet = 100;
  String _ign = 'SK_Player01', _bgmiId = '5123456789';

  final List<MatchModel> _matches = [
    MatchModel(title: 'SK ESPORTS Solo Rush #1', map: 'Erangel', mode: 'SOLO', time: 'Today, 08:00 PM', entryFee: 30, perKill: 20, chickenDinner: 175, maxSlots: 100, joinedCount: 42, roomId: '8849201', roomPass: 'SK2026'),
    MatchModel(title: 'Midnight Livik Blast #2', map: 'Livik', mode: 'SOLO', time: 'Today, 09:30 PM', entryFee: 20, perKill: 15, chickenDinner: 100, maxSlots: 52, joinedCount: 19),
    MatchModel(title: 'Weekend Miramar Clash #3', map: 'Miramar', mode: 'SQUAD', time: 'Tomorrow, 04:00 PM', entryFee: 50, perKill: 40, chickenDinner: 300, maxSlots: 100, joinedCount: 64),
    MatchModel(title: 'Pro High Stakes #4', map: 'Vikendi', mode: 'SQUAD', time: 'Tomorrow, 09:00 PM', entryFee: 100, perKill: 80, chickenDinner: 600, maxSlots: 100, joinedCount: 28),
  ];

  final List<WalletTxn> _txns = [WalletTxn('Welcome Bonus', 'SK ESPORTS', 100, true, 'SUCCESS')];

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
            onPressed: () {
              if (ignC.text.trim().isEmpty || idC.text.trim().length < 8) return _msg('Sahi IGN aur ID dalein!');
              if (_wallet < m.entryFee) {
                Navigator.pop(ctx);
                setState(() => _tab = 1);
                return _msg('Balance kam hai! Wallet mein paise add karein.');
              }
              setState(() {
                _ign = ignC.text.trim();
                _bgmiId = idC.text.trim();
                _wallet -= m.entryFee;
                m.joinedCount++;
                m.isJoined = true;
                _txns.insert(0, WalletTxn('Joined: ${m.title}', 'IGN: $_ign', m.entryFee, false, 'PAID'));
              });
              Navigator.pop(ctx);
              _msg('Slot Confirmed! Room ID card par dikhega.');
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
          title: const Text('Add Money (Razorpay)', style: TextStyle(fontSize: 16)),
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
              onPressed: () {
                if (utrC.text.trim().length < 6) return _msg('Sahi UTR dalein!');
                setState(() {
                  _wallet += amt;
                  _txns.insert(0, WalletTxn('Razorpay Deposit', 'UTR: ${utrC.text.trim()}', amt, true, 'VERIFIED'));
                });
                Navigator.pop(ctx);
                _msg('₹$amt Added!');
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
            onPressed: () {
              final v = int.tryParse(amtC.text.trim()) ?? 0;
              if (!upiC.text.contains('@') || v < 50 || v > _wallet) return _msg('Valid UPI aur balance check karein!');
              setState(() {
                _wallet -= v;
                _txns.insert(0, WalletTxn('UPI Withdrawal', upiC.text.trim(), v, false, 'PENDING'));
              });
              Navigator.pop(ctx);
              _msg('₹$v Withdrawal Request Sent!');
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
      body: [_matchesView(), _walletView(), _profileView()][_tab],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF161B22),
        currentIndex: _tab,
        selectedItemColor: const Color(0xFFFF9800),
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile & Rules'),
        ],
      ),
    );
  }

  Widget _matchesView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _matches.length,
      itemBuilder: (_, i) {
        final m = _matches[i];
        final left = m.maxSlots - m.joinedCount;
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
              const SizedBox(height: 4),
              Text('Time: ${m.time}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('ENTRY', '₹${m.entryFee}', Colors.white),
                _stat('PER KILL', '₹${m.perKill}', const Color(0xFF00E676)),
                _stat('WINNER', '₹${m.chickenDinner}', const Color(0xFFFF9800)),
              ]),
              if (m.isJoined) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0x1A00E676), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00E676))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Room ID: ${m.roomId} | Pass: ${m.roomPass}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12)),
                    InkWell(
                      onTap: () { Clipboard.setData(ClipboardData(text: m.roomId)); _msg('Room ID Copied!'); },
                      child: const Icon(Icons.copy, size: 16, color: Color(0xFF00E676)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              LinearProgressIndicator(value: m.joinedCount / m.maxSlots, backgroundColor: Colors.grey[800], color: m.isJoined ? const Color(0xFF00E676) : const Color(0xFFFF9800)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${m.joinedCount}/${m.maxSlots} Joined ($left left)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: m.isJoined ? const Color(0xFF00E676) : const Color(0xFFFF9800)),
                  onPressed: m.isJoined || left <= 0 ? null : () => _joinDialog(m),
                  child: Text(m.isJoined ? 'JOINED ✓' : (left > 0 ? 'Join ₹${m.entryFee}' : 'FULL'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _stat(String k, String v, Color c) => Column(children: [
    Text(k, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
  ]);

  Widget _walletView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFE65100)]), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            const Text('Available Balance', style: TextStyle(color: Colors.white70)),
            Text('₹$_wallet', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), padding: const EdgeInsets.symmetric(vertical: 12)), icon: const Icon(Icons.add, color: Colors.black), label: const Text('Add Money', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), onPressed: _depositDialog)),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)), icon: const Icon(Icons.send), label: const Text('Withdraw'), onPressed: _withdrawDialog)),
        ]),
        const SizedBox(height: 16),
        const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: ListView.builder(
            itemCount: _txns.length,
            itemBuilder: (_, i) {
              final t = _txns[i];
              return Card(
                child: ListTile(
                  title: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text('${t.subtitle} • ${t.status}', style: const TextStyle(fontSize: 11)),
                  trailing: Text('${t.isCredit ? '+' : '-'}₹${t.amount}', style: TextStyle(fontWeight: FontWeight.bold, color: t.isCredit ? const Color(0xFF00E676) : Colors.redAccent)),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _profileView() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFFF9800), child: Icon(Icons.person, color: Colors.black)),
          title: Text(_ign, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('BGMI ID: $_bgmiId'),
        ),
      ),
      const SizedBox(height: 10),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'SK ESPORTS RULES:\n• Minimum BGMI Level 40+ ID required.\n• Room ID & Pass 15 min pehle milega.\n• No hacks, teaming or emulators.\n• Winnings 30 min mein credit hongi.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
      ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF229ED9), padding: const EdgeInsets.all(14)),
        icon: const Icon(Icons.send, color: Colors.white),
        label: const Text('Join Telegram (@SK_ESPORTSOFFICIAL)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () { Clipboard.setData(const ClipboardData(text: 'https://t.me/SK_ESPORTSOFFICIAL')); _msg('Telegram Link Copied!'); },
      ),
    ]);
  }
}
