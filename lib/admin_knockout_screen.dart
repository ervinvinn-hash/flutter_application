import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- CLASSI DATI ---
class MatchupData {
  final String team1Id;
  final String team2Id;
  final String phaseName;
  final Map<String, dynamic> andata;
  final Map<String, dynamic>? ritorno;

  MatchupData(this.team1Id, this.team2Id, this.phaseName, this.andata, this.ritorno);

  num? get andataT1 => andata['home_team_id'] == team1Id ? andata['home_goals'] : andata['away_goals'];
  num? get andataT2 => andata['away_team_id'] == team2Id ? andata['away_goals'] : andata['home_goals'];
  
  num? get ritornoT1 => ritorno != null ? (ritorno!['home_team_id'] == team1Id ? ritorno!['home_goals'] : ritorno!['away_goals']) : null;
  num? get ritornoT2 => ritorno != null ? (ritorno!['away_team_id'] == team2Id ? ritorno!['away_goals'] : ritorno!['home_goals']) : null;

  bool get hasAnyScore => andataT1 != null || andataT2 != null || ritornoT1 != null || ritornoT2 != null;
  num get totalT1 => (andataT1 ?? 0) + (ritornoT1 ?? 0);
  num get totalT2 => (andataT2 ?? 0) + (ritornoT2 ?? 0);
}

// --- FUNZIONI GLOBALI ---
String formatScore(num? score) {
  if (score == null) return '-';
  if (score == score.toInt()) return score.toInt().toString();
  return score.toString();
}

List<MatchupData> groupMatchups(List<Map<String, dynamic>> rawMatches) {
  Map<String, List<Map<String, dynamic>>> grouped = {};
  for (var m in rawMatches) {
    List<String> ids = [m['home_team_id'].toString(), m['away_team_id'].toString()];
    ids.sort();
    int groupKey = m['match_day'] <= 5 ? 1 : (m['match_day'] <= 7 ? 2 : 3);
    String key = '${ids[0]}_${ids[1]}_$groupKey';
    grouped.putIfAbsent(key, () => []).add(m);
  }
  
  List<MatchupData> result = [];
  for (var list in grouped.values) {
    list.sort((a, b) => (a['match_day'] as int).compareTo(b['match_day'] as int));
    var andata = list[0];
    var ritorno = list.length > 1 ? list[1] : null;
    
    String phase = andata['phase'].toString().replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
    result.add(MatchupData(
      andata['home_team_id'].toString(),
      andata['away_team_id'].toString(),
      phase,
      andata,
      ritorno,
    ));
  }
  return result;
}

// --- SCHERMATA ADMIN ---
class AdminKnockoutScreen extends StatefulWidget {
  const AdminKnockoutScreen({super.key});

  @override
  State<AdminKnockoutScreen> createState() => _AdminKnockoutScreenState();
}

class _AdminKnockoutScreenState extends State<AdminKnockoutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  List<MatchupData> matchups = [];
  List<Map<String, dynamic>> teams = [];
  Map<String, String> teamNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final client = Supabase.instance.client;
      
      final teamsData = await client.from('fantasy_teams').select('id, team_name');
      final List<Map<String, dynamic>> loadedTeams = List<Map<String, dynamic>>.from(teamsData);
      
      Map<String, String> tNames = {};
      for (var t in loadedTeams) {
        tNames[t['id']] = t['team_name'];
      }

      final matchesData = await client.from('matches').select().gte('match_day', 4).order('match_day', ascending: true);
          
      setState(() {
        teams = loadedTeams;
        teamNames = tNames;
        matchups = groupMatchups(List<Map<String, dynamic>>.from(matchesData));
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      setState(() => isLoading = false);
    }
  }

  void _showMatchupEditor({MatchupData? matchup}) {
    String phase = matchup?.phaseName ?? (_tabController.index == 0 ? 'Playoff' : _tabController.index == 1 ? 'Semifinale' : 'Finale');
    int baseMatchDay = matchup?.andata['match_day'] ?? (_tabController.index == 0 ? 4 : _tabController.index == 1 ? 6 : 8);
    String? t1 = matchup?.team1Id;
    String? t2 = matchup?.team2Id;
    
    // Se è una nuova partita, decidi di default in base alla Tab (le Finali sono gara secca di default)
    bool isTwoLegs = matchup != null ? (matchup.ritorno != null) : (_tabController.index != 2);

    TextEditingController phaseCtrl = TextEditingController(text: phase);
    TextEditingController aT1 = TextEditingController(text: formatScore(matchup?.andataT1).replaceAll('-', ''));
    TextEditingController aT2 = TextEditingController(text: formatScore(matchup?.andataT2).replaceAll('-', ''));
    TextEditingController rT1 = TextEditingController(text: formatScore(matchup?.ritornoT1).replaceAll('-', ''));
    TextEditingController rT2 = TextEditingController(text: formatScore(matchup?.ritornoT2).replaceAll('-', ''));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      matchup == null ? 'Crea Nuova Sfida' : 'Modifica Risultati',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[900]),
                    ),
                    const Divider(height: 20),
                    
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: phaseCtrl, decoration: const InputDecoration(labelText: 'Fase', border: OutlineInputBorder(), isDense: true))),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<int>(
                            value: baseMatchDay,
                            decoration: const InputDecoration(labelText: 'Giornata Base', border: OutlineInputBorder(), isDense: true),
                            items: List.generate(6, (i) => i + 4).map((val) => DropdownMenuItem(value: val, child: Text('G $val'))).toList(),
                            onChanged: (v) => setModalState(() => baseMatchDay = v!),
                          ),
                        ),
                      ],
                    ),
                    
                    if (matchup == null) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Doppia Sfida (Andata e Ritorno)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        value: isTwoLegs,
                        activeColor: Colors.red[800],
                        onChanged: (val) => setModalState(() => isTwoLegs = val),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // SELEZIONE SQUADRE (Mostra sempre, ma se è un edit, le precompila)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: t1, hint: const Text('Squadra 1'), isExpanded: true,
                            items: teams.map((t) => DropdownMenuItem<String>(value: t['id'], child: Text(t['team_name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                            onChanged: (v) => setModalState(() => t1 = v),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: t2, hint: const Text('Squadra 2'), isExpanded: true,
                            items: teams.map((t) => DropdownMenuItem<String>(value: t['id'], child: Text(t['team_name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                            onChanged: (v) => setModalState(() => t2 = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // RISULTATI ANDATA
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Text('RISULTATO ANDATA (G $baseMatchDay)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 80, child: TextField(controller: aT1, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: const InputDecoration(filled: true, fillColor: Colors.white))),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                              SizedBox(width: 80, child: TextField(controller: aT2, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: const InputDecoration(filled: true, fillColor: Colors.white))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // RISULTATI RITORNO
                    if (isTwoLegs)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Text('RISULTATO RITORNO (G ${baseMatchDay + 1})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 80, child: TextField(controller: rT1, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: const InputDecoration(filled: true, fillColor: Colors.white))),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                                SizedBox(width: 80, child: TextField(controller: rT2, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: const InputDecoration(filled: true, fillColor: Colors.white))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        if (matchup != null)
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteMatchup(matchup);
                              },
                              child: const Icon(Icons.delete),
                            ),
                          ),
                        if (matchup != null) const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: () {
                              if (t1 == null || t2 == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona entrambe le squadre!')));
                                return;
                              }
                              Navigator.pop(ctx);
                              _saveMatchup(
                                matchup: matchup,
                                phase: phaseCtrl.text,
                                matchDay: baseMatchDay,
                                isTwoLegs: isTwoLegs,
                                t1Id: t1!, t2Id: t2!,
                                aT1: num.tryParse(aT1.text), aT2: num.tryParse(aT2.text),
                                rT1: num.tryParse(rT1.text), rT2: num.tryParse(rT2.text),
                              );
                            },
                            child: Text(matchup == null ? 'CREA SFIDA' : 'SALVA RISULTATI', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _saveMatchup({MatchupData? matchup, required String phase, required int matchDay, required bool isTwoLegs, required String t1Id, required String t2Id, num? aT1, num? aT2, num? rT1, num? rT2}) async {
    try {
      final client = Supabase.instance.client;

      if (matchup == null) {
        // CREA NUOVO
        await client.from('matches').insert({
          'phase': isTwoLegs ? '$phase (Andata)' : phase,
          'match_day': matchDay,
          'home_team_id': t1Id,
          'away_team_id': t2Id,
          'home_goals': aT1,
          'away_goals': aT2,
        });

        if (isTwoLegs) {
          await client.from('matches').insert({
            'phase': '$phase (Ritorno)',
            'match_day': matchDay + 1,
            'home_team_id': t2Id, // Ritorno campi invertiti
            'away_team_id': t1Id,
            'home_goals': rT2,
            'away_goals': rT1,
          });
        }
      } else {
        // AGGIORNA ESISTENTE
        await client.from('matches').update({
          'phase': matchup.ritorno != null ? '$phase (Andata)' : phase,
          'match_day': matchDay,
          'home_team_id': t1Id,
          'away_team_id': t2Id,
          'home_goals': aT1,
          'away_goals': aT2,
        }).eq('id', matchup.andata['id']);

        if (matchup.ritorno != null) {
          await client.from('matches').update({
            'phase': '$phase (Ritorno)',
            'match_day': matchDay + 1,
            'home_team_id': t2Id, // Ritorno campi invertiti
            'away_team_id': t1Id,
            'home_goals': rT2,
            'away_goals': rT1,
          }).eq('id', matchup.ritorno!['id']);
        }
      }
      
      _fetchData();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sfida salvata con successo!'), backgroundColor: Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteMatchup(MatchupData matchup) async {
    try {
      final client = Supabase.instance.client;
      await client.from('matches').delete().eq('id', matchup.andata['id']);
      if (matchup.ritorno != null) {
        await client.from('matches').delete().eq('id', matchup.ritorno!['id']);
      }
      _fetchData();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sfida interamente eliminata!'), backgroundColor: Colors.orange));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildScoreCard(MatchupData matchup) {
    String t1Name = teamNames[matchup.team1Id] ?? 'Squadra Eliminata';
    String t2Name = teamNames[matchup.team2Id] ?? 'Squadra Eliminata';

    return Card(
      elevation: 6,
      color: Colors.white.withOpacity(0.95), 
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showMatchupEditor(matchup: matchup),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: Colors.orange[800], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(matchup.phaseName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(t1Name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey[300]?.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      matchup.hasAnyScore ? '${formatScore(matchup.totalT1)} - ${formatScore(matchup.totalT2)}' : ' VS ', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)
                    ),
                  ),
                  Expanded(child: Text(t2Name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), border: Border(top: BorderSide(color: Colors.grey[200]!))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('Andata', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text('${formatScore(matchup.andataT1)} : ${formatScore(matchup.andataT2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    ],
                  ),
                  if (matchup.ritorno != null) Container(height: 30, width: 1, color: Colors.grey[300]),
                  if (matchup.ritorno != null)
                    Column(
                      children: [
                        const Text('Ritorno', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text('${formatScore(matchup.ritornoT1)} : ${formatScore(matchup.ritornoT2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchList(List<MatchupData> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black54))));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildScoreCard(list[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playoffs = matchups.where((m) => m.andata['match_day'] == 4 || m.andata['match_day'] == 5).toList();
    final semis = matchups.where((m) => m.andata['match_day'] == 6 || m.andata['match_day'] == 7).toList();
    final finals = matchups.where((m) => m.andata['match_day'] >= 8).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        title: const Text('Gestione Fasi Finali', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [Tab(text: 'PLAYOFF (G4-5)'), Tab(text: 'SEMIFINALI (G6-7)'), Tab(text: 'FINALI (G8)')],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMatchList(playoffs, 'Nessuna partita di Playoff.\nPremi + per crearne una.'),
                _buildMatchList(semis, 'Nessuna Semifinale.\nPremi + per crearne una.'),
                _buildMatchList(finals, 'Nessuna Finale.\nPremi + per crearne una.'),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red[800], foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Nuova Sfida', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showMatchupEditor(),
      ),
    );
  }
}