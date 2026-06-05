import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'calendar_screen.dart'; 

class MatchDetailScreen extends StatefulWidget {
  final MatchModel match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool isLoading = true;

  List<Map<String, dynamic>> homePlayers = [];
  List<Map<String, dynamic>> awayPlayers = [];

  @override
  void initState() {
    super.initState();
    _fetchMatchDetails();
  }

  Future<void> _fetchMatchDetails() async {
    try {
      final statsData = await Supabase.instance.client
          .from('matchday_stats')
          .select()
          .eq('match_day', widget.match.matchDay);

      Map<int, Map<String, dynamic>> statsMap = {};
      for (var row in statsData) {
        statsMap[row['player_id']] = row;
      }

      final playersData = await Supabase.instance.client.from('players').select('id, name, role');
      Map<int, Map<String, dynamic>> playersMap = {};
      for (var p in playersData) {
        playersMap[p['id']] = p;
      }

      homePlayers = await _buildTeamRoster(widget.match.homeTeamId, playersMap, statsMap);
      awayPlayers = await _buildTeamRoster(widget.match.awayTeamId, playersMap, statsMap);

      setState(() => isLoading = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento tabellino: $e')));
      setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _buildTeamRoster(String teamId, Map<int, Map<String, dynamic>> playersMap, Map<int, Map<String, dynamic>> statsMap) async {
    final rosterData = await Supabase.instance.client
        .from('roster_players')
        .select('player_id, is_starter, is_captain')
        .eq('team_id', teamId)
        .eq('is_starter', true);

    List<Map<String, dynamic>> teamList = [];

    for (var row in rosterData) {
      int pId = row['player_id'];
      var pInfo = playersMap[pId];
      var pStat = statsMap[pId];

      if (pInfo != null) {
        double baseGrade = pStat != null ? (pStat['base_grade'] as num).toDouble() : 0.0;
        int goals = pStat != null ? pStat['goals_scored'] as int : 0;
        int assists = pStat != null ? pStat['assists'] as int : 0;
        int yellows = pStat != null ? pStat['yellow_cards'] as int : 0;
        int reds = pStat != null ? pStat['red_cards'] as int : 0;
        bool motm = pStat != null ? pStat['man_of_the_match'] as bool : false;
        bool isCaptain = row['is_captain'] == true;

        double fantaGrade = baseGrade;
        if (baseGrade > 0) {
          fantaGrade += (goals * 3);
          fantaGrade += (assists * 1);
          fantaGrade -= (yellows * 0.5);
          fantaGrade -= (reds * 1);
          if (motm) fantaGrade += 0.5;
          if (isCaptain && goals > 0) fantaGrade += (goals * 0.5); 
        }

        teamList.add({
          'name': pInfo['name'],
          'role': pInfo['role'],
          'is_captain': isCaptain,
          'base_grade': baseGrade,
          'fanta_grade': fantaGrade,
          'goals': goals,
          'assists': assists,
          'yellows': yellows,
          'reds': reds,
          'motm': motm,
        });
      }
    }

    final roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5};
    teamList.sort((a, b) => roleOrder[a['role']]!.compareTo(roleOrder[b['role']]!));

    return teamList;
  }

  Color getRoleColor(String role) {
    switch (role) {
      case 'P': return Colors.orange;
      case 'D': return Colors.green;
      case 'C': return Colors.blue;
      case 'A': return Colors.red;
      case 'CT': return const Color.fromARGB(255, 0, 0, 0);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabellino Partita'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header con il Risultato
                Container(
                  color: Colors.green[800],
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: Text(widget.match.homeTeamName, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          '${widget.match.homeGoals ?? '-'} : ${widget.match.awayGoals ?? '-'}',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: Text(widget.match.awayTeamName, textAlign: TextAlign.left, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // IL NUOVO LAYOUT FACCIA A FACCIA
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Formazione di sinistra (In Casa)
                      Expanded(
                        child: Container(
                          color: Colors.grey[100],
                          child: _buildCompactTeamList(homePlayers),
                        ),
                      ),
                      // Linea divisoria centrale
                      const VerticalDivider(width: 2, thickness: 2, color: Colors.grey),
                      // Formazione di destra (In Trasferta)
                      Expanded(
                        child: Container(
                          color: Colors.grey[100],
                          child: _buildCompactTeamList(awayPlayers),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCompactTeamList(List<Map<String, dynamic>> players) {
    if (players.isEmpty) {
      return const Center(child: Text('Nessuna rosa', style: TextStyle(color: Colors.grey, fontSize: 12)));
    }

    return ListView.builder(
      itemCount: players.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final p = players[index];
        bool hasPlayed = p['base_grade'] > 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cerchietto del Ruolo
                CircleAvatar(
                  radius: 12,
                  backgroundColor: getRoleColor(p['role']),
                  child: Text(p['role'], style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                
                // Nome e Icone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p['name'], 
                              overflow: TextOverflow.ellipsis, // Se il nome è troppo lungo, mette i puntini
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)
                            ),
                          ),
                          if (p['is_captain']) const Text(' Ⓒ', style: TextStyle(color: Color.fromARGB(255, 244, 191, 35), fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                      if (hasPlayed) Wrap(
                        spacing: 2,
                        children: [
                          if (p['goals'] > 0) ...List.generate(p['goals'], (_) => const Text('⚽', style: TextStyle(fontSize: 10))),
                          if (p['assists'] > 0) ...List.generate(p['assists'], (_) => const Text('👟', style: TextStyle(fontSize: 10))),
                          if (p['yellows'] > 0) const Text('🟨', style: TextStyle(fontSize: 10)),
                          if (p['reds'] > 0) const Text('🟥', style: TextStyle(fontSize: 10)),
                          if (p['motm']) const Text('🌟', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Voti a destra
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasPlayed ? '${p['fanta_grade']}' : 's.v.',
                      style: TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.bold,
                        color: hasPlayed ? Colors.green[800] : Colors.grey,
                      ),
                    ),
                    if (hasPlayed) Text('${p['base_grade']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}