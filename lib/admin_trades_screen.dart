import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTradesScreen extends StatefulWidget {
  const AdminTradesScreen({super.key});

  @override
  State<AdminTradesScreen> createState() => _AdminTradesScreenState();
}

class _AdminTradesScreenState extends State<AdminTradesScreen> {
  bool isLoading = true;
  bool isTrading = false;

  List<Map<String, dynamic>> allTeams = [];
  Map<int, Map<String, dynamic>> playersCache = {};

  String? team1Id;
  String? team2Id;

  List<Map<String, dynamic>> roster1 = [];
  List<Map<String, dynamic>> roster2 = [];

  Set<int> selectedPlayersTeam1 = {}; // Giocatori che il Team 1 cede
  Set<int> selectedPlayersTeam2 = {}; // Giocatori che il Team 2 cede

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final teamsData = await Supabase.instance.client.from('fantasy_teams').select('id, team_name').order('team_name');
      final playersData = await Supabase.instance.client.from('players').select('id, name, role, national_team');

      Map<int, Map<String, dynamic>> pMap = {};
      for (var p in playersData) {
        pMap[p['id']] = p;
      }

      setState(() {
        allTeams = List<Map<String, dynamic>>.from(teamsData);
        playersCache = pMap;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _fetchRoster(String teamId, int teamNumber) async {
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

      // Ordina per ruolo e nome
      final roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5};
      enrichedRoster.sort((a, b) {
        int r = (roleOrder[a['role']] ?? 9).compareTo(roleOrder[b['role']] ?? 9);
        if (r != 0) return r;
        return a['name'].compareTo(b['name']);
      });

      setState(() {
        if (teamNumber == 1) {
          roster1 = enrichedRoster;
          selectedPlayersTeam1.clear();
        } else {
          roster2 = enrichedRoster;
          selectedPlayersTeam2.clear();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _executeTrade() async {
    if (team1Id == null || team2Id == null) return;
    if (selectedPlayersTeam1.isEmpty && selectedPlayersTeam2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona almeno un giocatore da scambiare!')));
      return;
    }

    setState(() => isTrading = true);

    try {
      final client = Supabase.instance.client;

      // 1. Sposta i giocatori dal Team 1 al Team 2
      for (int pId in selectedPlayersTeam1) {
        await client.from('roster_players').update({
          'team_id': team2Id,
          'is_starter': false, // Resetta la titolarità!
          'is_bench': false,
          'is_captain': false
        }).eq('team_id', team1Id!).eq('player_id', pId);
      }

      // 2. Sposta i giocatori dal Team 2 al Team 1
      for (int pId in selectedPlayersTeam2) {
        await client.from('roster_players').update({
          'team_id': team1Id,
          'is_starter': false, // Resetta la titolarità!
          'is_bench': false,
          'is_captain': false
        }).eq('team_id', team2Id!).eq('player_id', pId);
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scambio completato con successo! 🎉'), backgroundColor: Colors.green));
      
      // Ricarica le rose aggiornate
      await _fetchRoster(team1Id!, 1);
      await _fetchRoster(team2Id!, 2);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore scambio: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isTrading = false);
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

  Widget _buildTeamColumn(int teamNum, String? currentTeamId, List<Map<String, dynamic>> roster, Set<int> selectedSet) {
    return Expanded(
      child: Container(
        color: teamNum == 1 ? Colors.blue[50] : Colors.red[50],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Seleziona Squadra', style: TextStyle(fontWeight: FontWeight.bold)),
                value: currentTeamId,
                items: allTeams.map((t) {
                  return DropdownMenuItem<String>(
                    value: t['id'],
                    // Disabilita la squadra se è già selezionata dall'altra parte
                    enabled: (teamNum == 1 ? t['id'] != team2Id : t['id'] != team1Id),
                    child: Text(t['team_name'], style: TextStyle(color: (teamNum == 1 ? t['id'] == team2Id : t['id'] == team1Id) ? Colors.grey : Colors.black)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    if (teamNum == 1) { team1Id = val; } else { team2Id = val; }
                  });
                  _fetchRoster(val!, teamNum);
                },
              ),
            ),
            const Divider(thickness: 2),
            Expanded(
              child: currentTeamId == null
                  ? const Center(child: Text('Seleziona una squadra', style: TextStyle(color: Colors.grey)))
                  : roster.isEmpty
                      ? const Center(child: Text('Rosa vuota'))
                      : ListView.builder(
                          itemCount: roster.length,
                          itemBuilder: (ctx, i) {
                            final p = roster[i];
                            final isSelected = selectedSet.contains(p['player_id']);
                            
                            return CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              dense: true,
                              value: isSelected,
                              activeColor: teamNum == 1 ? Colors.blue[800] : Colors.red[800],
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    selectedSet.add(p['player_id']);
                                  } else {
                                    selectedSet.remove(p['player_id']);
                                  }
                                });
                              },
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: _getRoleColor(p['role']),
                                    child: Text(p['role'], style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(p['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              subtitle: Text('${p['purchase_price']} cr', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scambi di Mercato'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red[800],
                  child: const Text(
                    'Seleziona i giocatori da cedere da entrambe le parti. Le formazioni schierate in campo verranno rimosse ai giocatori scambiati.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildTeamColumn(1, team1Id, roster1, selectedPlayersTeam1),
                      const VerticalDivider(width: 2, thickness: 2, color: Colors.grey),
                      _buildTeamColumn(2, team2Id, roster2, selectedPlayersTeam2),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: isTrading || (selectedPlayersTeam1.isEmpty && selectedPlayersTeam2.isEmpty) ? null : _executeTrade,
                      icon: isTrading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.swap_horiz),
                      label: const Text('ESEGUI SCAMBIO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}