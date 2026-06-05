import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Aggiunto per leggere chi è l'Admin
import 'calculator_service.dart'; 
import 'tabellino_screen.dart'; // <-- IMPORTIAMO IL NUOVO TABELLINO!

class MatchModel {
  final int id;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  int? homeGoals;
  int? awayGoals;
  final String phase;
  final int matchDay;

  MatchModel(this.id, this.homeTeamId, this.awayTeamId, this.homeTeamName, this.awayTeamName, this.homeGoals, this.awayGoals, this.phase, this.matchDay);
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<MatchModel> matches = [];
  bool isLoading = true;
  bool isCalculating = false;
  bool isAdmin = false; // Variabile per nascondere i poteri speciali

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchMatches();
  }

  // Controlla se l'utente loggato è l'Admin
  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isAdmin = prefs.getBool('isAdmin') ?? false;
    });
  }

  Future<void> _fetchMatches() async {
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
          json['home_goals'],
          json['away_goals'],
          json['phase'],
          json['match_day'],
        );
      }).toList();

      setState(() {
        matches = loadedMatches;
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

      Map<String, Map<String, int>> stats = {};
      for(var t in teams) {
         stats[t['id']] = {'pts': 0, 'played': 0, 'gf': 0, 'ga': 0};
      }

      for (var m in playedMatches) {
        String home = m['home_team_id'];
        String away = m['away_team_id'];
        int hg = m['home_goals'];
        int ag = m['away_goals'];

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

  // POPUP MANUALE (Solo Admin)
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
                    TextField(controller: homeController, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[800]!), borderRadius: BorderRadius.circular(12)))),
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
                    TextField(controller: awayController, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[800]!), borderRadius: BorderRadius.circular(12)))),
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
                int? homeG = int.tryParse(homeController.text);
                int? awayG = int.tryParse(awayController.text);
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

  Future<void> _saveResult(MatchModel match, int homeG, int awayG) async {
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

      final dayMatches = matches.where((m) => m.matchDay == matchDay).toList();

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
        .select('player_id, is_starter, is_bench, is_captain')
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
        coachMultiplier: s != null ? (s['coach_multiplier'] as num).toDouble() : 0.0,
        cleanSheet: s != null ? (s['clean_sheet'] == true) : false,
        penaltySaved: s != null ? (s['penalty_saved'] as int? ?? 0) : 0,
        penaltyMissed: s != null ? (s['penalty_missed'] as int? ?? 0) : 0,
        ownGoals: s != null ? (s['own_goals'] as int? ?? 0) : 0, 
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

  // --- UI METODI PER I RIQUADRI ---

  Widget _buildMatchCard(MatchModel match) {
    final isPlayed = match.homeGoals != null && match.awayGoals != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 4,
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Text(match.homeTeamName, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isPlayed ? Colors.orange[800] : Colors.grey[300]?.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPlayed ? '${match.homeGoals} - ${match.awayGoals}' : ' VS ',
                  style: TextStyle(color: isPlayed ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
            Expanded(child: Text(match.awayTeamName, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
          ],
        ),
        
        // --- LA NUOVA LOGICA TAP (APRE SEMPRE IL TABELLINO) ---
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TabellinoScreen(
                matchDay: match.matchDay,
                team1Id: match.homeTeamId,
                team2Id: match.awayTeamId,
                team1Name: match.homeTeamName,
                team2Name: match.awayTeamName,
                score1: match.homeGoals ?? 0, // Se non è giocata, mostra 0
                score2: match.awayGoals ?? 0, // Se non è giocata, mostra 0
              ),
            ),
          );
        },
        onLongPress: () {
          // Solo l'Admin può forzare un risultato a tavolino
          if (isAdmin) {
            _showScoreDialog(match);
          }
        },
      ),
    );
  }

  Widget _buildDaySection(int day, List<MatchModel> allMatches) {
    final dayMatches = allMatches.where((m) => m.matchDay == day).toList();
    if (dayMatches.isEmpty) return const SizedBox.shrink();

    final matchesA = dayMatches.where((m) => m.phase.toUpperCase().contains('A')).toList();
    final matchesB = dayMatches.where((m) => m.phase.toUpperCase().contains('B')).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 12, right: 12),
      child: Card(
        elevation: 8,
        color: Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.orange[900]!])),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '$dayª GIORNATA',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
            
            if (matchesA.isNotEmpty) ...[
              Container(
                color: Colors.black12,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Text('GIRONE A', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 8),
              ...matchesA.map((m) => _buildMatchCard(m)),
              const SizedBox(height: 12),
            ],

            if (matchesB.isNotEmpty) ...[
              Container(
                color: Colors.black12,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Text('GIRONE B', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 8),
              ...matchesB.map((m) => _buildMatchCard(m)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKnockoutSection(int day, List<MatchModel> allMatches) {
    final dayMatches = allMatches.where((m) => m.matchDay == day).toList();
    if (dayMatches.isEmpty) return const SizedBox.shrink();

    String phaseName = dayMatches.first.phase;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 12, right: 12),
      child: Card(
        elevation: 8,
        color: Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.red[700]!, Colors.red[900]!])),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                phaseName.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
            const SizedBox(height: 8),
            ...dayMatches.map((m) => _buildMatchCard(m)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupMatches = matches.where((m) => m.matchDay <= 3).toList();
    final knockoutMatches = matches.where((m) => m.matchDay > 3).toList();
    final knockoutDays = knockoutMatches.map((m) => m.matchDay).toSet().toList()..sort();

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/sfondo.png'), 
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Calendario e Risultati', style: TextStyle(color: Color.fromRGBO(0, 0, 0, 1), fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white.withOpacity(0.8),
            elevation: 0,
            iconTheme: const IconThemeData(color: Color.fromRGBO(0, 0, 0, 1)),
            bottom: TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Colors.orange[800], 
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'GIRONI (1-3)'),
                Tab(text: 'FASI FINALI'),
              ],
            ),
          ),
          body: isLoading || isCalculating
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      isCalculating ? 'Calcolo in corso...' : 'Caricamento...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  groupMatches.isEmpty 
                    ? const Center(child: Text('Nessuna partita in calendario.', style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 80),
                        itemCount: 3, 
                        itemBuilder: (context, index) {
                          return _buildDaySection(index + 1, groupMatches);
                        },
                      ),
                      
                  knockoutMatches.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(16)),
                          child: const Text(
                            'Le fasi a eliminazione diretta verranno sbloccate al termine dei gironi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 80),
                        itemCount: knockoutDays.length, 
                        itemBuilder: (context, index) {
                          return _buildKnockoutSection(knockoutDays[index], knockoutMatches);
                        },
                      ),
                ],
              ),
          floatingActionButton: isAdmin 
            ? FloatingActionButton.extended(
                onPressed: _showCalculateDialog,
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                icon: const Icon(Icons.calculate),
                label: const Text('Calcola Giornata', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            : null,
        ),
      ),
    );
  }
}