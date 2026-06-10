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
  List<Map<String, dynamic>> tradesHistory = [];
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

      // SCARICA LO STORICO COMPLETO (Sia inviate che ricevute, di qualsiasi status)
      final tradesData = await client
          .from('pending_trades')
          .select()
          .or('receiver_team_id.eq.${widget.myTeamId},sender_team_id.eq.${widget.myTeamId}')
          .order('created_at', ascending: false);

      setState(() {
        tradesHistory = List<Map<String, dynamic>>.from(tradesData);
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
      setState(() => isLoading = false);
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
        String receiverTeamId = trade['receiver_team_id'];

        // Esegui lo scambio delle squadre
        for (var pId in senderPlayers) {
          await client.from('roster_players').update({
            'team_id': receiverTeamId,
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

  // --- FUNZIONE PER ELIMINARE DALLO STORICO (Tasto X) ---
  Future<void> _deleteTradeHistory(int tradeId) async {
    try {
      await Supabase.instance.client.from('pending_trades').delete().eq('id', tradeId);
      _fetchTrades();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore rimozione: $e')));
    }
  }

  String _getPlayersNames(List<dynamic> ids) {
    return ids.map((id) => playerNamesCache[id] ?? 'Sconosciuto').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text('Centro Scambi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/sfondo.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : tradesHistory.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Nessuna proposta nello storico.', style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tradesHistory.length,
                      itemBuilder: (context, index) {
                        final trade = tradesHistory[index];
                        final isIncoming = trade['receiver_team_id'] == widget.myTeamId;
                        final otherTeamName = teamNamesCache[isIncoming ? trade['sender_team_id'] : trade['receiver_team_id']] ?? 'Squadra ignota';
                        
                        final status = trade['status']; // 'pending', 'accepted', 'rejected'
                        
                        Color statusColor;
                        String statusText;
                        IconData statusIcon;

                        if (status == 'accepted') {
                          statusColor = Colors.green[700]!; statusText = 'ACCETTATA'; statusIcon = Icons.check_circle;
                        } else if (status == 'rejected') {
                          statusColor = Colors.red[700]!; statusText = 'RIFIUTATA'; statusIcon = Icons.cancel;
                        } else {
                          statusColor = Colors.grey[600]!; statusText = 'IN ATTESA'; statusIcon = Icons.access_time_filled;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.90), 
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- INTESTAZIONE CARTA CON LA X ---
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isIncoming ? Colors.blue[800]!.withValues(alpha: 0.1) : Colors.orange[800]!.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(isIncoming ? Icons.download : Icons.upload, color: isIncoming ? Colors.blue[800] : Colors.orange[800], size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isIncoming ? 'Proposta da: $otherTeamName' : 'Inviata a: $otherTeamName', 
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isIncoming ? Colors.blue[900] : Colors.orange[900]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // LA "X" IN ALTO A DESTRA
                                    GestureDetector(
                                      onTap: () => _deleteTradeHistory(trade['id']),
                                      child: const Icon(Icons.close, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // --- CONTENUTO GIOCATORI ---
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(isIncoming ? 'Ti offrono:' : 'Hai offerto:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 13)),
                                          Text(_getPlayersNames(trade['sender_player_ids']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                          const SizedBox(height: 12),
                                          Text(isIncoming ? 'In cambio di:' : 'Hai richiesto:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800], fontSize: 13)),
                                          Text(_getPlayersNames(trade['receiver_player_ids']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                        ],
                                      ),
                                    ),
                                    
                                    // --- BADGE LATERALE DELLO STATUS ---
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)),
                                      child: Column(
                                        children: [
                                          Icon(statusIcon, color: statusColor, size: 28),
                                          const SizedBox(height: 4),
                                          Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),

                              // --- BOTTONI ACCETTA/RIFIUTA (Mostrati solo se la proposta è in arrivo e ancora in attesa) ---
                              if (isIncoming && status == 'pending')
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _respondToTrade(trade, false),
                                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                          label: const Text('Rifiuta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            side: const BorderSide(color: Colors.red, width: 2),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _respondToTrade(trade, true),
                                          icon: const Icon(Icons.check, size: 20),
                                          label: const Text('Accetta', style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            backgroundColor: Colors.green[700], 
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTradeScreen(myTeamId: widget.myTeamId)));
          if (result == true) _fetchTrades(); // Se torno indietro dopo aver inviato, ricarico lo storico!
        },
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.black87,
        elevation: 8,
        icon: const Icon(Icons.add_shopping_cart, size: 24),
        label: const Text('NUOVA PROPOSTA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}