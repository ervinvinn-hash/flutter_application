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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona almeno un giocatore da offrire e uno da richiedere!')));
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

  // --- POPUP PER LA SELEZIONE GIOCATORI ---
  Future<void> _showSelectionDialog(bool isMyTeam) async {
    if (!isMyTeam && targetTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona prima la squadra avversaria!')));
      return;
    }

    List<Map<String, dynamic>> roster = isMyTeam ? myRoster : targetRoster;
    Set<int> currentSelection = Set.from(isMyTeam ? selectedMyPlayers : selectedTargetPlayers);
    Color themeColor = isMyTeam ? Colors.blue[800]! : Colors.red[800]!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 5, margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
                  ),
                  Text(isMyTeam ? 'Seleziona chi offri' : 'Seleziona chi richiedi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor)),
                  const Divider(thickness: 1.5),
                  Expanded(
                    child: ListView.builder(
                      itemCount: roster.length,
                      itemBuilder: (context, index) {
                        final p = roster[index];
                        final isSelected = currentSelection.contains(p['player_id']);
                        return CheckboxListTile(
                          activeColor: themeColor,
                          value: isSelected,
                          onChanged: (bool? val) {
                            setModalState(() {
                              if (val == true) currentSelection.add(p['player_id']);
                              else currentSelection.remove(p['player_id']);
                            });
                          },
                          title: Row(
                            children: [
                              CircleAvatar(
                                radius: 12, backgroundColor: _getRoleColor(p['role']),
                                child: Text(p['role'], style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            ],
                          ),
                          subtitle: Text('${p['purchase_price']} cr', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('CONFERMA SELEZIONE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );

    setState(() {
      if (isMyTeam) {
        selectedMyPlayers = currentSelection;
      } else {
        selectedTargetPlayers = currentSelection;
      }
    });
  }

  // --- CHIP IN STILE VETRO PER I GIOCATORI SELEZIONATI ---
  Widget _buildGlassChip(Map<String, dynamic> player, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10, backgroundColor: _getRoleColor(player['role']),
            child: Text(player['role'], style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Text(player['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.cancel, size: 18, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> mySelectedList = myRoster.where((p) => selectedMyPlayers.contains(p['player_id'])).toList();
    List<Map<String, dynamic>> targetSelectedList = targetRoster.where((p) => selectedTargetPlayers.contains(p['player_id'])).toList();

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
                    // --- PANNELLO SUPERIORE: LA TUA SQUADRA ---
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[300]!.withValues(alpha: 0.5), width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue[800]!.withValues(alpha: 0.9),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              ),
                              child: const Text('LA TUA SQUADRA (OFFRI)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: mySelectedList.isEmpty 
                                  ? const Center(child: Text('Nessun giocatore selezionato.', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)))
                                  : SingleChildScrollView(
                                      child: Wrap(
                                        children: mySelectedList.map((p) => _buildGlassChip(p, () {
                                          setState(() => selectedMyPlayers.remove(p['player_id']));
                                        })).toList(),
                                      ),
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: ElevatedButton.icon(
                                onPressed: () => _showSelectionDialog(true),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Scegli Giocatori', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                                  foregroundColor: Colors.blue[900],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Icon(Icons.swap_vert, color: Colors.white70, size: 36),

                    // --- PANNELLO INFERIORE: SQUADRA AVVERSARIA ---
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red[300]!.withValues(alpha: 0.5), width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.red[800]!.withValues(alpha: 0.9),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  dropdownColor: Colors.red[900],
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  hint: const Text('Seleziona Avversario (RICHIEDI)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  value: targetTeamId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                  items: otherTeams.map((t) {
                                    return DropdownMenuItem<String>(value: t['id'], child: Text(t['team_name']));
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      targetTeamId = val;
                                      selectedTargetPlayers.clear();
                                    });
                                    _fetchRoster(val!, isMyRoster: false);
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: targetTeamId == null 
                                  ? const Center(child: Text('Seleziona una squadra avversaria.', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)))
                                  : targetSelectedList.isEmpty
                                    ? const Center(child: Text('Nessun giocatore selezionato.', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)))
                                    : SingleChildScrollView(
                                        child: Wrap(
                                          children: targetSelectedList.map((p) => _buildGlassChip(p, () {
                                            setState(() => selectedTargetPlayers.remove(p['player_id']));
                                          })).toList(),
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: ElevatedButton.icon(
                                onPressed: targetTeamId == null ? null : () => _showSelectionDialog(false),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Scegli Giocatori', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                                  foregroundColor: Colors.red[900],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // --- BOTTONE INVIA PROPOSTA ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ElevatedButton(
                        onPressed: isSending || selectedMyPlayers.isEmpty || selectedTargetPlayers.isEmpty ? null : _sendTradeProposal,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(55),
                          backgroundColor: Colors.orange[800],
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