import 'package:flutter/material.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFFFF9800),
        cardColor: const Color(0xFF161B22),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF9800),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MatchModel {
  String id;
  String title;
  String map;
  String mode;
  String time;
  int entryFee;
  int perKill;
  int chickenDinner;
  int maxSlots;
  List<PlayerEntry> joinedPlayers;

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
    required this.joinedPlayers,
  });
}

class PlayerEntry {
  String ign;
  String bgmiId;
  int kills;
  bool isWinner;
  int prizeWon;

  PlayerEntry({
    required this.ign,
    required this.bgmiId,
    this.kills = 0,
    this.isWinner = false,
    this.prizeWon = 0,
  });
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;
  int _userWalletBalance = 100;

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
      joinedPlayers: [
        PlayerEntry(ign: 'SK_SahidYT', bgmiId: '5123456789'),
        PlayerEntry(ign: 'MortalPro', bgmiId: '5987654321'),
      ],
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
      joinedPlayers: [
        PlayerEntry(ign: 'SniperKing', bgmiId: '5544332211'),
      ],
    ),
    MatchModel(
      id: 'M3',
      title: 'Pro Squad High Stakes #3',
      map: 'Miramar',
      mode: 'SQUAD',
      time: 'Tomorrow, 04:00 PM',
      entryFee: 100,
      perKill: 80,
      chickenDinner: 500,
      maxSlots: 100,
      joinedPlayers: [],
    ),
  ];

  void _joinMatchDialog(MatchModel match) {
    final ignController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Join ${match.title}', style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entry Fee: ₹${match.entryFee} (Level 40+ ID Required)',
              style: const TextStyle(color: Color(0xFFFF9800), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ignController,
              decoration: const InputDecoration(
                labelText: 'BGMI In-Game Name (IGN)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'BGMI Character ID (10 Digits)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () {
              if (ignController.text.isEmpty || idController.text.isEmpty) return;
              if (_userWalletBalance < match.entryFee) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wallet balance kam hai! Razorpay se add karein.')),
                );
                return;
              }
              setState(() {
                _userWalletBalance -= match.entryFee;
                match.joinedPlayers.add(
                  PlayerEntry(ign: ignController.text.trim(), bgmiId: idController.text.trim()),
                );
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Slot Confirmed! ₹${match.entryFee} deducted.')),
              );
            },
            child: Text('Pay ₹${match.entryFee} & Join', style: const TextStyle(color: Colors.black)),
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
      _buildAdminTab(),
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
          Container(
            margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF9800)),
            ),
            child: Center(
              child: Text(
                '₹$_userWalletBalance',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
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
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
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
        final slotsLeft = m.maxSlots - m.joinedPlayers.length;
        return Card(
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
                    Expanded(
                      child: Text(m.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF9800),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${m.map} • ${m.mode}', style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
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
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: m.joinedPlayers.length / m.maxSlots,
                  backgroundColor: Colors.grey[800],
                  color: const Color(0xFFFF9800),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${m.joinedPlayers.length}/${m.maxSlots} Joined ($slotsLeft left)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
                      onPressed: slotsLeft > 0 ? () => _joinMatchDialog(m) : null,
                      child: Text(slotsLeft > 0 ? 'Join ₹${m.entryFee}' : 'FULL',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFE65100)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text('Available Balance', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('₹$_userWalletBalance',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.qr_code_2, color: Colors.black),
                  label: const Text('Add Money (Razorpay)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() => _userWalletBalance += 50);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo: ₹50 Added via Razorpay QR!')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.send_to_mobile),
                  label: const Text('Withdraw UPI'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('RazorpayX UPI Payout Request Submitted!')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFFFF9800),
            tabs: [
              Tab(text: 'Create Match'),
              Tab(text: 'Add Kills & Prizes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCreateMatchForm(),
                _buildKillCalculator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateMatchForm() {
    final titleCtrl = TextEditingController(text: 'SK ESPORTS Evening Clash');
    final mapCtrl = TextEditingController(text: 'Erangel');
    final feeCtrl = TextEditingController(text: '50');
    final killCtrl = TextEditingController(text: '40');
    final cdCtrl = TextEditingController(text: '250');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Match Title')),
          TextField(controller: mapCtrl, decoration: const InputDecoration(labelText: 'Map (Erangel / Livik / Miramar)')),
          TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Entry Fee (₹20, ₹30, ₹50, ₹100)')),
          TextField(controller: killCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per Kill Reward (₹)')),
          TextField(controller: cdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chicken Dinner Prize (₹)')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800), padding: const EdgeInsets.all(14)),
              onPressed: () {
                setState(() {
                  _matches.insert(
                    0,
                    MatchModel(
                      id: 'M${_matches.length + 1}',
                      title: titleCtrl.text,
                      map: mapCtrl.text,
                      mode: 'SOLO',
                      time: 'Today, 10:00 PM',
                      entryFee: int.tryParse(feeCtrl.text) ?? 30,
                      perKill: int.tryParse(killCtrl.text) ?? 20,
                      chickenDinner: int.tryParse(cdCtrl.text) ?? 175,
                      maxSlots: 100,
                      joinedPlayers: [],
                    ),
                  );
                  _selectedIndex = 0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New Match Published Live!')),
                );
              },
              child: const Text('Publish New Match', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKillCalculator() {
    final activeMatch = _matches.first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Scoring: ${activeMatch.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('Rate: ₹${activeMatch.perKill}/Kill | Chicken Dinner: ₹${activeMatch.chickenDinner}',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        ...activeMatch.joinedPlayers.map((player) {
          final totalPrize = (player.kills * activeMatch.perKill) + (player.isWinner ? activeMatch.chickenDinner : 0);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${player.ign} (ID: ${player.bgmiId})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Total: ₹$totalPrize',
                          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Kills: '),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          if (player.kills > 0) player.kills--;
                        }),
                      ),
                      Text('${player.kills}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => player.kills++),
                      ),
                      const Spacer(),
                      const Text('Chicken Dinner: '),
                      Switch(
                        value: player.isWinner,
                        activeColor: const Color(0xFFFF9800),
                        onChanged: (val) => setState(() => player.isWinner = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), padding: const EdgeInsets.all(14)),
          onPressed: () {
            int sahidPrize = 0;
            for (var p in activeMatch.joinedPlayers) {
              p.prizeWon = (p.kills * activeMatch.perKill) + (p.isWinner ? activeMatch.chickenDinner : 0);
              if (p.ign == 'SK_SahidYT') sahidPrize = p.prizeWon;
            }
            setState(() {
              _userWalletBalance += sahidPrize;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Result Published! ₹$sahidPrize added to wallet.')),
            );
          },
          child: const Text('Publish Result & Credit Wallets',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
