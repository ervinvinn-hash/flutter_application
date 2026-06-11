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

  @override
  void initState() {
    super.initState();
    _fetchTabellinoData();
  }

  Future<void> _fetchTabellinoData() async {
    try {
      final playersData = await Supabase.instance.client.from('players').select('id, name, role, national_team'); //
      final statsData = await Supabase.instance.client.from('matchday_stats').select().eq('match_day', widget.matchDay); //
      
      Map<int, Map<String, dynamic>> pMap = { for (var p in playersData) p['id']: p }; //
      playerStats = { for (var s in statsData) s['player_id']: s }; //

      final roster1 = await Supabase.instance.client.from('roster_players').select().eq('team_id', widget.team1Id); //
      final roster2 = await Supabase.instance.client.from('roster_players').select().eq('team_id', widget.team2Id); //

      List<Map<String, dynamic>> mapRoster(List<dynamic> rosterRows) {
        List<Map<String, dynamic>> list = []; //
        for (var row in rosterRows) { //
          int pid = row['player_id']; //
          if (pMap.containsKey(pid)) { //
            list.add({
              'player_id': pid, //
              'name': pMap[pid]!['name'], //
              'role': pMap[pid]!['role'], //
              'national_team': pMap[pid]!['national_team'] ?? '???', //
              'is_starter': row['is_starter'] ?? false, //
              'is_bench': row['is_bench'] ?? false, //
              'is_captain': row['is_captain'] ?? false, //
            });
          }
        }
        final roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5}; //
        list.sort((a, b) => roleOrder[a['role']]!.compareTo(roleOrder[b['role']] ?? 99)); //
        return list; //
      }

      var fullT1 = mapRoster(roster1); //
      var fullT2 = mapRoster(roster2); //

      setState(() {
        try { t1Coach = fullT1.firstWhere((p) => p['is_starter'] && p['role'] == 'CT'); } catch(_) { t1Coach = null; } //
        try { t2Coach = fullT2.firstWhere((p) => p['is_starter'] && p['role'] == 'CT'); } catch(_) { t2Coach = null; } //

        t1Starters = fullT1.where((p) => p['is_starter'] && p['role'] != 'CT').toList(); //
        t1Bench = fullT1.where((p) => p['is_bench'] && p['role'] != 'CT').toList(); //
        
        t2Starters = fullT2.where((p) => p['is_starter'] && p['role'] != 'CT').toList(); //
        t2Bench = fullT2.where((p) => p['is_bench'] && p['role'] != 'CT').toList(); //
        
        isLoading = false; //
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e'))); //
      setState(() => isLoading = false); //
    }
  }

  String _getFlagOnly(String country) { //
    if (country.isEmpty || country == '???') return '🏳️'; //
    final String cleanCountry = country.trim().toLowerCase().replaceAll('’', '\'').replaceAll('`', '\''); //

    if (cleanCountry.contains('usa') || cleanCountry.contains('stati uniti')) return '🇺🇸'; //
    if (cleanCountry.contains('avorio')) return '🇨🇮'; //

    final Map<String, String> flags = {
      'algeria': '🇩🇿', 'arabia saudita': '🇸🇦', 'argentina': '🇦🇷', 'australia': '🇦🇺', //
      'austria': '🇦🇹', 'belgio': '🇧🇪', 'bosnia e herzegovina': '🇧🇦', 'bosnia': '🇧🇦', //
      'brasile': '🇧🇷', 'canada': '🇨🇦', 'capo verde': '🇨🇻', 'colombia': '🇨🇴', //
      'congo': '🇨🇩', 'congo dr': '🇨🇩', 'corea': '🇰🇷', 'corea del sud': '🇰🇷', //
      'croazia': '🇭🇷', 'curacao': '🇨🇼', 'curaçao': '🇨🇼', 'ecuador': '🇪🇨', //
      'egitto': '🇪🇬', 'francia': '🇫🇷', 'germania': '🇩🇪', 'ghana': '🇬🇭', //
      'giappone': '🇯🇵', 'giordania': '🇯🇴', 'haiti': '🇭🇹', 'inghilterra': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', //
      'iran': '🇮🇷', 'iraq': '🇮🇶', 'italia': '🇮🇹', 'marocco': '🇲🇦', 'morocco': '🇲🇦', //
      'messico': '🇲🇽', 'norvegia': '🇳🇴', 'nuova zelanda': '🇳🇿', 'olanda': '🇳🇱', //
      'paesi bassi': '🇳🇱', 'panama': '🇵🇦', 'paraguay': '🇵🇾', 'portogallo': '🇵🇹', //
      'qatar': '🇶🇦', 'repubblica ceca': '🇨🇿', 'scozia': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'senegal': '🇸🇳', //
      'spagna': '🇪🇸', 'sud africa': '🇿🇦', 'svezia': '🇸🇪', 'svizzera': '🇨🇭', //
      'tunisia': '🇹🇳', 'turchia': '🇹🇷', 'uruguay': '🇺🇾', 'uzbekistan': '🇺🇿', //
    };
    return flags[cleanCountry] ?? '🏳️'; //
  }

  Color _getRoleColor(String role) { //
    switch (role) { //
      case 'P': return Colors.orange; //
      case 'D': return Colors.green[700]!; //
      case 'C': return Colors.blue[700]!; //
      case 'A': return Colors.red[700]!; //
      case 'CT': return Colors.black87; //
      default: return Colors.grey; //
    }
  }

  Map<String, dynamic> _calculatePlayerPerformance(int playerId, String role) { //
    if (!playerStats.containsKey(playerId)) { //
      return {'voto': '-', 'fantavoto': '-', 'emojis': ''}; //
    }
    
    var s = playerStats[playerId]!; //
    double base = (s['base_grade'] as num).toDouble(); //
    if (base == 0) return {'voto': 's.v.', 'fantavoto': '-', 'emojis': ''}; //

    if (role == 'CT') { //
      double coachMod = (s['coach_multiplier'] as num? ?? 0.0).toDouble(); //
      return {
        'voto': base.toStringAsFixed(1), //
        'fantavoto': coachMod >= 0 ? '+$coachMod' : '$coachMod', //
        'emojis': '👔', //
      };
    }

    int gol = s['goals_scored'] ?? 0; //
    int assist = s['assists'] ?? 0; //
    int yellow = s['yellow_cards'] ?? 0; //
    int red = s['red_cards'] ?? 0; //
    int own = s['own_goals'] ?? 0; //
    int pMissed = s['penalty_missed'] ?? 0; //
    int pSaved = s['penalty_saved'] ?? 0; //
    bool clean = s['clean_sheet'] ?? false; //

    double fv = base + (gol * 3) + (assist * 1) - (yellow * 0.5) - (red * 1) - (own * 2) - (pMissed * 3); //
    if (role == 'P') { //
      fv += (pSaved * 3); //
      if (clean) fv += 1; //
    } //

    String emojis = ''; //
    if (gol > 0) emojis += '⚽' * gol; //
    if (assist > 0) emojis += '👟' * assist; //
    if (yellow > 0) emojis += '🟨'; //
    if (red > 0) emojis += '🟥'; //
    if (own > 0) emojis += '🤦‍♂️' * own; //
    if (pMissed > 0) emojis += '❌' * pMissed; //
    if (pSaved > 0) emojis += '🧤' * pSaved; //
    if (clean && role == 'P') emojis += '🛡️'; //

    return {
      'voto': base.toStringAsFixed(1), //
      'fantavoto': fv.toStringAsFixed(1), //
      'emojis': emojis, //
    };
  }

  // --- IL BOLLINO GIALLO CON LA C NERA ---
  Widget _buildCaptainBadge() {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.amber, // Giallo fascia
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'C',
          style: TextStyle(
            color: Colors.black, // C Nera
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- WIDGET RIGA SINGOLO GIOCATORE LATERALE ---
  Widget _buildPlayerSide(Map<String, dynamic>? player, bool isLeft) {
    if (player == null) return const Expanded(child: SizedBox.shrink()); //

    List<Widget> content = [
      CircleAvatar(radius: 12, backgroundColor: _getRoleColor(player['role']), child: Text(player['role'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), //
      const SizedBox(width: 8), //
      Expanded(
        child: Column(
          crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end, //
          mainAxisAlignment: MainAxisAlignment.center, //
          children: [
            // IL NOME ORA TORNA PULITO SENZA COMPOSIZIONI STRANE
            Text(player['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87), overflow: TextOverflow.ellipsis), //
            Text('${player['national_team']} ${_getFlagOnly(player['national_team'])}', style: const TextStyle(fontSize: 10, color: Colors.black54)), //
          ],
        ),
      ),
    ];

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4), //
        child: Row(
          mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end, //
          children: isLeft ? content : content.reversed.toList(), //
        ),
      ),
    );
  }

  // --- WIDGET BLOCCO CENTRALE VOTI (CON I BADGE CAPITANO E BONUS AFFIANCATI) ---
  Widget _buildCenterGrades(Map<String, dynamic>? p1, Map<String, dynamic>? p2) {
    var perf1 = p1 != null ? _calculatePlayerPerformance(p1['player_id'], p1['role']) : {'voto': '-', 'fantavoto': '-', 'emojis': ''};
    var perf2 = p2 != null ? _calculatePlayerPerformance(p2['player_id'], p2['role']) : {'voto': '-', 'fantavoto': '-', 'emojis': ''};

    bool isCaptain1 = p1 != null && (p1['is_captain'] ?? false);
    bool isCaptain2 = p2 != null && (p2['is_captain'] ?? false);

    Widget gradeBox(String base, String fv, bool isLeft) {
      return Container(
        width: 35, //
        decoration: BoxDecoration(
          color: Colors.white, //
          border: Border.all(color: Colors.grey[300]!), //
          borderRadius: isLeft ? const BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6)) : const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)), //
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, //
          children: [
            Container(
              width: double.infinity, //
              color: Colors.grey[200], //
              padding: const EdgeInsets.symmetric(vertical: 2), //
              child: Text(base, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)), //
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4), //
              child: Text(fv, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[900])), //
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min, //
      children: [
        // --- SEZIONE SINISTRA (SQUADRA 1) ---
        // Se è capitano, posiziona il bollino giallo prima dei badge emoji (quindi a sinistra dei voti)
        if (isCaptain1) _buildCaptainBadge(),
        if (perf1['emojis'] != '') Text(perf1['emojis'], style: const TextStyle(fontSize: 11)),
        
        // I DUE VOTI AL CENTRO RIGIDI
        gradeBox(perf1['voto'], perf1['fantavoto'], true), //
        gradeBox(perf2['voto'], perf2['fantavoto'], false), //
        
        // --- SEZIONE DESTRA (SQUADRA 2) ---
        if (perf2['emojis'] != '') Text(perf2['emojis'], style: const TextStyle(fontSize: 11)),
        // Se è capitano, posiziona il bollino subito dopo le emoji (quindi a destra dei voti)
        if (isCaptain2) _buildCaptainBadge(),
      ],
    );
  }

  // --- WIDGET RIGA COMPLETA (T1 vs T2) ---
  Widget _buildMatchRow(Map<String, dynamic>? p1, Map<String, dynamic>? p2) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), //
      padding: const EdgeInsets.symmetric(vertical: 8), //
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85), //
        borderRadius: BorderRadius.circular(12), //
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)], //
      ),
      child: Row(
        children: [
          _buildPlayerSide(p1, true), //
          _buildCenterGrades(p1, p2), // Gestisce voti, capitani ed emoji tutti allineati al centro
          _buildPlayerSide(p2, false), //
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int maxStarters = [t1Starters.length, t2Starters.length].reduce((a, b) => a > b ? a : b); //
    int maxBench = [t1Bench.length, t2Bench.length].reduce((a, b) => a > b ? a : b); //

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/sfondo.png'), //
          fit: BoxFit.cover, //
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, //
        appBar: AppBar(
          title: const Text('Tabellino Partita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), //
          backgroundColor: Colors.orange[800]?.withValues(alpha: 0.9), //
          elevation: 0, //
          iconTheme: const IconThemeData(color: Colors.white), //
        ),
        body: isLoading //
            ? const Center(child: CircularProgressIndicator(color: Colors.orange)) //
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16), //
                    color: Colors.orange[900]?.withValues(alpha: 0.9), //
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, //
                      children: [
                        Expanded(child: Text(widget.team1Name, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))), //
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16), //
                          child: Text('${widget.score1} : ${widget.score2}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), //
                        ),
                        Expanded(child: Text(widget.team2Name, textAlign: TextAlign.left, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))), //
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8), //
                      children: [
                        if (t1Coach != null || t2Coach != null) ...[ //
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8), //
                            child: Center(child: Text('ALLENATORI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))), //
                          ),
                          _buildMatchRow(t1Coach, t2Coach), //
                          const SizedBox(height: 8), //
                        ],

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8), //
                          child: Center(child: Text('TITOLARI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))), //
                        ),
                        
                        if (maxStarters == 0) //
                          const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Nessuna formazione schierata', style: TextStyle(color: Colors.white70)))), //

                        for (int i = 0; i < maxStarters; i++) //
                          _buildMatchRow( //
                            i < t1Starters.length ? t1Starters[i] : null, //
                            i < t2Starters.length ? t2Starters[i] : null, //
                          ), //

                        if (maxBench > 0) ...[ //
                          const Padding( //
                            padding: EdgeInsets.only(top: 16, bottom: 8), //
                            child: Center(child: Text('PANCHINA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))), //
                          ), //
                          for (int i = 0; i < maxBench; i++) //
                            _buildMatchRow( //
                              i < t1Bench.length ? t1Bench[i] : null, //
                              i < t2Bench.length ? t2Bench[i] : null, //
                            ), //
                        ] //
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
