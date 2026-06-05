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

  // I 7 slot rigorosi della panchina
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
      final rosterData = await Supabase.instance.client.from('roster_players').select().eq('team_id', widget.teamId);
      final playersData = await Supabase.instance.client.from('players').select('id, name, role, national_team');
      
      Map<int, Map<String, dynamic>> playersMap = { for (var p in playersData) p['id']: p };

      List<Map<String, dynamic>> loadedRoster = [];
      for (var row in rosterData) {
        int pId = row['player_id'];
        if (playersMap.containsKey(pId)) {
          loadedRoster.add({
            'player_id': pId,
            'name': playersMap[pId]!['name'],
            'role': playersMap[pId]!['role'],
            'national_team': playersMap[pId]!['national_team'] ?? '???',
            'is_starter': row['is_starter'] ?? false,
            'is_bench': row['is_bench'] ?? false,
            'is_captain': row['is_captain'] ?? false,
            
            // DATI SIMULATI PER LA UI
            'match': 'Ita - Fra', 
            'apps': 0, 'goals': 0, 'assists': 0, 'yellows': 0, 'reds': 0, 'mv': 6.00, 'fm': 6.00,
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

  // NUOVA FUNZIONE: Restituisce solo l'emoji della bandiera
  String _getFlagOnly(String country) {
    final String cleanCountry = country.trim(); 
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
                        subtitle: Text('${p['national_team']} ${_getFlagOnly(p['national_team'])}'), // Aggiunta bandierina anche qui
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
    if (player == null) {
      return GestureDetector(
        onTap: () => _showPlayerSelectionDialog(role, (p) {
          setState(() { onUpdate(p); _syncRosterState(); });
        }),
        child: SizedBox(
          width: 55,
          child: Column(
            children: [
              CircleAvatar(radius: 20, backgroundColor: Colors.white.withValues(alpha: 0.5), child: Icon(Icons.add, color: _getRoleColor(role))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                child: const Text('Vuoto', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showPlayerSelectionDialog(role, (p) {
        if (p != null) setState(() { onUpdate(p); _syncRosterState(); });
      }),
      onDoubleTap: () => setState(() { onUpdate(null); _syncRosterState(); }),
      onLongPress: () {
        if (role != 'CT') { 
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
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _getRoleColor(player['role']),
                  // Modificato: Ora mostra la bandiera al posto delle 3 lettere!
                  child: Text(_getFlagOnly(player['national_team']), style: const TextStyle(fontSize: 18)),
                ),
                if (player['is_captain'])
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                      child: const Icon(Icons.stars, size: 14, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2)]),
              child: Text(player['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 1),
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
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.green[800], 
              image: const DecorationImage(
                image: NetworkImage('https://www.transparenttextures.com/patterns/grass.png'),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
            child: Stack(
              children: [
                Center(child: Container(height: 2, color: Colors.white.withValues(alpha: 0.5))),
                Center(child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2)))),
                
                Positioned(top: 0, left: 0, right: 0, child: Center(child: Container(width: 160, height: 60, decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), right: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2)))))),
                Positioned(top: 0, left: 0, right: 0, child: Center(child: Container(width: 70, height: 25, decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), right: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2)))))),
                
                Positioned(bottom: 0, left: 0, right: 0, child: Center(child: Container(width: 160, height: 60, decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), right: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2)))))),
                Positioned(bottom: 0, left: 0, right: 0, child: Center(child: Container(width: 70, height: 25, decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), right: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2), top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2)))))),
                
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRowOfSlots(fieldA, 'A', (i, p) => fieldA[i] = p),
                    _buildRowOfSlots(fieldC, 'C', (i, p) => fieldC[i] = p),
                    _buildRowOfSlots(fieldD, 'D', (i, p) => fieldD[i] = p),
                    
                    Row(
                      children: [
                        Expanded(child: Container()),
                        _buildSlot('P', fieldP, (p) => fieldP = p),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: _buildSlot('CT', fieldCoach, (p) => fieldCoach = p),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        Container(
          color: Colors.white.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PANCHINA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  return _buildSlot(benchRoles[index], benchPlayers[index], (p) => benchPlayers[index] = p);
                }),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSlot(benchRoles[5], benchPlayers[5], (p) => benchPlayers[5] = p),
                  const SizedBox(width: 40),
                  _buildSlot(benchRoles[6], benchPlayers[6], (p) => benchPlayers[6] = p),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildListCard(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      color: Colors.white.withValues(alpha: 0.95),
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
                          Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                          if (p['is_captain']) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.stars, color: Colors.amber, size: 16)),
                          const SizedBox(width: 6),
                          Text(_getFlagOnly(p['national_team']), style: const TextStyle(fontSize: 14)), // Bandierina anche qui di fianco al nome!
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
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/sfondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Invio Formazione', style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color.fromRGBO(255, 255, 255, 1)),
          actions: [
            IconButton(icon: const Icon(Icons.help_outline), onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tap: Inserisci/Cambia. Doppio Tap: Rimuovi. Pressione Lunga: Capitano.')));
            }),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                Container(
                  color: Colors.white.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Icon(Icons.group, color: Colors.orange[800], size: 24),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.teamName,
                                style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: DropdownButton<String>(
                            value: currentFormation,
                            dropdownColor: Colors.white.withValues(alpha: 0.9),
                            icon: Icon(Icons.arrow_drop_down, color: Colors.orange[800]),
                            style: TextStyle(color: Colors.orange[800], fontSize: 18, fontWeight: FontWeight.bold),
                            underline: Container(),
                            onChanged: (String? newValue) {
                              if (newValue != null) _changeFormation(newValue);
                            },
                            items: validFormations.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.save, color: Colors.orange[800]),
                              tooltip: 'Salva bozza',
                              onPressed: () => _saveLineup(forceSave: true),
                            ),
                            IconButton(
                              icon: Icon(Icons.share, color: Colors.orange[800]),
                              tooltip: 'Copia formazione',
                              onPressed: _copyLineupToClipboard,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white.withValues(alpha: 0.9),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.orange[800],
                    indicatorWeight: 4,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.black54,
                    tabs: const [
                      Tab(text: 'CAMPO'),
                      Tab(text: 'TITOLARI'),
                      Tab(text: 'PANCHINA'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildTabCampo(),
                  ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: titolari.length,
                    itemBuilder: (context, index) => _buildListCard(titolari[index]),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: panchinari.length,
                    itemBuilder: (context, index) => _buildListCard(panchinari[index]),
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