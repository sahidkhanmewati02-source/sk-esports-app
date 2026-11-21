import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SKEsportsUserApp());
}

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
      home: const UserHomeScreen(),
    );
  }
}

class MatchModel {
  final String id;
  final String title;
  final String map;
  final String mode;
  final String time;
  final int entryFee;
  final int perKill;
  final int chickenDinner;
  final int maxSlots;
  int joinedCount;
  bool isJoined;
  String roomId;
  String roomPass;

  MatchModel({
    required this.id,
    required this.title,
    required this.map,
    required this.mode,
    required this.time,
    required this.entryFee,
    required this.perKill,
    required this.chickenDinner,
    required this.maxSlots,
    required this.joinedCount,
    this.isJoined = false,
    this.roomId = 'Wait (15 min before match)',
    this.roomPass = '****',
  });
}

class WalletTxn {
  final String title;
  final String subtitle;
  final int amount;
  final bool isCredit;
  final String status;

  WalletTxn({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.status,
  });
}

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  int _walletBalance = 100;
  String _playerIgn = 'SK_Player01';
  String _playerBgmiId = '5123456789';

  final List<MatchModel> _matches = [
    MatchModel(
      id: 'M1',
      title: 'SK ESPORTS Solo Rush #1',
      map: 'Erangel',
      mode: 'SOLO',
      time: 'Today, 08:00 PM',
      entryFee: 30,
      perKill: 20,
      chickenDinner: 175,
      maxSlots: 100,
      joinedCount: 42,
      roomId: '8849201',
      roomPass: 'SK2026',
    ),
    MatchModel(
      id: 'M2',
      title: 'Midnight Livik Blast #2',
      map: 'Livik',
      mode: 'SOLO',
      time: 'Today, 09:30 PM',
      entryFee: 20,
      perKill: 15,
      chickenDinner: 100,
      maxSlots: 52,
      joinedCount: 19,
    ),
    MatchModel(
      id: 'M3',
      title: 'Weekend Miramar Clash #3',
      map: 'Miramar',
      mode: 'SQUAD',
      time: 'Tomorrow, 04:00 PM',
      entryFee: 50,
      perKill: 40,
      chickenDinner: 300,
      maxSlots: 100,
      joinedCount: 64,
    ),
    MatchModel(
      id: 'M4',
      title: 'Pro High Stakes #4',
      map: 'Vikendi',
      mode: 'SQUAD',
      time: 'Tomorrow, 09:00 PM',
      entryFee: 100,
      perKill: 80,
      chickenDinner: 600,
      maxSlots: 100,
      joinedCount: 28,
    ),
  ];

  final List<WalletTxn> _txns = [
    WalletTxn(
      title: 'Welcome Bonus',
      subtitle: 'SK ESPORTS New Player',
      amount: 100,
      isCredit: true,
      status: 'SUCCESS',
    ),
  ];

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _joinMatchDialog(MatchModel match) {
    final ignCtrl = TextEditingController(text: _playerIgn);
    final idCtrl = TextEditingController(text: _playerBgmiId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Join ${match.title}', style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x22FF9800),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Rule: Minimum BGMI ID Level 40+ required. No emulators/hacks.',
                style: TextStyle(color: Color(0xFFFF9800), fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ignCtrl,
              decoration: const InputDecoration(
                labelText: 'BGMI In-Game Name (IGN)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: idCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'BGMI Character ID (10 Digits)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () {
              if (ignCtrl.text.trim().isEmpty || idCtrl.text.trim().length < 8) {
                _showSnack('Sahi BGMI Name aur ID dalein!');
                return;
              }
              if (_walletBalance < match.entryFee) {
                Navigator.pop(ctx);
                setState(() => _selectedIndex = 1);
                _showSnack('Balance kam hai! Pehle Wallet mein paise add karein.');
                return;
              }
              setState(() {
                _playerIgn = ignCtrl.text.trim();
                _playerBgmiId = idCtrl.text.trim();
                _walletBalance -= match.entryFee;
                match.joinedCount++;
                match.isJoined = true;
                _txns.insert(
                  0,
                  WalletTxn(
                    title: 'Joined: ${match.title}',
                    subtitle: 'IGN: $_playerIgn',
                    amount: match.entryFee,
                    isCredit: false,
                    status: 'PAID',
                  ),
                );
              });
              Navigator.pop(ctx);
              _showSnack('Slot Confirmed! Room ID ab card par dikhega.');
            },
            child: Text('Pay ₹${match.entryFee} & Join',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog() {
    int selectedAmt = 50;
    final utrCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Add Money via Razorpay', style: TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  children: [20, 30, 50, 100, 200].map((amt) {
                    final active = selectedAmt == amt;
                    return ChoiceChip(
                      label: Text('₹$amt'),
                      selected: active,
                      selectedColor: const Color(0xFFFF9800),
                      onSelected: (_) => setDialogState(() => selectedAmt = amt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2, size: 90, color: Color(0xFF00E676)),
                      const SizedBox(height: 6),
                      Text('Pay ₹$selectedAmt on SK ESPORTS Razorpay QR',
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: utrCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '12-Digit UPI Ref / UTR Number',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
              onPressed: () {
                if (utrCtrl.text.trim().length < 6) {
                  _showSnack('Sahi UTR / Reference Number dalein!');
                  return;
                }
                setState(() {
                  _walletBalance += selectedAmt;
                  _txns.insert(
                    0,
                    WalletTxn(
                      title: 'Razorpay Deposit',
                      subtitle: 'UTR: ${utrCtrl.text.trim()}',
                      amount: selectedAmt,
                      isCredit: true,
                      status: 'VERIFIED',
                    ),
                  );
                });
                Navigator.pop(ctx);
                _showSnack('₹$selectedAmt Wallet mein add ho gaye!');
              },
              child: const Text('Submit & Add',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog() {
    final upiCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Withdraw to UPI', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: upiCtrl,
              decoration: const InputDecoration(
                labelText: 'Your UPI ID (e.g. name@ybl)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (Min ₹50)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            onPressed: () {
              final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
              if (!upiCtrl.text.contains('@') || amt < 50) {
                _showSnack('Sahi UPI ID aur kam se kam ₹50 dalein!');
                return;
              }
              if (amt > _walletBalance) {
                _showSnack('Itna balance wallet mein nahi hai!');
                return;
              }
              setState(() {
                _walletBalance -= amt;
                _txns.insert(
                  0,
                  WalletTxn(
                    title: 'UPI Withdrawal',
                    subtitle: 'To: ${upiCtrl.text.trim()}',
                    amount: amt,
                    isCredit: false,
                    status: 'PENDING',
                  ),
                );
              });
              Navigator.pop(ctx);
              _showSnack('₹$amt Withdrawal Request bhej di gayi hai!');
            },
            child: const Text('Withdraw Now',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildMatchesTab(),
      _buildWalletTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text('SK ESPORTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 1),
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF9800)),
              ),
              child: Center(
                child: Text(
                  '₹$_walletBalance',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF161B22),
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFFF9800),
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile & Rules'),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final m = _matches[index];
        final slotsLeft = m.maxSlots - m.joinedCount;
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: m.isJoined ? const Color(0xFF00E676) : Colors.transparent),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(m.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF9800),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${m.map} • ${m.mode}',
                          style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Time: ${m.time}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoBox('ENTRY FEE', '₹${m.entryFee}', Colors.white),
                    _infoBox('PER KILL', '₹${m.perKill}', const Color(0xFF00E676)),
                    _infoBox('CHICKEN DINNER', '₹${m.chickenDinner}', const Color(0xFFFF9800)),
                  ],
                ),
                if (m.isJoined) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x1A00E676),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E676)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Room ID: ${m.roomId}  |  Pass: ${m.roomPass}',
                            style: const TextStyle(
                                color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: m.roomId));
                            _showSnack('Room ID Copied!');
                          },
                          child: const Icon(Icons.copy, size: 18, color: Color(0xFF00E676)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: m.joinedCount / m.maxSlots,
                  backgroundColor: Colors.grey[800],
                  color: m.isJoined ? const Color(0xFF00E676) : const Color(0xFFFF9800),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${m.joinedCount}/${m.maxSlots} Joined ($slotsLeft left)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: m.isJoined ? const Color(0xFF00E676) : const Color(0xFFFF9800),
                      ),
                      onPressed: m.isJoined ? null : (slotsLeft > 0 ? () => _joinMatchDialog(m) : null),
                      child: Text(
                        m.isJoined ? 'JOINED ✓' : (slotsLeft > 0 ? 'Join ₹${m.entryFee}' : 'FULL'),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildWalletTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFE65100)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
     
