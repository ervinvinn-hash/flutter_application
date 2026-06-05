import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// --- SCHERMATA PRINCIPALE ---

class StandingsScreen extends StatefulWidget {
  final String teamId;

  const StandingsScreen({super.key, required this.teamId});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  Map<String, List<TeamRanking>> groups = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStandingsFromDatabase();
  }

  Future<void> _fetchStandingsFromDatabase() async {
    try {
      final data = await Supabase.instance.client.from('fantasy_teams').select();
      Map<String, List<TeamRanking>> loadedGroups = {};

      for (var row in data) {
        String group = row['group_name'] ?? '-';
        
        if (group != 'A' && group != 'B') continue;

        TeamRanking team = TeamRanking(
          row['id'],
          row['team_name'],
          row['owner_name'] ?? 'Mister',
          group,
          row['group_points'] ?? 0,
          row['matches_played'] ?? 0,
          row['goals_for'] ?? 0,
          row['goals_against'] ?? 0,
          (row['total_score'] ?? 0).toDouble(),
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

      setState(() {
        var sortedKeys = loadedGroups.keys.toList()..sort();
        groups = {for (var k in sortedKeys) k: loadedGroups[k]!};
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
      setState(() => isLoading = false);
    }
  }

  Widget _buildGroupTable(String groupName, List<TeamRanking> teams) {
    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 8,
      color: Colors.white.withOpacity(0.9), // Effetto vetro VIP
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: groupName == 'A' ? Colors.orange[800] : Colors.orange[800], // Colori eleganti e scuri per i gironi
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'GIRONE $groupName',
              style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2), // Testo oro/arancio
              textAlign: TextAlign.center,
            ),
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

            // La tua squadra si evidenzia in arancio chiaro, i primi 3 hanno un tocco delicato
            Color? rowColor = team.isMyTeam 
                ? Colors.orange[100]?.withOpacity(0.7) 
                : (position <= 3 ? Colors.green[50]?.withOpacity(0.4) : Colors.transparent);
            FontWeight fw = team.isMyTeam ? FontWeight.bold : FontWeight.normal;

            return Container(
              color: rowColor,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('$position', style: TextStyle(fontWeight: position <= 3 ? FontWeight.bold : FontWeight.bold, color: position <= 3 ? const Color.fromARGB(255, 46, 179, 2) : const Color.fromARGB(255, 255, 0, 0))),
                  ),
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
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/sfondo.png'), // Sfondo globale
          fit: BoxFit.cover,
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent, // Mantiene lo sfondo visibile
          appBar: AppBar(
            title: const Text('Classifica Lega', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white.withOpacity(0.8), // Barra stile vetro
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            bottom: TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Colors.orange[800], // Indicatore VIP
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'GIRONI'),
                Tab(text: 'ELIMINAZIONE DIRETTA'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // TAB 1: GIRONI
              isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : groups.isEmpty 
                      ? const Center(child: Text('I gironi non sono ancora stati composti.', style: TextStyle(color: Colors.white70)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20, top: 10),
                          itemCount: groups.keys.length,
                          itemBuilder: (context, index) {
                            String groupName = groups.keys.elementAt(index);
                            return _buildGroupTable(groupName, groups[groupName]!);
                          },
                        ),

              // TAB 2: ELIMINAZIONE DIRETTA
              KnockoutBracketWidget(groups: groups),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET ELIMINAZIONE DIRETTA ---

class KnockoutBracketWidget extends StatefulWidget {
  final Map<String, List<TeamRanking>> groups; 

  const KnockoutBracketWidget({super.key, required this.groups});

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

  String getTeamPlaceholder(String groupName, int position) {
    if (widget.groups.containsKey(groupName) && widget.groups[groupName]!.length >= position) {
      return widget.groups[groupName]![position - 1].teamName;
    }
    return '$positionª Girone $groupName';
  }

  Widget _buildMatchupCard(String title, String team1, String team2, {bool isTwoLegs = true}) {
    return Card(
      elevation: 6,
      color: Colors.white.withOpacity(0.95), // Effetto vetro solido
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange[800], // Tema VIP per l'intestazione partita
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(team1, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[300]?.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                  child: const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
                Expanded(child: Text(team2, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Andata', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(isTwoLegs ? '- : -' : 'Gara Secca', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ],
                ),
                if (isTwoLegs) Container(height: 30, width: 1, color: Colors.grey[300]),
                if (isTwoLegs)
                  const Column(
                    children: [
                      Text('Ritorno', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      SizedBox(height: 4),
                      Text('- : -', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white.withOpacity(0.9), // Barra scorrimento fasi stile vetro
          child: TabBar(
            controller: _bracketController,
            labelColor: Colors.orange[800],
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.orange[800],
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(text: '1. PLAYOFF'),
              Tab(text: '2. SEMIFINALI'),
              Tab(text: '3. FINALI'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _bracketController,
            children: [
              // PAGINA 1: PLAYOFF
              ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Le 3 sfide di Playoff (Andata e Ritorno)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                  ),
                  _buildMatchupCard('Match 1', getTeamPlaceholder('A', 1), getTeamPlaceholder('B', 3)),
                  _buildMatchupCard('Match 2', getTeamPlaceholder('A', 2), getTeamPlaceholder('B', 2)),
                  _buildMatchupCard('Match 3', getTeamPlaceholder('A', 3), getTeamPlaceholder('B', 1)),
                ],
              ),
              
              // PAGINA 2: SEMIFINALI
              ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Le 2 Semifinali (Andata e Ritorno)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                  ),
                  _buildMatchupCard('Semifinale 1', 'Vincente Match 1', 'Miglior Sconfitta (Punti Tot)'),
                  _buildMatchupCard('Semifinale 2', 'Vincente Match 2', 'Vincente Match 3'),
                ],
              ),
              
              // PAGINA 3: FINALI
              ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Le Finali (Gara Secca in campo neutro)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                  ),
                  _buildMatchupCard('FINALE 1°/2° POSTO 🏆', 'Vincente Semi 1', 'Vincente Semi 2', isTwoLegs: false),
                  const SizedBox(height: 10),
                  _buildMatchupCard('FINALE 3°/4° POSTO 🥉', 'Perdente Semi 1', 'Perdente Semi 2', isTwoLegs: false),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}