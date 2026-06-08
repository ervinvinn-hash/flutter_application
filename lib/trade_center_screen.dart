import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_trade_screen.dart';

class TradeCenterScreen extends StatefulWidget {
  final String myTeamId; 

  const TradeCenterScreen({super.key, required this.myTeamId});

  @override
  State<TradeCenterScreen> createState() => _TradeCenterScreenState();
}

class _TradeCenterScreenState extends State<TradeCenterScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> incomingTrades = [];
  Map<int, String> playerNamesCache = {}; 
  Map<String, String> teamNamesCache = {}; 

  @override
  void initState() {
    super.initState();
    _fetchTrades();
  }

  Future<void> _fetchTrades() async {
    try {
      final client = Supabase.instance.client;

      final teamsData = await client.from('fantasy_teams').select('id, team_name');
      final playersData = await client.from('players').select('id, name');

      for (var t in teamsData) teamNamesCache[t['id']] = t['team_name'];
      for (var p in playersData) playerNamesCache[p['id']] = p['name'];

      final tradesData = await client
          .from('pending_trades')
          .select()
          .eq('receiver_team_id', widget.myTeamId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      setState(() {
        incomingTrades = List<Map<String, dynamic>>.from(tradesData);
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
    }
  }

  Future<void> _respondToTrade(Map<String, dynamic> trade, bool isAccepted) async {
    setState(() => isLoading = true);
    try {
      final client = Supabase.instance.client;

      if (isAccepted) {
        List<dynamic> senderPlayers = trade['sender_player_ids'];
        List<dynamic> receiverPlayers = trade['receiver_player_ids'];
        String senderTeamId = trade['sender_team_id'];

        for (var pId in senderPlayers) {
          await client.from('roster_players').update({
            'team_id': widget.myTeamId,
            'is_starter': false, 'is_bench': false, 'is_captain': false
          }).eq('player_id', pId);
        }

        for (var pId in receiverPlayers) {
          await client.from('roster_players').update({
            'team_id': senderTeamId,
            'is_starter': false, 'is_bench': false, 'is_captain': false
          }).eq('player_id', pId);
        }

        await client.from('pending_trades').update({'status': 'accepted'}).eq('id', trade['id']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scambio ACCETTATO!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      } else {
        await client.from('pending_trades').update({'status': 'rejected'}).eq('id', trade['id']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scambio RIFIUTATO.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }

      _fetchTrades();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  String _getPlayersNames(List<dynamic> ids) {
    return ids.map((id) => playerNamesCache[id] ?? 'Sconosciuto').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // <--- APP BAR TRASPARENTE
      appBar: AppBar(
        title: const Text('Centro Scambi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- LO STESSO SFONDO DELLO STADIO DELLA DASHBOARD ---
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/sfondo.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : incomingTrades.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Nessuna proposta in attesa.', style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: incomingTrades.length,
                      itemBuilder: (context, index) {
                        final trade = incomingTrades[index];
                        final senderName = teamNamesCache[trade['sender_team_id']] ?? 'Squadra ignota';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85), // Effetto vetro
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_fire_department, color: Colors.orange[800]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Proposta da: $senderName', 
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(thickness: 1.5),
                                const SizedBox(height: 8),
                                Text('Ti offrono:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 14)),
                                Text(_getPlayersNames(trade['sender_player_ids']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 16),
                                Text('In cambio di:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800], fontSize: 14)),
                                Text(_getPlayersNames(trade['receiver_player_ids']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _respondToTrade(trade, false),
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        label: const Text('Rifiuta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: const BorderSide(color: Colors.red, width: 2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _respondToTrade(trade, true),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Accetta', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          backgroundColor: Colors.green[700], 
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTradeScreen(myTeamId: widget.myTeamId)));
          if (result == true) _fetchTrades();
        },
        backgroundColor: Colors.amberAccent,
        foregroundColor: Colors.black87,
        elevation: 8,
        icon: const Icon(Icons.add_shopping_cart, size: 24),
        label: const Text('NUOVA PROPOSTA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}