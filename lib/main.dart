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
              const SizedBox(height: 4),
              Text('Time: ${m.time}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('ENTRY', '₹${m.fee}', Colors.white),
                _stat('PER KILL', '₹${m.kill}', const Color(0xFF00E676)),
                _stat('WINNER', '₹${m.win}', const Color(0xFFFF9800)),
              ]),
              if (m.isJoined || isAdmin) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0x1A00E676), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00E676))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Room: ${m.rId} | Pass: ${m.rPass}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12)),
                    Row(children: [
                      if (isAdmin) IconButton(icon: const Icon(Icons.edit, size: 16, color: Color(0xFFFF9800)), onPressed: () => _editRoom(m)),
                      InkWell(onTap: () { Clipboard.setData(ClipboardData(text: m.rId)); _msg('Copied!'); }, child: const Icon(Icons.copy, size: 16, color: Color(0xFF00E676))),
                    ]),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              LinearProgressIndicator(value: m.joined / m.slots, backgroundColor: Colors.grey[800], color: m.isJoined ? const Color(0xFF00E676) : const Color(0xFFFF9800)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${m.joined}/${m.slots} Joined ($left left)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: m.isJoined ? const Color(0xFF00E676) : const Color(0xFFFF9800)),
                  onPressed: m.isJoined || left <= 0 ? null : () => _join(m),
                  child: Text(m.isJoined ? 'JOINED ✓' : (left > 0 ? 'Join ₹${m.fee}' : 'FULL'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  Widget _walletTab() {
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
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), padding: const EdgeInsets.symmetric(vertical: 12)), icon: const Icon(Icons.add, color: Colors.black), label: const Text('Add Money', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), onPressed: _deposit)),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)), icon: const Icon(Icons.send), label: const Text('Withdraw'), onPressed: _withdraw)),
        ]),
        const SizedBox(height: 14),
        const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: _txns.isEmpty
              ? const Center(child: Text('Koi transaction nahi hai.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _txns.length,
                  itemBuilder: (_, i) {
                    final t = _txns[i];
                    return Card(
                      child: ListTile(
                        title: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('${t.sub} • ${t.status}', style: const TextStyle(fontSize: 11)),
                        trailing: Text('${t.credit ? '+' : '-'}₹${t.amt}', style: TextStyle(fontWeight: FontWeight.bold, color: t.credit ? const Color(0xFF00E676) : Colors.redAccent)),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _profileTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFFF9800), child: Icon(Icons.person, color: Colors.black)),
          title: Text(_ign, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('BGMI ID: $_bgmiId\n${widget.email}'),
          isThreeLine: true,
        ),
      ),
      const SizedBox(height: 10),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('SK ESPORTS RULES:\n• Minimum BGMI Level 40+ ID required.\n• Room ID & Pass 15 min pehle milega.\n• No hacks, teaming or emulators.\n• Winnings 30 min mein credit hongi.', style: TextStyle(fontSize: 13, height: 1.5)),
        ),
      ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF229ED9), padding: const EdgeInsets.all(14)),
        icon: const Icon(Icons.send, color: Colors.white),
        label: const Text('Join Telegram (@SK_ESPORTSOFFICIAL)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Clipboard.setData(const ClipboardData(text: 'https://t.me/SK_ESPORTSOFFICIAL'));
          _msg('Telegram Link Copied!');
        },
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
      ),
    ]);
  }
}
