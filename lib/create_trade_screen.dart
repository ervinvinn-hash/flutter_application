import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateTradeScreen extends StatefulWidget {
  final String myTeamId;

  const CreateTradeScreen({super.key, required this.myTeamId});

  @override
  State<CreateTradeScreen> createState() => _CreateTradeScreenState();
}

class _CreateTradeScreenState extends State<CreateTradeScreen> {
  bool isLoading = true;
  bool isSending = false;

  List<Map<String, dynamic>> otherTeams = [];
  Map<int, Map<String, dynamic>> playersCache = {};

  String? targetTeamId;
  List<Map<String, dynamic>> myRoster = [];
  List<Map<String, dynamic>> targetRoster = [];

  Set<int> selectedMyPlayers = {}; 
  Set<int> selectedTargetPlayers = {}; 

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final client = Supabase.instance.client;
      final teamsData = await client.from('fantasy_teams').select('id, team_name').neq('id', widget.myTeamId).order('team_name');
      final playersData = await client.from('players').select('id, name, role');

      Map<int, Map<String, dynamic>> pMap = {};
      for (var p in playersData) {
        pMap[p['id']] = p;
      }

      setState(() {
        otherTeams = List<Map<String, dynamic>>.from(teamsData);
        playersCache = pMap;
        isLoading = false;
      });

      _fetchRoster(widget.myTeamId, isMyRoster: true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _fetchRoster(String teamId, {required bool isMyRoster}) async {
    try {
      final rosterData = await Supabase.instance.client.from('roster_players').select().eq('team_id', teamId);
      
      List<Map<String, dynamic>> enrichedRoster = [];
      for (var r in rosterData) {
        var pInfo = playersCache[r['player_id']];
        if (pInfo != null) {
          enrichedRoster.add({
            'player_id': r['player_id'],
            'name': pInfo['name'],
            'role': pInfo['role'],
            'purchase_price': r['purchase_price'],
          });
        }
      }

      final roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5};
      enrichedRoster.sort((a, b) {
        int r = (roleOrder[a['role']] ?? 9).compareTo(roleOrder[b['role']] ?? 9);
        if (r != 0) return r;
        return a['name'].compareTo(b['name']);
      });

      setState(() {
        if (isMyRoster) {
          myRoster = enrichedRoster;
          selectedMyPlayers.clear();
        } else {
          targetRoster = enrichedRoster;
          selectedTargetPlayers.clear();
        }
      });
    } catch (e) {
      debugPrint('Errore roster: $e');
    }
  }

  Future<void> _sendTradeProposal() async {
    if (targetTeamId == null) return;
    if (selectedMyPlayers.isEmpty || selectedTargetPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devi selezionare almeno un giocatore da offrire e uno da richiedere!')));
      return;
    }

    setState(() => isSending = true);

    try {
      await Supabase.instance.client.from('pending_trades').insert({
        'sender_team_id': widget.myTeamId,
        'receiver_team_id': targetTeamId,
        'sender_player_ids': selectedMyPlayers.toList(),
        'receiver_player_ids': selectedTargetPlayers.toList(),
        'status': 'pending'
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proposta inviata con successo! ✈️'), backgroundColor: Colors.green));
      Navigator.pop(context, true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore invio: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isSending = false);
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'P': return Colors.orange;
      case 'D': return Colors.green[700]!;
      case 'C': return Colors.blue[700]!;
      case 'A': return Colors.red[700]!;
      case 'CT': return Colors.black87;
      default: return Colors.grey;
    }
  }

  Widget _buildRosterList(List<Map<String, dynamic>> roster, Set<int> selectedSet, Color activeColor) {
    if (roster.isEmpty) {
      return const Center(child: Text('Rosa vuota', style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)));
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: roster.length,
      itemBuilder: (ctx, i) {
        final p = roster[i];
        final isSelected = selectedSet.contains(p['player_id']);
        
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: CheckboxListTile(
            // AUMENTATO IL PADDING per staccare il testo dal bordo sinistro
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            dense: true,
            value: isSelected,
            activeColor: activeColor,
            checkColor: Colors.white,
            onChanged: (bool? val) {
              setState(() {
                if (val == true) { selectedSet.add(p['player_id']); } 
                else { selectedSet.remove(p['player_id']); }
              });
            },
            title: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: _getRoleColor(p['role']),
                  child: Text(p['role'], style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                // Aumentato anche qui lo spazio tra il pallino del ruolo e il nome
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p['name'], 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Text('${p['purchase_price']} cr', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text('Nuova Proposta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Seleziona chi vuoi cedere e chi vuoi in cambio',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          // --- PANNELLO SINISTRO: LA TUA SQUADRA ---
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(left: 12, right: 6, bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                              ),
                              child: Column(
                                children: [
                                  // STRISCIA BLU A ALTEZZA FISSA
                                  Container(
                                    width: double.infinity,
                                    height: 48, // ALTEZZA FISSA IMPOSTATA QUI
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[800],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    child: const Text('TU OFFRI', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                                  ),
                                  Expanded(child: _buildRosterList(myRoster, selectedMyPlayers, Colors.blue[800]!)),
                                ],
                              ),
                            ),
                          ),
                          
                          // --- PANNELLO DESTRO: L'AVVERSARIO ---
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(left: 6, right: 12, bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                              ),
                              child: Column(
                                children: [
                                  // STRISCIA ROSSA A ALTEZZA FISSA (IDENTICA A QUELLA BLU)
                                  Container(
                                    width: double.infinity,
                                    height: 48, // ALTEZZA FISSA IMPOSTATA QUI
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red[800],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        dropdownColor: Colors.red[50],
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                        hint: const Text('Scegli Avversario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                        value: targetTeamId,
                                        items: otherTeams.map((t) {
                                          return DropdownMenuItem<String>(
                                            value: t['id'],
                                            child: Text(t['team_name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() => targetTeamId = val);
                                          _fetchRoster(val!, isMyRoster: false);
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: targetTeamId == null
                                        ? const Center(child: Text('Seleziona una squadra', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)))
                                        : _buildRosterList(targetRoster, selectedTargetPlayers, Colors.red[800]!),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // --- BOTTONE INVIA PROPOSTA (STILE VIP) ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ElevatedButton(
                        onPressed: isSending || selectedMyPlayers.isEmpty || selectedTargetPlayers.isEmpty ? null : _sendTradeProposal,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(55),
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black87,
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isSending 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 3)) 
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send, size: 20),
                                  SizedBox(width: 10),
                                  Text('INVIA PROPOSTA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}