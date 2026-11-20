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
            style:
            
