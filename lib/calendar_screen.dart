import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'calculator_service.dart'; 
import 'tabellino_screen.dart'; 

// --- MODELLO DATI ---
class MatchModel {
  final int id;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  num? homeGoals;
  num? awayGoals;
  final String phase;
  final int matchDay;

  MatchModel(this.id, this.homeTeamId, this.awayTeamId, this.homeTeamName, this.awayTeamName, this.homeGoals, this.awayGoals, this.phase, this.matchDay);
}

// --- CLASSE AUSILIARIA PER RAGGRUPPARE LE SFIDE A/R ---
class CalendarMatchup {
  final String team1Id;
  final String team2Id;
  final String phaseName;
  final MatchModel andata;
  final MatchModel? ritorno;

  CalendarMatchup(this.team1Id, this.team2Id, this.phaseName, this.andata, this.ritorno);

  num? get andataT1 => andata.homeTeamId == team1Id ? andata.homeGoals : andata.awayGoals;
  num? get andataT2 => andata.awayTeamId == team2Id ? andata.awayGoals : andata.homeGoals;
  
  num? get ritornoT1 => ritorno != null ? (ritorno!.homeTeamId == team1Id ? ritorno!.homeGoals : ritorno!.awayGoals) : null;
  num? get ritornoT2 => ritorno != null ? (ritorno!.awayTeamId == team2Id ? ritorno!.awayGoals : ritorno!.homeGoals) : null;

  bool get hasAnyScore => andataT1 != null || andataT2 != null || ritornoT1 != null || ritornoT2 != null;
  num get totalT1 => (andataT1 ?? 0) + (ritornoT1 ?? 0);
  num get totalT2 => (andataT2 ?? 0) + (ritornoT2 ?? 0);
}

String formatScore(num? score) {
  if (score == null) return '-';
  if (score == score.toInt()) return score.toInt().toString();
  return score.toString();
}

// --- SCHERMATA PRINCIPALE ---
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<MatchModel> allMatches = [];
  bool isLoading = true;
  bool isCalculating = false;
  bool isAdmin = false; 
  
  int selectedGroupMatchday = 1;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchMatches();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isAdmin = prefs.getBool('isAdmin') ?? false;
      });
    }
  }

  Future<void> _fetchMatches() async {
    setState(() => isLoading = true);
    try {
      final teamsData = await Supabase.instance.client.from('fantasy_teams').select('id, team_name');
      Map<String, String> teamNames = {};
      for (var t in teamsData) {
        teamNames[t['id']] = t['team_name'];
      }

      final matchesData = await Supabase.instance.client.from('matches').select().order('match_day', ascending: true);
      
      List<MatchModel> loadedMatches = matchesData.map<MatchModel>((json) {
        return MatchModel(
          json['id'],
          json['home_team_id'],
          json['away_team_id'],
          teamNames[json['home_team_id']] ?? 'Squadra Sconosciuta',
          teamNames[json['away_team_id']] ?? 'Squadra Sconosciuta',
          json['home_goals'] as num?,
          json['away_goals'] as num?,
          json['phase'] ?? 'Girone',
          json['match_day'],
        );
      }).toList();

      setState(() {
        allMatches = loadedMatches;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateLeagueStandings() async {
    try {
      final teams = await Supabase.instance.client.from('fantasy_teams').select('id');
      
      final playedMatches = await Supabase.instance.client.from('matches')
          .select()
          .not('home_goals', 'is', null)
          .ilike('phase', '%Girone%'); 

      Map<String, Map<String, num>> stats = {};
      for(var t in teams) {
         stats[t['id']] = {'pts': 0, 'played': 0, 'gf': 0, 'ga': 0};
      }

      for (var m in playedMatches) {
        String home = m['home_team_id'];
        String away = m['away_team_id'];
        num hg = m['home_goals'];
        num ag = m['away_goals'];

        if(stats.containsKey(home)) {
          stats[home]!['played'] = stats[home]!['played']! + 1;
          stats[home]!['gf'] = stats[home]!['gf']! + hg;
          stats[home]!['ga'] = stats[home]!['ga']! + ag;
        }
        if(stats.containsKey(away)) {
          stats[away]!['played'] = stats[away]!['played']! + 1;
          stats[away]!['gf'] = stats[away]!['gf']! + ag;
          stats[away]!['ga'] = stats[away]!['ga']! + hg;
        }

        if (hg > ag) {
          if(stats.containsKey(home)) stats[home]!['pts'] = stats[home]!['pts']! + 3;
        } else if (ag > hg) {
          if(stats.containsKey(away)) stats[away]!['pts'] = stats[away]!['pts']! + 3;
        } else {
          if(stats.containsKey(home)) stats[home]!['pts'] = stats[home]!['pts']! + 1;
          if(stats.containsKey(away)) stats[away]!['pts'] = stats[away]!['pts']! + 1;
        }
      }

      for (var teamId in stats.keys) {
        await Supabase.instance.client.from('fantasy_teams').update({
          'group_points': stats[teamId]!['pts'],
          'matches_played': stats[teamId]!['played'],
          'goals_for': stats[teamId]!['gf'],
          'goals_against': stats[teamId]!['ga'],
        }).eq('id', teamId);
      }
    } catch (e) {
      debugPrint('Errore aggiornamento classifica: $e');
    }
  }

  void _showScoreDialog(MatchModel match) {
    final homeController = TextEditingController(text: match.homeGoals?.toString() ?? '');
    final awayController = TextEditingController(text: match.awayGoals?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Risultato: ${match.phase}', style: TextStyle(color: Colors.orange[900])),
          content: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(match.homeTeamName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(controller: homeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[800]!), borderRadius: BorderRadius.circular(12)))),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text(' - ', style: TextStyle(fontSize: 24))),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(match.awayTeamName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(controller: awayController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[800]!), borderRadius: BorderRadius.circular(12)))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
              onPressed: () async {
                num? homeG = num.tryParse(homeController.text);
                num? awayG = num.tryParse(awayController.text);
                if (homeG != null && awayG != null) {
                  Navigator.pop(context);
                  await _saveResult(match, homeG, awayG);
                }
              },
              child: const Text('Salva Risultato (A Tavolino)'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveResult(MatchModel match, num homeG, num awayG) async {
    try {
      await Supabase.instance.client.from('matches').update({
        'home_goals': homeG,
        'away_goals': awayG,
      }).eq('id', match.id);

      setState(() {
        match.homeGoals = homeG;
        match.awayGoals = awayG;
      });

      await _updateLeagueStandings();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e'), backgroundColor: Colors.red));
    }
  }

  void _showCalculateDialog() {
    int selectedDay = 1;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Calcola Giornata', style: TextStyle(color: Colors.orange[900])),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Seleziona la giornata per calcolare automaticamente tutte le partite.'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.orange[800]!), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDay,
                        isExpanded: true,
                        items: List.generate(8, (index) => index + 1).map((int value) { 
                          return DropdownMenuItem<int>(value: value, child: Text('Giornata $value', style: const TextStyle(fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: (int? newValue) {
                          setDialogState(() => selectedDay = newValue!);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _calculateMatchday(selectedDay);
                  },
                  child: const Text('Avvia Calcolo'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _calculateMatchday(int matchDay) async {
    setState(() => isCalculating = true);
    try {
      final calcService = CalculatorService();

      final statsData = await Supabase.instance.client.from('matchday_stats').select().eq('match_day', matchDay);
      if (statsData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Nessun voto inserito per questa giornata!'), backgroundColor: Colors.orange[800]));
        setState(() => isCalculating = false);
        return;
      }

      Map<int, Map<String, dynamic>> dayStats = {};
      for (var row in statsData) {
        dayStats[row['player_id']] = row;
      }

      final playersData = await Supabase.instance.client.from('players').select('id, role');
      Map<int, String> playerRoles = {};
      for (var p in playersData) {
        playerRoles[p['id']] = p['role'];
      }

      final dayMatches = allMatches.where((m) => m.matchDay == matchDay).toList();

      for (var match in dayMatches) {
        double homeScore = await _getTeamScore(match.homeTeamId, dayStats, playerRoles, calcService);
        double awayScore = await _getTeamScore(match.awayTeamId, dayStats, playerRoles, calcService);

        bool isKnockout = !match.phase.toLowerCase().contains('girone');
        
        Map<String, int> result = calcService.calculateMatchResult(homeScore, awayScore, isKnockout);
        
        await Supabase.instance.client.from('matches').update({
          'home_goals': result['homeGoals']!,
          'away_goals': result['awayGoals']!,
        }).eq('id', match.id);

        setState(() {
          match.homeGoals = result['homeGoals'];
          match.awayGoals = result['awayGoals'];
        });
      }

      await _updateLeagueStandings();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Risultati Giornata $matchDay calcolati!'), backgroundColor: Colors.green));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore durante il calcolo: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isCalculating = false);
    }
  }

  Future<double> _getTeamScore(String teamId, Map<int, Map<String, dynamic>> stats, Map<int, String> roles, CalculatorService calc) async {
    final rosterData = await Supabase.instance.client.from('roster_players')
        .select('player_id, is_starter, is_bench, is_captain, bench_order')
        .eq('team_id', teamId);

    List<PlayerStat> roster = [];
    PlayerStat? coach;
    PlayerStat? captain;

    for (var row in rosterData) {
      int pId = row['player_id'];
      String role = roles[pId] ?? '';
      bool isStarter = row['is_starter'] ?? false;
      bool isBench = row['is_bench'] ?? false;
      bool isCaptain = row['is_captain'] ?? false;
      
      if (!isStarter && !isBench && role != 'CT') continue; 

      var s = stats[pId];
      
      PlayerStat pStat = PlayerStat(
        id: pId,
        role: role,
        isStarter: isStarter,
        isBench: isBench,
        baseGrade: s != null ? (s['base_grade'] as num).toDouble() : 0.0,
        goalsScored: s != null ? s['goals_scored'] as int : 0,
        assists: s != null ? s['assists'] as int : 0,
        yellowCards: s != null ? s['yellow_cards'] as int : 0,
        redCards: s != null ? s['red_cards'] as int : 0,
        manOfTheMatch: s != null ? s['man_of_the_match'] as bool : false,
        coachMultiplier: s != null ? (s['coach_multiplier'] as num? ?? 0.0).toDouble() : 0.0,
        cleanSheet: s != null ? (s['clean_sheet'] == true) : false,
        penaltySaved: s != null ? (s['penalty_saved'] as int? ?? 0) : 0,
        penaltyMissed: s != null ? (s['penalty_missed'] as int? ?? 0) : 0,
        ownGoals: s != null ? (s['own_goals'] as int? ?? 0) : 0, 
        goalsConceded: s != null ? (s['goals_conceded'] as int? ?? 0) : 0,
        benchOrder: row['bench_order'] ?? 99,
      );

      if (role == 'CT') {
        coach = pStat;
      } else {
        roster.add(pStat);
        if (isCaptain) captain = pStat;
      }
    }

    return await calc.calculateTeamScore(roster, coach, captain);
  }

  // --- LOGICA RAGGRUPPAMENTO KNOCKOUT ---
  List<CalendarMatchup> _getGroupedKnockouts(List<MatchModel> matches) {
    Map<String, List<MatchModel>> grouped = {};
    for (var m in matches) {
      List<String> ids = [m.homeTeamId, m.awayTeamId];
      ids.sort();
      int phaseKey = m.matchDay <= 5 ? 1 : (m.matchDay <= 7 ? 2 : 3);
      String key = '${ids[0]}_${ids[1]}_$phaseKey';
      grouped.putIfAbsent(key, () => []).add(m);
    }
    
    List<CalendarMatchup> result = [];
    for (var list in grouped.values) {
      list.sort((a, b) => a.matchDay.compareTo(b.matchDay));
      var andata = list[0];
      var ritorno = list.length > 1 ? list[1] : null;
      String cleanPhase = andata.phase.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
      
      result.add(CalendarMatchup(andata.homeTeamId, andata.awayTeamId, cleanPhase, andata, ritorno));
    }
    return result;
  }

  // --- WIDGET RIGA CLICCABILE PER APRIRE IL TABELLINO ---
  Widget _buildClickableMatchRow(String label, MatchModel match) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TabellinoScreen(
            matchDay: match.matchDay,
            team1Id: match.homeTeamId,
            team2Id: match.awayTeamId,
            team1Name: match.homeTeamName,
            team2Name: match.awayTeamName,
            score1: match.homeGoals ?? 0,
            score2: match.awayGoals ?? 0,
          ),
        ),
      ).then((_) => _fetchMatches()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
              child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(match.homeTeamName, style: const TextStyle(fontSize: 14, color: Colors.black87))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey[300]!)),
              child: Text('${formatScore(match.homeGoals)} - ${formatScore(match.awayGoals)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
            ),
            Expanded(child: Text(match.awayTeamName, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, color: Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildKnockoutMatchupCard(CalendarMatchup matchup) {
    // CORREZIONE BUG NOMI SQUADRE FASI FINALI:
    // Estraiamo il nome esatto direttamente dalla partita di andata del playoff
    // invece di cercarlo globalmente (evitando così di pescare i nomi degli avversari dei gironi).
    String t1Name = matchup.andata.homeTeamId == matchup.team1Id 
        ? matchup.andata.homeTeamName 
        : matchup.andata.awayTeamName;
        
    String t2Name = matchup.andata.homeTeamId == matchup.team2Id 
        ? matchup.andata.homeTeamName 
        : matchup.andata.awayTeamName;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: Colors.orange[800], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Text(matchup.phaseName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(t1Name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[200]!)),
                  child: Text(
                    matchup.hasAnyScore ? '${formatScore(matchup.totalT1)} - ${formatScore(matchup.totalT2)}' : ' TOT ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange[900]),
                  ),
                ),
                Expanded(child: Text(t2Name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              ],
            ),
          ),
          const Divider(height: 10),
          _buildClickableMatchRow('ANDATA (G${matchup.andata.matchDay})', matchup.andata),
          if (matchup.ritorno != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildClickableMatchRow('RITORNO (G${matchup.ritorno!.matchDay})', matchup.ritorno!),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildKnockoutTabList(List<CalendarMatchup> list, String emptyMsg) {
    if (list.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text(emptyMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 15))));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      itemCount: list.length,
      itemBuilder: (context, index) => _buildKnockoutMatchupCard(list[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupMatches = allMatches.where((m) => m.matchDay <= 3 && m.matchDay == selectedGroupMatchday).toList();
    final allKnockouts = allMatches.where((m) => m.matchDay >= 4).toList();
    final groupedKnockouts = _getGroupedKnockouts(allKnockouts);

    final playoffs = groupedKnockouts.where((m) => m.andata.matchDay == 4 || m.andata.matchDay == 5).toList();
    final semis = groupedKnockouts.where((m) => m.andata.matchDay == 6 || m.andata.matchDay == 7).toList();
    final finals = groupedKnockouts.where((m) => m.andata.matchDay >= 8).toList();

    return Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/sfondo.png'), fit: BoxFit.cover)),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Calendario Competizione', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white.withOpacity(0.8),
            elevation: 0,
            actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.black87), onPressed: _fetchMatches)],
            bottom: TabBar(
              labelColor: Colors.black, unselectedLabelColor: Colors.black54, indicatorColor: Colors.orange[800],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [Tab(text: 'GIRONI'), Tab(text: 'FASI FINALI')],
            ),
          ),
          body: isCalculating
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.orange), SizedBox(height: 16), Text('Calcolo in corso...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))
              : isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : TabBarView(
                      children: [
                        // --- GIRONI ---
                        Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4), padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Seleziona Giornata:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                  DropdownButton<int>(
                                    value: selectedGroupMatchday, underline: Container(),
                                    style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 16),
                                    items: [1, 2, 3].map((val) => DropdownMenuItem(value: val, child: Text('Giornata $val'))).toList(),
                                    onChanged: (v) { if (v != null) setState(() => selectedGroupMatchday = v); },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: groupMatches.isEmpty
                                  ? const Center(child: Text('Nessun match configurato.', style: TextStyle(color: Colors.white70)))
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(bottom: 80, top: 6),
                                      itemCount: groupMatches.length,
                                      itemBuilder: (context, index) {
                                        final m = groupMatches[index];
                                        return Card(
                                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: ListTile(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => TabellinoScreen(
                                                    matchDay: m.matchDay,
                                                    team1Id: m.homeTeamId,
                                                    team2Id: m.awayTeamId,
                                                    team1Name: m.homeTeamName,
                                                    team2Name: m.awayTeamName,
                                                    score1: m.homeGoals ?? 0,
                                                    score2: m.awayGoals ?? 0,
                                                  ),
                                                ),
                                              ).then((_) => _fetchMatches());
                                            },
                                            onLongPress: () { if (isAdmin) _showScoreDialog(m); },
                                            title: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(m.homeTeamName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                                                  child: Text('${formatScore(m.homeGoals)} - ${formatScore(m.awayGoals)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                                Expanded(child: Text(m.awayTeamName, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        // --- FASI FINALI ---
                        DefaultTabController(
                          length: 3,
                          child: Column(
                            children: [
                              Container(
                                color: Colors.white.withOpacity(0.85),
                                child: TabBar(
                                  labelColor: Colors.orange[800], unselectedLabelColor: Colors.black54, indicatorColor: Colors.orange[800],
                                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  tabs: const [Tab(text: '1. PLAYOFF (G4-5)'), Tab(text: '2. SEMIFINALI (G6-7)'), Tab(text: '3. FINALI (G8)')],
                                ),
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildKnockoutTabList(playoffs, 'Nessun match di Playoff inserito.\nGenerali dalla schermata Classifica.'),
                                    _buildKnockoutTabList(semis, 'Le Semifinali non sono ancora state create.'),
                                    _buildKnockoutTabList(finals, 'Le Finali non sono ancora state create.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
          floatingActionButton: isAdmin && !isLoading
              ? FloatingActionButton.extended(
                  onPressed: _showCalculateDialog, backgroundColor: Colors.orange[800], foregroundColor: Colors.white,
                  icon: const Icon(Icons.calculate), label: const Text('Calcola Giornata', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
        ),
      ),
    );
  }
}