import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- CLASSI DATI ---
class TeamRanking {
  final String id;
  final String teamName;
  final String ownerName;
  final String groupName;
  final int groupPoints;
  final int played;
  final int goalsFor;
  final int goalsAgainst;
  final double totalScore;
  final bool isMyTeam;

  TeamRanking(this.id, this.teamName, this.ownerName, this.groupName, this.groupPoints, this.played, this.goalsFor, this.goalsAgainst, this.totalScore, {this.isMyTeam = false});
}

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

// --- SCHERMATA PRINCIPALE ---
class StandingsScreen extends StatefulWidget {
  final String teamId;
  const StandingsScreen({super.key, required this.teamId});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  Map<String, List<TeamRanking>> groups = {};
  List<MatchupData> knockoutMatchups = [];
  Map<String, String> teamNames = {};
  
  bool isLoading = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchStandingsFromDatabase();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isAdmin = prefs.getBool('isAdmin') ?? false);
  }

  Future<void> _fetchStandingsFromDatabase() async {
    setState(() => isLoading = true);
    try {
      final data = await Supabase.instance.client.from('fantasy_teams').select();
      Map<String, List<TeamRanking>> loadedGroups = {};
      Map<String, String> tNames = {};

      for (var row in data) {
        String group = row['group_name'] ?? '-';
        tNames[row['id']] = row['team_name']; 
        
        if (group != 'A' && group != 'B') continue;

        TeamRanking team = TeamRanking(
          row['id'], row['team_name'], row['owner_name'] ?? 'Mister', group,
          row['group_points'] ?? 0, row['matches_played'] ?? 0, row['goals_for'] ?? 0,
          row['goals_against'] ?? 0, (row['total_score'] ?? 0).toDouble(),
          isMyTeam: row['id'] == widget.teamId, 
        );
        loadedGroups.putIfAbsent(group, () => []).add(team);
      }

      loadedGroups.forEach((groupName, teams) {
        teams.sort((a, b) {
          int cmp = b.groupPoints.compareTo(a.groupPoints);
          if (cmp != 0) return cmp;
          int diffA = a.goalsFor - a.goalsAgainst;
          int diffB = b.goalsFor - b.goalsAgainst;
          int diffCmp = diffB.compareTo(diffA);
          if (diffCmp != 0) return diffCmp;
          return b.totalScore.compareTo(a.totalScore); 
        });
      });

      final matchesData = await Supabase.instance.client.from('matches').select().gte('match_day', 4).order('match_day', ascending: true);
      List<MatchupData> groupedMatches = groupMatchups(List<Map<String, dynamic>>.from(matchesData));

      setState(() {
        var sortedKeys = loadedGroups.keys.toList()..sort();
        groups = {for (var k in sortedKeys) k: loadedGroups[k]!};
        teamNames = tNames;
        knockoutMatchups = groupedMatches;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  Future<void> _generatePlayoffMatches() async {
    if (groups['A'] == null || groups['B'] == null || groups['A']!.length < 3 || groups['B']!.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('I gironi non sono completi!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Genera Playoff Ufficiali'),
        content: const Text('Vuoi generare le partite di Andata e Ritorno per i Playoff?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final tA1 = groups['A']![0].id; final tA2 = groups['A']![1].id; final tA3 = groups['A']![2].id;
                final tB1 = groups['B']![0].id; final tB2 = groups['B']![1].id; final tB3 = groups['B']![2].id;
                final client = Supabase.instance.client;
                
                await client.from('matches').insert([
                  {'home_team_id': tA1, 'away_team_id': tB3, 'match_day': 4, 'phase': 'Playoff (Andata)'},
                  {'home_team_id': tA2, 'away_team_id': tB2, 'match_day': 4, 'phase': 'Playoff (Andata)'},
                  {'home_team_id': tA3, 'away_team_id': tB1, 'match_day': 4, 'phase': 'Playoff (Andata)'},
                ]);
                await client.from('matches').insert([
                  {'home_team_id': tB3, 'away_team_id': tA1, 'match_day': 5, 'phase': 'Playoff (Ritorno)'},
                  {'home_team_id': tB2, 'away_team_id': tA2, 'match_day': 5, 'phase': 'Playoff (Ritorno)'},
                  {'home_team_id': tB1, 'away_team_id': tA3, 'match_day': 5, 'phase': 'Playoff (Ritorno)'},
                ]);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🪄 Partite generate!'), backgroundColor: Colors.green));
                _fetchStandingsFromDatabase();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore DB: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Genera Partite'),
          )
        ]
      )
    );
  }

  Widget _buildGroupTable(String groupName, List<TeamRanking> teams) {
    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 8,
      color: Colors.white.withOpacity(0.9), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.orange[800], 
            padding: const EdgeInsets.all(12.0),
            child: Text('GIRONE $groupName', style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2), textAlign: TextAlign.center),
          ),
          Container(
            color: Colors.grey[200]?.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: const Row(
              children: [
                SizedBox(width: 20, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Squadra', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 30, child: Center(child: Text('Pt', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)))),
                SizedBox(width: 30, child: Center(child: Text('G', style: TextStyle(fontWeight: FontWeight.bold)))),
                SizedBox(width: 40, child: Center(child: Text('GF:GS', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
          ...teams.asMap().entries.map((entry) {
            int position = entry.key + 1;
            TeamRanking team = entry.value;
            Color? rowColor = team.isMyTeam ? Colors.orange[100]?.withOpacity(0.7) : (position <= 3 ? Colors.green[50]?.withOpacity(0.4) : Colors.transparent);
            FontWeight fw = team.isMyTeam ? FontWeight.bold : FontWeight.normal;
            return Container(
              color: rowColor,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text('$position', style: TextStyle(fontWeight: position <= 3 ? FontWeight.bold : FontWeight.bold, color: position <= 3 ? const Color.fromARGB(255, 46, 179, 2) : const Color.fromARGB(255, 255, 0, 0)))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team.teamName, style: TextStyle(fontWeight: fw, fontSize: 16, color: Colors.black87)),
                        Text(team.ownerName, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  SizedBox(width: 30, child: Center(child: Text('${team.groupPoints}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange[900])))),
                  SizedBox(width: 30, child: Center(child: Text('${team.played}', style: TextStyle(fontWeight: fw)))),
                  SizedBox(width: 40, child: Center(child: Text('${team.goalsFor}:${team.goalsAgainst}', style: TextStyle(fontWeight: fw)))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/sfondo.png'), fit: BoxFit.cover)),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent, 
          appBar: AppBar(
            title: const Text('Classifica Lega', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white.withOpacity(0.8), 
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.black87), tooltip: 'Aggiorna Dati', onPressed: _fetchStandingsFromDatabase),
              if (isAdmin && !isLoading)
                IconButton(icon: Icon(Icons.auto_awesome, color: Colors.orange[900]), tooltip: 'Genera Partite Playoff', onPressed: _generatePlayoffMatches),
            ],
            bottom: TabBar(
              labelColor: Colors.black, unselectedLabelColor: Colors.black54, indicatorColor: Colors.orange[800], 
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [Tab(text: 'GIRONI'), Tab(text: 'ELIMINAZIONE DIRETTA')],
            ),
          ),
          body: TabBarView(
            children: [
              RefreshIndicator(
                onRefresh: _fetchStandingsFromDatabase, color: Colors.orange[800],
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                    : groups.isEmpty 
                        ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('I gironi non sono ancora stati composti.', style: TextStyle(color: Colors.white70))))])
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20, top: 10),
                            itemCount: groups.keys.length,
                            itemBuilder: (context, index) {
                              String groupName = groups.keys.elementAt(index);
                              return _buildGroupTable(groupName, groups[groupName]!);
                            },
                          ),
              ),
              KnockoutBracketWidget(matchups: knockoutMatchups, teamNames: teamNames, onRefresh: _fetchStandingsFromDatabase),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET ELIMINAZIONE DIRETTA ---
class KnockoutBracketWidget extends StatefulWidget {
  final List<MatchupData> matchups; 
  final Map<String, String> teamNames;
  final Future<void> Function() onRefresh;

  const KnockoutBracketWidget({super.key, required this.matchups, required this.teamNames, required this.onRefresh});

  @override
  State<KnockoutBracketWidget> createState() => _KnockoutBracketWidgetState();
}

class _KnockoutBracketWidgetState extends State<KnockoutBracketWidget> with SingleTickerProviderStateMixin {
  late TabController _bracketController;

  @override
  void initState() {
    super.initState();
    _bracketController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _bracketController.dispose();
    super.dispose();
  }

  Widget _buildScoreCard(MatchupData matchup) {
    String t1Name = widget.teamNames[matchup.team1Id] ?? 'Squadra Eliminata';
    String t2Name = widget.teamNames[matchup.team2Id] ?? 'Squadra Eliminata';

    return Card(
      elevation: 6,
      color: Colors.white.withOpacity(0.95), 
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: Colors.orange[800], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Text(matchup.phaseName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
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
    );
  }

  Widget _buildMatchList(List<MatchupData> list, String emptyMessage) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: Colors.orange[800],
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [Padding(padding: const EdgeInsets.only(top: 60.0, left: 20, right: 20), child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)))],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: Colors.orange[800],
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return _buildScoreCard(list[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playoffs = widget.matchups.where((m) => m.andata['match_day'] == 4 || m.andata['match_day'] == 5).toList();
    final semis = widget.matchups.where((m) => m.andata['match_day'] == 6 || m.andata['match_day'] == 7).toList();
    final finals = widget.matchups.where((m) => m.andata['match_day'] >= 8).toList();

    return Column(
      children: [
        Container(
          color: Colors.white.withOpacity(0.9), 
          child: TabBar(
            controller: _bracketController,
            labelColor: Colors.orange[800],
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.orange[800],
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [Tab(text: '1. PLAYOFF'), Tab(text: '2. SEMIFINALI'), Tab(text: '3. FINALI')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _bracketController,
            children: [
              _buildMatchList(playoffs, 'Nessuna partita di Playoff trovata.\nL\'Admin deve ancora generare gli scontri.'),
              _buildMatchList(semis, 'Le Semifinali non sono ancora state decise.'),
              _buildMatchList(finals, 'Le Finali non sono ancora state decise.'),
            ],
          ),
        ),
      ],
    );
  }
}