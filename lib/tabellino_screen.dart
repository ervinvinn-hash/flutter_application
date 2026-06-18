import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TabellinoScreen extends StatefulWidget {
  final int matchDay;
  final String team1Id;
  final String team2Id;
  final String team1Name;
  final String team2Name;
  final int score1;
  final int score2;

  const TabellinoScreen({
    super.key,
    required this.matchDay,
    required this.team1Id,
    required this.team2Id,
    required this.team1Name,
    required this.team2Name,
    required this.score1,
    required this.score2,
  });

  @override
  State<TabellinoScreen> createState() => _TabellinoScreenState();
}

class _TabellinoScreenState extends State<TabellinoScreen> {
  bool isLoading = true;
  
  Map<String, dynamic>? t1Coach;
  Map<String, dynamic>? t2Coach;

  List<Map<String, dynamic>> t1Starters = [];
  List<Map<String, dynamic>> t1Bench = [];
  List<Map<String, dynamic>> t2Starters = [];
  List<Map<String, dynamic>> t2Bench = [];
  
  Map<int, Map<String, dynamic>> playerStats = {};

  double t1Total = 0.0;
  double t2Total = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTabellinoData();
  }

  // --- MOTORE DI SIMULAZIONE SOSTITUZIONI PER LA GRAFICA ---
  void _simulateSubs(List<Map<String, dynamic>> starters, List<Map<String, dynamic>> bench) {
    for (var p in starters) p['status'] = 'playing';
    for (var p in bench) p['status'] = 'unused';
    
    int subsMade = 0;
    for (var starter in starters) {
      var s = playerStats[starter['player_id']];
      double baseGrade = s != null ? (s['base_grade'] as num).toDouble() : 0.0;
      
      if (baseGrade == 0.0) {
        starter['status'] = 'subbed_out';
        
        if (subsMade < 5) {
          for (var b in bench) {
            if (b['status'] == 'unused' && b['role'] == starter['role']) {
              var bs = playerStats[b['player_id']];
              double bGrade = bs != null ? (bs['base_grade'] as num).toDouble() : 0.0;
              if (bGrade > 0.0) {
                b['status'] = 'subbed_in';
                subsMade++;
                break; 
              }
            }
          }
        }
      }
    }
  }

  Future<void> _fetchTabellinoData() async {
    try {
      final playersData = await Supabase.instance.client.from('players').select('id, name, role, national_team');
      final statsData = await Supabase.instance.client.from('matchday_stats').select().eq('match_day', widget.matchDay);
      
      Map<int, Map<String, dynamic>> pMap = { for (var p in playersData) p['id']: p };
      playerStats = { for (var s in statsData) s['player_id']: s };

      // 1. Tenta di scaricare la formazione "congelata" per la giornata richiesta
      var roster1 = await Supabase.instance.client.from('storici_formazioni').select().eq('team_id', widget.team1Id).eq('match_day', widget.matchDay);
      var roster2 = await Supabase.instance.client.from('storici_formazioni').select().eq('team_id', widget.team2Id).eq('match_day', widget.matchDay);

      // 2. Se la formazione storica è vuota (es. è la giornata in corso e il timer non è scaduto), usa la formazione live
      if (roster1.isEmpty) {
        roster1 = await Supabase.instance.client.from('roster_players').select().eq('team_id', widget.team1Id);
      }
      if (roster2.isEmpty) {
        roster2 = await Supabase.instance.client.from('roster_players').select().eq('team_id', widget.team2Id);
      }
      List<Map<String, dynamic>> mapRoster(List<dynamic> rosterRows) {
        List<Map<String, dynamic>> list = [];
        for (var row in rosterRows) {
          int pid = row['player_id'];
          if (pMap.containsKey(pid)) {
            list.add({
              'player_id': pid,
              'name': pMap[pid]!['name'],
              'role': pMap[pid]!['role'],
              'national_team': pMap[pid]!['national_team'] ?? '???',
              'is_starter': row['is_starter'] ?? false,
              'is_bench': row['is_bench'] ?? false,
              'is_captain': row['is_captain'] ?? false,
              'bench_order': row['bench_order'] ?? 99,
            });
          }
        }
        
        final roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5};
        
        list.sort((a, b) {
          int roleComparison = roleOrder[a['role']]!.compareTo(roleOrder[b['role']] ?? 99);
          if (roleComparison != 0) return roleComparison;
          return (a['bench_order'] as int).compareTo(b['bench_order'] as int);
        });
        
        return list;
      }

      var fullT1 = mapRoster(roster1);
      var fullT2 = mapRoster(roster2);

      setState(() {
        try { t1Coach = fullT1.firstWhere((p) => p['is_starter'] && p['role'] == 'CT'); } catch(_) { t1Coach = null; }
        try { t2Coach = fullT2.firstWhere((p) => p['is_starter'] && p['role'] == 'CT'); } catch(_) { t2Coach = null; }

        t1Starters = fullT1.where((p) => p['is_starter'] && p['role'] != 'CT').toList();
        t1Bench = fullT1.where((p) => p['is_bench'] && p['role'] != 'CT').toList();
        
        t2Starters = fullT2.where((p) => p['is_starter'] && p['role'] != 'CT').toList();
        t2Bench = fullT2.where((p) => p['is_bench'] && p['role'] != 'CT').toList();

        _simulateSubs(t1Starters, t1Bench);
        _simulateSubs(t2Starters, t2Bench);

        // --- FUNZIONE DI AIUTO PER GOL DALLA PANCHINA ---
        int getBenchGoals(int pId) {
          if (!playerStats.containsKey(pId)) return 0;
          return playerStats[pId]!['goals_scored'] ?? 0;
        }

        // 2. Calcola i totali in tempo reale (Aggiunto calcolo gol panchinari inutilizzati)
        t1Total = 0.0;
        t2Total = 0.0;
        
        if (t1Coach != null) t1Total += _calculatePlayerPerformance(t1Coach!['player_id'], 'CT', false)['fantavoto_num'];
        for(var p in t1Starters) {
          if(p['status'] != 'subbed_out') t1Total += _calculatePlayerPerformance(p['player_id'], p['role'], p['is_captain'] ?? false)['fantavoto_num'];
        }
        for(var p in t1Bench) {
          if(p['status'] == 'subbed_in') {
            t1Total += _calculatePlayerPerformance(p['player_id'], p['role'], false)['fantavoto_num'];
          } else if (p['status'] == 'unused') {
            t1Total += getBenchGoals(p['player_id']) * 1.0; // +1 per ogni gol dalla panchina
          }
        }

        if (t2Coach != null) t2Total += _calculatePlayerPerformance(t2Coach!['player_id'], 'CT', false)['fantavoto_num'];
        for(var p in t2Starters) {
          if(p['status'] != 'subbed_out') t2Total += _calculatePlayerPerformance(p['player_id'], p['role'], p['is_captain'] ?? false)['fantavoto_num'];
        }
        for(var p in t2Bench) {
          if(p['status'] == 'subbed_in') {
            t2Total += _calculatePlayerPerformance(p['player_id'], p['role'], false)['fantavoto_num'];
          } else if (p['status'] == 'unused') {
            t2Total += getBenchGoals(p['player_id']) * 1.0; // +1 per ogni gol dalla panchina
          }
        }
        
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
      setState(() => isLoading = false);
    }
  }

  String _getFlagOnly(String country) {
    final Map<String, String> flags = {
      'Algeria': '🇩🇿', 'Arabia Saudita': '🇸🇦', 'Argentina': '🇦🇷', 'Australia': '🇦🇺',
      'Austria': '🇦🇹', 'Belgio': '🇧🇪', 'Bosnia e Herzegovina': '🇧🇦', 'Brasile': '🇧🇷',
      'Canada': '🇨🇦', 'Capo Verde': '🇨🇻', 'Colombia': '🇨🇴', 'Congo': '🇨🇩', 
      'Congo DR': '🇨🇩', 'Corea': '🇰🇷', 'Costa d\'avorio': '🇨🇮', 'Croazia': '🇭🇷',
      'Curacao': '🇨🇼', 'Curaçao': '🇨🇼', 'Ecuador': '🇪🇨', 'Egitto': '🇪🇬',
      'Francia': '🇫🇷', 'Germania': '🇩🇪', 'Ghana': '🇬🇭', 'Giappone': '🇯🇵',
      'Giordania': '🇯🇴', 'Haiti': '🇭🇹', 'Inghilterra': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'Iran': '🇮🇷',
      'Iraq': '🇮🇶', 'Italia': '🇮🇹', 'Marocco': '🇲🇦', 'Morocco': '🇲🇦',
      'Messico': '🇲🇽', 'Norvegia': '🇳🇴', 'Nuova Zelanda': '🇳🇿', 'Olanda': '🇳🇱',
      'Paesi Bassi': '🇳🇱', 'Panama': '🇵🇦', 'Paraguay': '🇵🇾', 'Portogallo': '🇵🇹',
      'Qatar': '🇶🇦', 'Repubblica Ceca': '🇨🇿', 'Scozia': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'Senegal': '🇸🇳',
      'Spagna': '🇪🇸', 'Sud Africa': '🇿🇦', 'Svezia': '🇸🇪', 'Svizzera': '🇨🇭',
      'Tunisia': '🇹🇳', 'Turchia': '🇹🇷', 'Uruguay': '🇺🇾', 'USA': '🇺🇸',
      'Uzbekistan': '🇺🇿',
    };
    return flags[country.trim()] ?? '🏳️';
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

  Map<String, dynamic> _calculatePlayerPerformance(int playerId, String role, bool isCaptain) {
    if (!playerStats.containsKey(playerId)) {
      return {'voto': '-', 'fantavoto': '-', 'emojis': '', 'fantavoto_num': 0.0};
    }
    
    var s = playerStats[playerId]!;
    
    if (role == 'CT') {
      double coachMod = (s['coach_multiplier'] as num? ?? 0.0).toDouble();
      return {
        'voto': '-',
        'fantavoto': coachMod > 0 ? '+${coachMod.toStringAsFixed(1)}' : coachMod.toStringAsFixed(1),
        'emojis': '👔',
        'fantavoto_num': coachMod,
      };
    }

    double base = (s['base_grade'] as num).toDouble();
    if (base == 0) return {'voto': 's.v.', 'fantavoto': '-', 'emojis': '', 'fantavoto_num': 0.0};

    int gol = s['goals_scored'] ?? 0;
    int assist = s['assists'] ?? 0;
    int yellow = s['yellow_cards'] ?? 0;
    int red = s['red_cards'] ?? 0;
    int own = s['own_goals'] ?? 0;
    int pMissed = s['penalty_missed'] ?? 0;
    int pSaved = s['penalty_saved'] ?? 0;
    int goalsConceded = s['goals_conceded'] ?? 0;
    bool clean = s['clean_sheet'] ?? false;
    bool mom = s['man_of_the_match'] ?? false;

    double fv = base + (gol * 3) + (assist * 1) - (yellow * 0.5) - (red * 1) - (own * 2) - (pMissed * 3);
    if (role == 'P') {
      fv += (pSaved * 3);
      fv -= (goalsConceded * 1.0);
      if (clean) fv += 1;
    }
    
    if (mom) fv += 0.5;
    if (isCaptain && gol > 0) fv += (0.5 * gol);

    String emojis = '';
    if (gol > 0) emojis += '⚽' * gol;
    if (assist > 0) emojis += '👟' * assist;
    if (yellow > 0) emojis += '🟨';
    if (red > 0) emojis += '🟥';
    if (own > 0) emojis += '🤦‍♂️' * own;
    if (pMissed > 0) emojis += '❌' * pMissed;
    if (goalsConceded > 0 && role == 'P') emojis += '🥅' * goalsConceded;
    if (pSaved > 0) emojis += '🧤' * pSaved;
    if (clean && role == 'P') emojis += '🛡️';
    if (mom) emojis += '🌟';

    return {
      'voto': base.toStringAsFixed(1),
      'fantavoto': fv.toStringAsFixed(1),
      'emojis': emojis,
      'fantavoto_num': fv,
    };
  }

  Widget _buildCaptainBadge() {
    return Container(
      width: 15,
      height: 15,
      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
      child: const Center(child: Text('C', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold))),
    );
  }

  // --- GRAFICA EMOJI E BADGE INTEGRATA NEI LATI PER EVITARE DISALLINEAMENTI ---
  Widget _buildPlayerSide(Map<String, dynamic>? player, bool isLeft) {
    if (player == null) return const Expanded(child: SizedBox.shrink());

    double opacityLevel = 1.0;
    String subIcon = '';
    
    if (player['status'] == 'subbed_out') {
      opacityLevel = 0.4;
      subIcon = '🔻 ';
    } else if (player['status'] == 'subbed_in') {
      opacityLevel = 1.0;
      subIcon = '🔼 ';
    } else if (player['status'] == 'unused') {
      opacityLevel = 0.4;
    }

    bool isCaptain = player['is_captain'] ?? false;
    var perf = _calculatePlayerPerformance(player['player_id'], player['role'], isCaptain);
    String emojis = perf['emojis'];

    // Box Nome Giocatore + Ruolo
    List<Widget> playerInfo = [
      CircleAvatar(radius: 12, backgroundColor: _getRoleColor(player['role']), child: Text(player['role'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$subIcon${player['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87), overflow: TextOverflow.ellipsis),
            Text('${player['national_team']} ${_getFlagOnly(player['national_team'])}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    ];

    // Box Emoji e Capitano (Spinti verso il centro ma appartenenti alle espansioni laterali)
    Widget addons = Row(
      mainAxisSize: MainAxisSize.min,
      children: isLeft 
        ? [
            if (isCaptain) Padding(padding: const EdgeInsets.only(left: 4), child: _buildCaptainBadge()),
            if (emojis.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4, right: 4), child: Text(emojis, style: const TextStyle(fontSize: 11))),
          ]
        : [
            if (emojis.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 4, left: 4), child: Text(emojis, style: const TextStyle(fontSize: 11))),
            if (isCaptain) Padding(padding: const EdgeInsets.only(right: 4), child: _buildCaptainBadge()),
          ],
    );

    return Expanded(
      child: Opacity(
        opacity: opacityLevel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: isLeft
                ? [...playerInfo, addons]
                : [addons, ...playerInfo.reversed.toList()],
          ),
        ),
      ),
    );
  }

  // --- CENTRO PERFETTAMENTE ALLINEATO CON LARGHEZZA FISSA ---
  Widget _buildCenterGrades(Map<String, dynamic>? p1, Map<String, dynamic>? p2) {
    bool isCaptain1 = p1 != null && (p1['is_captain'] ?? false);
    bool isCaptain2 = p2 != null && (p2['is_captain'] ?? false);

    var perf1 = p1 != null ? _calculatePlayerPerformance(p1['player_id'], p1['role'], isCaptain1) : {'voto': '-', 'fantavoto': '-'};
    var perf2 = p2 != null ? _calculatePlayerPerformance(p2['player_id'], p2['role'], isCaptain2) : {'voto': '-', 'fantavoto': '-'};

    Widget gradeBox(String base, String fv, bool isLeft) {
      return Container(
        width: 35, // Larghezza fissa che impedisce slittamenti
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: isLeft ? const BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6)) : const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(base, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(fv, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[900])),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        gradeBox(perf1['voto']!, perf1['fantavoto']!, true),
        gradeBox(perf2['voto']!, perf2['fantavoto']!, false),
      ],
    );
  }

  Widget _buildMatchRow(Map<String, dynamic>? p1, Map<String, dynamic>? p2) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          _buildPlayerSide(p1, true),
          _buildCenterGrades(p1, p2),
          _buildPlayerSide(p2, false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int maxStarters = [t1Starters.length, t2Starters.length].reduce((a, b) => a > b ? a : b);
    int maxBench = [t1Bench.length, t2Bench.length].reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage('assets/sfondo.png'), fit: BoxFit.cover),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Tabellino Partita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange[800]?.withValues(alpha: 0.9),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    color: Colors.orange[900]?.withValues(alpha: 0.9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: Text(widget.team1Name, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Text('${widget.score1} : ${widget.score2}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${t1Total.toStringAsFixed(1)} pt  -  ${t2Total.toStringAsFixed(1)} pt', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(child: Text(widget.team2Name, textAlign: TextAlign.left, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (t1Coach != null || t2Coach != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: Text('ALLENATORI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))),
                          ),
                          _buildMatchRow(t1Coach, t2Coach),
                          const SizedBox(height: 8),
                        ],

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: Text('TITOLARI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))),
                        ),
                        
                        if (maxStarters == 0)
                          const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Nessuna formazione schierata', style: TextStyle(color: Colors.white70)))),

                        for (int i = 0; i < maxStarters; i++)
                          _buildMatchRow(
                            i < t1Starters.length ? t1Starters[i] : null,
                            i < t2Starters.length ? t2Starters[i] : null,
                          ),

                        if (maxBench > 0) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 8),
                            child: Center(child: Text('PANCHINA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))),
                          ),
                          for (int i = 0; i < maxBench; i++)
                            _buildMatchRow(
                              i < t1Bench.length ? t1Bench[i] : null,
                              i < t2Bench.length ? t2Bench[i] : null,
                            ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}