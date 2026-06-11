import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamLineupScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamLineupScreen({super.key, required this.teamId, required this.teamName});

  @override
  State<TeamLineupScreen> createState() => _TeamLineupScreenState();
}

class _TeamLineupScreenState extends State<TeamLineupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  bool isSaving = false;
  
  List<Map<String, dynamic>> roster = [];

  final List<String> validFormations = ['3-5-2', '3-4-3', '3-3-4', '4-5-1', '4-4-2', '4-3-3', '4-2-4', '5-4-1', '5-3-2', '5-2-3'];
  String currentFormation = '3-4-3';
  
  List<Map<String, dynamic>?> fieldD = [null, null, null];
  List<Map<String, dynamic>?> fieldC = [null, null, null, null];
  List<Map<String, dynamic>?> fieldA = [null, null, null];
  Map<String, dynamic>? fieldP;
  Map<String, dynamic>? fieldCoach;

  final List<String> benchRoles = ['P', 'D', 'D', 'C', 'C', 'A', 'A'];
  List<Map<String, dynamic>?> benchPlayers = List.filled(7, null);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchRoster();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoster() async {
    try {
      final client = Supabase.instance.client;
      final rosterData = await client.from('roster_players').select().eq('team_id', widget.teamId);
      final playersData = await client.from('players').select('id, name, role, national_team');
      
      // --- IL NUOVO MOTORE DEL CALENDARIO ---
      final matchesData = await client.from('world_cup_matches').select().order('kickoff_time', ascending: true);
      
      int currentMatchday = 1;
      final now = DateTime.now();
      
      try {
        var upcomingMatch = matchesData.firstWhere((m) {
          DateTime kickoff = DateTime.parse(m['kickoff_time']);
          return kickoff.add(const Duration(hours: 2)).isAfter(now);
        });
        currentMatchday = upcomingMatch['matchday'];
      } catch (e) {
        if (matchesData.isNotEmpty) currentMatchday = matchesData.last['matchday'];
      }

      Map<String, String> teamMatches = {};
      for (var m in matchesData) {
        if (m['matchday'] == currentMatchday) {
          String home = m['home_team'];
          String away = m['away_team'];
          
          String siglaHome = home.length >= 3 ? home.substring(0, 3).toUpperCase() : home.toUpperCase();
          String siglaAway = away.length >= 3 ? away.substring(0, 3).toUpperCase() : away.toUpperCase();
          String matchString = '$siglaHome - $siglaAway';
          
          teamMatches[home] = matchString;
          teamMatches[away] = matchString;
        }
      }
      
      // --- NUOVO: RECUPERO E CALCOLO STATISTICHE REALI ---
      // Estrapoliamo gli ID dei giocatori in rosa per scaricare solo i loro voti
      List<int> rosterIds = rosterData.map<int>((r) => r['player_id'] as int).toList();
      
      List<dynamic> statsData = [];
      if (rosterIds.isNotEmpty) {
        statsData = await client.from('matchday_stats').select().inFilter('player_id', rosterIds);
      }

      // Dizionario per accumulare le statistiche: playerId -> {statistiche aggregate}
      Map<int, Map<String, dynamic>> aggregatedStats = {
        for (var id in rosterIds)
          id: { 'apps': 0, 'goals': 0, 'assists': 0, 'yellows': 0, 'reds': 0, 'sum_mv': 0.0, 'sum_fm': 0.0 }
      };

      for (var stat in statsData) {
        int pId = stat['player_id'];
        if (aggregatedStats.containsKey(pId)) {
          var ag = aggregatedStats[pId]!;
          ag['apps'] += 1;
          ag['goals'] += stat['goals_scored'] ?? 0;
          ag['assists'] += stat['assists'] ?? 0;
          ag['yellows'] += stat['yellow_cards'] ?? 0;
          ag['reds'] += stat['red_cards'] ?? 0;

          double mv = (stat['base_grade'] as num).toDouble();
          ag['sum_mv'] += mv;

          // Calcolo FantaVoto Dinamico con Bonus/Malus
          double fm = mv;
          fm += (stat['goals_scored'] ?? 0) * 3.0;
          fm += (stat['assists'] ?? 0) * 1.0;
          fm -= (stat['yellow_cards'] ?? 0) * 0.5;
          fm -= (stat['red_cards'] ?? 0) * 1.0;
          fm -= (stat['own_goals'] ?? 0) * 2.0;
          fm += (stat['penalty_saved'] ?? 0) * 3.0;
          fm -= (stat['penalty_missed'] ?? 0) * 3.0;
          if (stat['clean_sheet'] == true) fm += 1.0; // Bonus porta inviolata
          
          ag['sum_fm'] += fm;
        }
      }
      // ---------------------------------------------------

      Map<int, Map<String, dynamic>> playersMap = { for (var p in playersData) p['id']: p };

      List<Map<String, dynamic>> loadedRoster = [];
      for (var row in rosterData) {
        int pId = row['player_id'];
        if (playersMap.containsKey(pId)) {
          String nTeam = playersMap[pId]!['national_team'] ?? '???';
          
          // Estrapoliamo i calcoli finali per questo giocatore
          var ag = aggregatedStats[pId]!;
          int apps = ag['apps'];
          double mediaVoto = apps > 0 ? ag['sum_mv'] / apps : 0.0;
          double fantaMedia = apps > 0 ? ag['sum_fm'] / apps : 0.0;
          
          loadedRoster.add({
            'player_id': pId,
            'name': playersMap[pId]!['name'],
            'role': playersMap[pId]!['role'],
            'national_team': nTeam,
            'is_starter': row['is_starter'] ?? false,
            'is_bench': row['is_bench'] ?? false,
            'is_captain': row['is_captain'] ?? false,
            'match': teamMatches[nTeam] ?? 'Riposo', 
            
            // ASSEGNAZIONE DELLE STATISTICHE REALI!
            'apps': apps, 
            'goals': ag['goals'], 
            'assists': ag['assists'], 
            'yellows': ag['yellows'], 
            'reds': ag['reds'], 
            'mv': mediaVoto, 
            'fm': fantaMedia,
          });
        }
      }

      List<Map<String, dynamic>> sD = loadedRoster.where((p) => p['is_starter'] && p['role'] == 'D').toList();
      List<Map<String, dynamic>> sC = loadedRoster.where((p) => p['is_starter'] && p['role'] == 'C').toList();
      List<Map<String, dynamic>> sA = loadedRoster.where((p) => p['is_starter'] && p['role'] == 'A').toList();
      
      String inferredForm = '${sD.length}-${sC.length}-${sA.length}';
      if (!validFormations.contains(inferredForm)) inferredForm = '3-4-3';
      
      currentFormation = inferredForm;
      int rD = int.parse(currentFormation[0]);
      int rC = int.parse(currentFormation[2]);
      int rA = int.parse(currentFormation[4]);

      fieldD = List.generate(rD, (i) => i < sD.length ? sD[i] : null);
      fieldC = List.generate(rC, (i) => i < sC.length ? sC[i] : null);
      fieldA = List.generate(rA, (i) => i < sA.length ? sA[i] : null);
      
      try { fieldP = loadedRoster.firstWhere((p) => p['is_starter'] && p['role'] == 'P'); } catch(e) { fieldP = null; }
      try { fieldCoach = loadedRoster.firstWhere((p) => p['is_starter'] && p['role'] == 'CT'); } catch(e) { fieldCoach = null; }

      List<Map<String, dynamic>> bP = loadedRoster.where((p) => p['is_bench']).toList();
      benchPlayers = List.filled(7, null);
      for (int i = 0; i < 7; i++) {
        int idx = bP.indexWhere((p) => p['role'] == benchRoles[i] && !benchPlayers.contains(p));
        if (idx != -1) benchPlayers[i] = bP[idx];
      }

      setState(() {
        roster = loadedRoster;
        isLoading = false;
        _syncRosterState();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  void _syncRosterState() {
    for (var p in roster) {
      p['is_starter'] = false;
      p['is_bench'] = false;
    }

    void setStarter(Map<String, dynamic>? p) { if (p != null) p['is_starter'] = true; }
    void setBench(Map<String, dynamic>? p) { if (p != null) p['is_bench'] = true; }

    fieldD.forEach(setStarter);
    fieldC.forEach(setStarter);
    fieldA.forEach(setStarter);
    setStarter(fieldP);
    setStarter(fieldCoach);
    benchPlayers.forEach(setBench);

    for (var p in roster) {
      if (p['is_captain'] == true && p['is_starter'] == false) {
        p['is_captain'] = false;
      }
    }
  }

  void _changeFormation(String newFormation) {
    setState(() {
      currentFormation = newFormation;
      int reqD = int.parse(newFormation[0]);
      int reqC = int.parse(newFormation[2]);
      int reqA = int.parse(newFormation[4]);

      fieldD = _adjustList(fieldD, reqD);
      fieldC = _adjustList(fieldC, reqC);
      fieldA = _adjustList(fieldA, reqA);
      _syncRosterState();
    });
  }

  List<Map<String, dynamic>?> _adjustList(List<Map<String, dynamic>?> list, int newSize) {
    if (list.length == newSize) return list;
    if (list.length > newSize) return list.sublist(0, newSize);
    List<Map<String, dynamic>?> newList = List.from(list);
    while (newList.length < newSize) { newList.add(null); }
    return newList;
  }

  List<Map<String, dynamic>> _getAvailablePlayers(String role) {
    return roster.where((p) => p['role'] == role && !p['is_starter'] && !p['is_bench']).toList();
  }

  Future<void> _saveLineup({bool forceSave = false}) async {
    _syncRosterState();
    int starters = roster.where((p) => p['is_starter'] && p['role'] != 'CT').length;
    bool hasCaptain = roster.any((p) => p['is_starter'] && p['is_captain'] == true && p['role'] != 'CT');

    if (!forceSave) {
      if (starters != 11) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Devi riempire gli 11 slot sul campo! (Ora: $starters)'), backgroundColor: Colors.orange[800]));
        return;
      }
      if (!hasCaptain) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Manca il Capitano! Tieni premuto su un giocatore per assegnarlo.'), backgroundColor: Colors.orange[800]));
        return;
      }
    }

    setState(() => isSaving = true);
    try {
      final client = Supabase.instance.client;
      for (var p in roster) {
        await client.from('roster_players').update({
          'is_starter': p['is_starter'],
          'is_bench': p['is_bench'],
          'is_captain': p['is_captain'] ?? false,
        }).eq('team_id', widget.teamId).eq('player_id', p['player_id']);
      }
      
      String msg = forceSave ? 'Bozza salvata con successo! 📝' : 'Formazione inviata! 🚀';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isSaving = false);
    }
  }

  void _copyLineupToClipboard() {
    _syncRosterState();
    StringBuffer sb = StringBuffer();
    
    sb.writeln(widget.teamName);
    sb.writeln('Allenatore:');
    
    if (fieldCoach != null) {
      sb.writeln('ALL - ${fieldCoach!['name']} (${fieldCoach!['national_team']})');
    } else {
      sb.writeln('ALL - Nessun Allenatore');
    }

    sb.writeln('Titolari:');
    final roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5};
    List<Map<String, dynamic>> titolari = roster.where((p) => p['is_starter'] && p['role'] != 'CT').toList();
    titolari.sort((a, b) => roleOrder[a['role']]!.compareTo(roleOrder[b['role']]!));
    
    for (var p in titolari) {
      String capTag = p['is_captain'] ? ' [C]' : '';
      sb.writeln('${p['role']} - ${p['name']} (${p['national_team']})$capTag');
    }

    sb.writeln('Panchina:');
    for (var p in benchPlayers) {
      if (p != null) {
        sb.writeln('${p['role']} - ${p['name']} (${p['national_team']})');
      }
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Formazione copiata negli appunti! 📋'), backgroundColor: Colors.orange[800]));
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'P': return Colors.orange;
      case 'D': return Colors.green[800]!;
      case 'C': return Colors.blue[800]!;
      case 'A': return Colors.red[800]!;
      case 'CT': return Colors.black87;
      default: return Colors.grey;
    }
  }

  String _getFlagOnly(String country) {
    if (country.isEmpty || country == '???') return '🏳️';
    final String cleanCountry = country.trim().toLowerCase().replaceAll('’', '\'').replaceAll('`', '\''); 

    if (cleanCountry.contains('usa') || cleanCountry.contains('stati uniti')) return '🇺🇸';
    if (cleanCountry.contains('avorio')) return '🇨🇮';

    final Map<String, String> flags = {
      'algeria': '🇩🇿', 'arabia saudita': '🇸🇦', 'argentina': '🇦🇷', 'australia': '🇦🇺',
      'austria': '🇦🇹', 'belgio': '🇧🇪', 'bosnia e herzegovina': '🇧🇦', 'bosnia': '🇧🇦',
      'brasile': '🇧🇷', 'canada': '🇨🇦', 'capo verde': '🇨🇻', 'colombia': '🇨🇴', 
      'congo': '🇨🇩', 'congo dr': '🇨🇩', 'corea': '🇰🇷', 'corea del sud': '🇰🇷', 
      'croazia': '🇭🇷', 'curacao': '🇨🇼', 'curaçao': '🇨🇼', 'ecuador': '🇪🇨', 
      'egitto': '🇪🇬', 'francia': '🇫🇷', 'germania': '🇩🇪', 'ghana': '🇬🇭', 
      'giappone': '🇯🇵', 'giordania': '🇯🇴', 'haiti': '🇭🇹', 'inghilterra': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 
      'iran': '🇮🇷', 'iraq': '🇮🇶', 'italia': '🇮🇹', 'marocco': '🇲🇦', 'morocco': '🇲🇦', 
      'messico': '🇲🇽', 'norvegia': '🇳🇴', 'nuova zelanda': '🇳🇿', 'olanda': '🇳🇱', 
      'paesi bassi': '🇳🇱', 'panama': '🇵🇦', 'paraguay': '🇵🇾', 'portogallo': '🇵🇹', 
      'qatar': '🇶🇦', 'repubblica ceca': '🇨🇿', 'scozia': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'senegal': '🇸🇳', 
      'spagna': '🇪🇸', 'sud africa': '🇿🇦', 'svezia': '🇸🇪', 'svizzera': '🇨🇭', 
      'tunisia': '🇹🇳', 'turchia': '🇹🇷', 'uruguay': '🇺🇾', 'uzbekistan': '🇺🇿',
    };

    return flags[cleanCountry] ?? '🏳️';
  }

  void _showPlayerSelectionDialog(String role, Function(Map<String, dynamic>?) onSelected) {
    List<Map<String, dynamic>> available = _getAvailablePlayers(role);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white.withValues(alpha: 0.95), 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Seleziona ($role)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Divider(),
              if (available.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Text('Nessun giocatore disponibile in questo ruolo.', style: TextStyle(color: Colors.grey)))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (ctx, i) {
                      final p = available[i];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: _getRoleColor(p['role']), child: Text(p['role'], style: const TextStyle(color: Colors.white, fontSize: 12))),
                        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p['national_team']} ${_getFlagOnly(p['national_team'])}'),
                        trailing: Icon(Icons.add_circle, color: Colors.orange[800]),
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(p);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlot(String role, Map<String, dynamic>? player, Function(Map<String, dynamic>?) onUpdate) {
    bool isEmpty = player == null;

    return GestureDetector(
      onTap: () => _showPlayerSelectionDialog(role, (p) {
        setState(() { onUpdate(p); _syncRosterState(); });
      }),
      onDoubleTap: () => setState(() { onUpdate(null); _syncRosterState(); }),
      onLongPress: () {
        if (!isEmpty && role != 'CT') { 
          setState(() {
            if (player['is_captain'] == true) {
              player['is_captain'] = false;
            } else {
              for (var r in roster) { r['is_captain'] = false; }
              player['is_captain'] = true;
            }
          });
        }
      },
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isEmpty ? Colors.black.withValues(alpha: 0.5) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _getRoleColor(role), width: 2.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Center(
                    child: isEmpty 
                        ? const Icon(Icons.add, color: Colors.white70, size: 20)
                        : Text(_getFlagOnly(player['national_team']), style: const TextStyle(fontSize: 20)),
                  ),
                ),
                if (!isEmpty && player['is_captain'])
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      child: const Icon(Icons.star, size: 12, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95), 
                borderRadius: BorderRadius.circular(6), 
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2)]
              ),
              child: isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('Vuoto', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          player['name'],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          player['match'] ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 8, color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowOfSlots(List<Map<String, dynamic>?> list, String role, Function(int, Map<String, dynamic>?) onUpdate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(list.length, (index) => _buildSlot(role, list[index], (p) => onUpdate(index, p))),
    );
  }

  Widget _buildTabCampo() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/foto_campo.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          colorFilter: ColorFilter.mode(Colors.black26, BlendMode.darken),
        ),
      ),
      child: Column(
        children: [
          // IL CAMPO E I TITOLARI
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 40.0, left: 40.0, right: 40.0, bottom: 0.0),
                  child: _buildRowOfSlots(fieldA, 'A', (i, p) => fieldA[i] = p),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 0.0, left: 40.0, right: 40.0, bottom: 0.0),
                  child: _buildRowOfSlots(fieldC, 'C', (i, p) => fieldC[i] = p),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, left: 40.0, right: 40.0, bottom: 0.0),
                  child: _buildRowOfSlots(fieldD, 'D', (i, p) => fieldD[i] = p),
                ),
                Row(
                  children: [
                    Expanded(child: Container()),
                    _buildSlot('P', fieldP, (p) => fieldP = p),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 40.0),
                          child: _buildSlot('CT', fieldCoach, (p) => fieldCoach = p),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // LA PANCHINA
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2), 
                  blurRadius: 8, 
                  offset: const Offset(0, 4)
                )
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false, // Parte chiusa di default per preservare spazio
                iconColor: Colors.orange[800],
                collapsedIconColor: Colors.black54,
                title: const Row(
                  children: [
                    Icon(Icons.airline_seat_recline_normal, color: Colors.black54, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'PANCHINA', 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    child: Column(
                      children: [
                        const Divider(height: 1, thickness: 1),
                        const SizedBox(height: 12),
                        // Prima riga panchina (Primi 5 slot)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (index) {
                            return _buildSlot(benchRoles[index], benchPlayers[index], (p) => benchPlayers[index] = p);
                          }),
                        ),
                        const SizedBox(height: 12),
                        // Seconda riga panchina (Ultimi 2 slot centrate)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSlot(benchRoles[5], benchPlayers[5], (p) => benchPlayers[5] = p),
                            const SizedBox(width: 32),
                            _buildSlot(benchRoles[6], benchPlayers[6], (p) => benchPlayers[6] = p),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildListCard(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: _getRoleColor(p['role']), borderRadius: BorderRadius.circular(4)),
                  child: Center(child: Text(p['role'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), overflow: TextOverflow.ellipsis),
                          ),
                          if (p['is_captain']) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.stars, color: Colors.amber, size: 20)),
                          const SizedBox(width: 6),
                          Padding(padding: const EdgeInsets.only(right: 10), child: Text(_getFlagOnly(p['national_team']), style: const TextStyle(fontSize: 18))), 
                        ],
                      ),
                      Text(p['match'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: p['is_starter'] ? Colors.green : (p['is_bench'] ? Colors.orange[800] : Colors.grey), shape: BoxShape.circle),
                  child: Center(child: Text(p['is_starter'] ? 'T' : (p['is_bench'] ? 'P' : 'X'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(Icons.person, p['apps'].toString()),
                _statItem(Icons.sports_soccer, p['goals'].toString()),
                _statItem(Icons.style, '${p['yellows']}/${p['reds']}'),
                _statItem(Icons.directions_run, p['assists'].toString()),
                _statText('MV', p['mv'].toStringAsFixed(2)),
                _statText('FM', p['fm'].toStringAsFixed(2)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
      ],
    );
  }

  Widget _statText(String label, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> titolari = roster.where((p) => p['is_starter'] && p['role'] != 'CT').toList();
    List<Map<String, dynamic>> panchinari = roster.where((p) => p['is_bench'] && p['role'] != 'CT').toList();

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/sfondo.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Schiera Formazione', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(icon: const Icon(Icons.help_outline), onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tap: Inserisci/Cambia. Doppio Tap: Rimuovi. Pressione Lunga: Capitano.')));
            }),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Icon(Icons.shield, color: Colors.orange[800], size: 24),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.teamName,
                                        style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.orange[900]!]),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 3))],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('MODULO', style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: currentFormation,
                                        dropdownColor: Colors.orange[900],
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                        isDense: true,
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) _changeFormation(newValue);
                                        },
                                        items: validFormations.map<DropdownMenuItem<String>>((String value) {
                                          return DropdownMenuItem<String>(value: value, child: Text(value));
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.save, color: Colors.orange[800], size: 24),
                                      tooltip: 'Salva bozza',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _saveLineup(forceSave: true),
                                    ),
                                    const SizedBox(width: 20),
                                    IconButton(
                                      icon: Icon(Icons.share, color: Colors.orange[800], size: 24),
                                      tooltip: 'Copia formazione',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: _copyLineupToClipboard,
                                    ),
                                    const SizedBox(width: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.orange[800],
                          indicatorWeight: 4,
                          labelColor: Colors.black87,
                          unselectedLabelColor: const Color.fromARGB(93, 0, 0, 0),
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                          tabs: const [
                            Tab(text: 'CAMPO'),
                            Tab(text: 'TITOLARI'),
                            Tab(text: 'PANCHINA'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabCampo(),
                        titolari.isEmpty 
                            ? const Center(child: Text('Nessun titolare schierato', style: TextStyle(color: Colors.white70, fontSize: 16)))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 20),
                                itemCount: titolari.length,
                                itemBuilder: (context, index) => _buildListCard(titolari[index]),
                              ),
                        panchinari.isEmpty 
                            ? const Center(child: Text('Nessun panchinaro schierato', style: TextStyle(color: Colors.white70, fontSize: 16)))
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 20),
                                itemCount: panchinari.length,
                                itemBuilder: (context, index) => _buildListCard(panchinari[index]),
                              ),
                      ],
                    ),
                  ),
                ],
              ),

        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : () => _saveLineup(forceSave: false),
              icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.send),
              label: const Text('INVIA FORMAZIONE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.orange[800], 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}