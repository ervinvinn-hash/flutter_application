import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_roles_screen.dart';

// Modello per gestire comodamente i dati in locale prima di salvarli
class PlayerStatInput {
  final int playerId;
  final String name;
  final String role;
  final String team;
  double baseGrade;
  int goalsScored;
  int assists;
  int yellowCards;
  int redCards;
  bool manOfTheMatch;
  int ownGoals;
  bool cleanSheet;
  int penaltySaved;
  int penaltyMissed;
  int goalsConceded;
  double coachMultiplier;

  PlayerStatInput({
    required this.playerId,
    required this.name,
    required this.role,
    required this.team,
    this.baseGrade = 6.0,
    this.goalsScored = 0,
    this.assists = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.manOfTheMatch = false,
    this.ownGoals = 0,
    this.cleanSheet = false,
    this.penaltySaved = 0,
    this.penaltyMissed = 0,
    this.goalsConceded = 0,
    this.coachMultiplier = 0.0,
  });
}

class AdminVotesScreen extends StatefulWidget {
  const AdminVotesScreen({super.key});

  @override
  State<AdminVotesScreen> createState() => _AdminVotesScreenState();
}

class _AdminVotesScreenState extends State<AdminVotesScreen> {
  bool isLoading = true;
  int selectedMatchDay = 1;
  List<PlayerStatInput> playersToGrade = [];
  List<PlayerStatInput> filteredPlayers = [];
  String searchQuery = '';
  String roleFilter = 'Tutti';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final playersData = await Supabase.instance.client.from('players').select('id, name, role, national_team');
      
      final rosterData = await Supabase.instance.client.from('roster_players').select('player_id');
      final Set<int> ownedPlayerIds = rosterData.map<int>((row) => row['player_id'] as int).toSet();

      final statsData = await Supabase.instance.client.from('matchday_stats').select().eq('match_day', selectedMatchDay);
      Map<int, Map<String, dynamic>> existingStats = { for (var row in statsData) row['player_id']: row };

      List<PlayerStatInput> loadedPlayers = [];

      for (var p in playersData) {
        int pId = p['id'];
        
        if (ownedPlayerIds.contains(pId)) {
          var stat = existingStats[pId];
          loadedPlayers.add(PlayerStatInput(
            playerId: pId,
            name: p['name'],
            role: p['role'],
            team: p['national_team'],
            baseGrade: stat != null ? (stat['base_grade'] as num).toDouble() : 6.0,
            goalsScored: stat != null ? stat['goals_scored'] : 0,
            assists: stat != null ? stat['assists'] : 0,
            yellowCards: stat != null ? stat['yellow_cards'] : 0,
            redCards: stat != null ? stat['red_cards'] : 0,
            manOfTheMatch: stat != null ? stat['man_of_the_match'] : false,
            ownGoals: stat != null ? stat['own_goals'] : 0,
            cleanSheet: stat != null ? stat['clean_sheet'] : false,
            penaltySaved: stat != null ? stat['penalty_saved'] : 0,
            penaltyMissed: stat != null ? stat['penalty_missed'] : 0,
            goalsConceded: stat != null ? stat['goals_conceded'] : 0,
            coachMultiplier: stat != null ? (stat['coach_multiplier'] as num?)?.toDouble() ?? 0.0 : 0.0,
          ));
          if (p['role'] == 'CT') {
            loadedPlayers.last.baseGrade = 0.0;
          }
        }
      }

      final roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5};
      loadedPlayers.sort((a, b) {
        int roleComparison = roleOrder[a.role]!.compareTo(roleOrder[b.role]!);
        if (roleComparison != 0) return roleComparison;
  
        String lastNameA = a.name.contains('.') ? a.name.split('.').last.trim() : a.name;
        String lastNameB = b.name.contains('.') ? b.name.split('.').last.trim() : b.name;
        return lastNameA.compareTo(lastNameB);
      });

      setState(() {
        playersToGrade = loadedPlayers;
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredPlayers = playersToGrade.where((p) {
        bool matchesRole = roleFilter == 'Tutti' || p.role == roleFilter;
        bool matchesSearch = p.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
                             p.team.toLowerCase().contains(searchQuery.toLowerCase());
        return matchesRole && matchesSearch;
      }).toList();
    });
  }

  Future<void> _savePlayerStat(PlayerStatInput stat) async {
    try {
      await Supabase.instance.client.from('matchday_stats').upsert({
        'match_day': selectedMatchDay,
        'player_id': stat.playerId,
        'base_grade': stat.baseGrade,
        'goals_scored': stat.goalsScored,
        'assists': stat.assists,
        'yellow_cards': stat.yellowCards,
        'red_cards': stat.redCards,
        'man_of_the_match': stat.manOfTheMatch,
        'own_goals': stat.ownGoals,
        'clean_sheet': stat.cleanSheet,
        'penalty_saved': stat.penaltySaved,
        'penalty_missed': stat.penaltyMissed,
        'goals_conceded': stat.goalsConceded,
        'coach_multiplier': stat.role == 'CT' ? stat.coachMultiplier : 0.0,
      }, onConflict: 'match_day, player_id');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voto salvato per ${stat.name}'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e'), backgroundColor: Colors.red));
    }
  }
  
  Future<void> _deletePlayerStat(PlayerStatInput stat) async {
    try {
      await Supabase.instance.client
          .from('matchday_stats')
          .delete()
          .eq('match_day', selectedMatchDay)
          .eq('player_id', stat.playerId);

      setState(() {
        stat.baseGrade = 6.0;
        stat.goalsScored = 0;
        stat.assists = 0;
        stat.yellowCards = 0;
        stat.redCards = 0;
        stat.manOfTheMatch = false;
        stat.ownGoals = 0;
        stat.cleanSheet = false;
        stat.penaltySaved = 0;
        stat.penaltyMissed = 0;
        stat.goalsConceded = 0;
        stat.coachMultiplier = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Voto eliminato per ${stat.name}'),
        backgroundColor: Colors.orange[800],
        duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Errore eliminazione: $e'),
        backgroundColor: Colors.red,
      ));
    }
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

  void _openGradingSheet(PlayerStatInput stat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Widget buildCounterRow(String label, int value, Function(int) onChanged) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 16)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => onChanged(value > 0 ? value - 1 : 0)),
                        SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => onChanged(value + 1)),
                      ],
                    )
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: _getRoleColor(stat.role), child: Text(stat.role, style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stat.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('${stat.team} ${_getFlagOnly(stat.team)}', style: const TextStyle(color: Colors.grey)), 
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30, thickness: 2),

                    if (stat.role == 'CT') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('BONUS ALLENATORE:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32), onPressed: () => setModalState(() => stat.coachMultiplier -= 0.5)),
                              SizedBox(width: 60, child: Text(stat.coachMultiplier > 0 ? '+${stat.coachMultiplier}' : stat.coachMultiplier.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: () => setModalState(() => stat.coachMultiplier += 0.5)),
                            ],
                          )
                        ],
                      ),
                      const Divider(),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('VOTO BASE:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32), onPressed: () => setModalState(() => stat.baseGrade -= 0.5)),
                              SizedBox(width: 60, child: Text(stat.baseGrade.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: () => setModalState(() => stat.baseGrade += 0.5)),
                            ],
                          )
                        ],
                      ),
                      const Divider(),
                    ],

                    if (stat.role != 'CT') ...[
                      buildCounterRow('Gol Fatti ⚽', stat.goalsScored, (v) => setModalState(() => stat.goalsScored = v)),
                      buildCounterRow('Assist 👟', stat.assists, (v) => setModalState(() => stat.assists = v)),
                      buildCounterRow('Autogol 🤦‍♂️', stat.ownGoals, (v) => setModalState(() => stat.ownGoals = v)),
                      buildCounterRow('Cartellini Gialli 🟨', stat.yellowCards, (v) => setModalState(() => stat.yellowCards = v)),
                      buildCounterRow('Cartellini Rossi 🟥', stat.redCards, (v) => setModalState(() => stat.redCards = v)),
                      buildCounterRow('Rigori Sbagliati ❌', stat.penaltyMissed, (v) => setModalState(() => stat.penaltyMissed = v)),
                      SwitchListTile(
                        title: const Text('Uomo Partita 🌟'),
                        value: stat.manOfTheMatch,
                        activeThumbColor: Colors.amber,
                        onChanged: (v) => setModalState(() => stat.manOfTheMatch = v),
                      ),
                      if (stat.role == 'P') ...[
                        const Divider(),
                        const Text('Statistiche Portiere', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        buildCounterRow('Gol Subiti 🥅', stat.goalsConceded, (v) => setModalState(() => stat.goalsConceded = v)),
                        buildCounterRow('Rigori Parati 🧤', stat.penaltySaved, (v) => setModalState(() => stat.penaltySaved = v)),
                        SwitchListTile(
                          title: const Text('Rete Inviolata 🛡️'),
                          value: stat.cleanSheet,
                          activeThumbColor: Colors.orange,
                          onChanged: (v) => setModalState(() => stat.cleanSheet = v),
                        ),
                      ]
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[400]!),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () {
                              _deletePlayerStat(stat);
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('AZZERA', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[800], 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(vertical: 16)
                            ),
                            onPressed: () {
                              _savePlayerStat(stat);
                              setState(() {}); 
                              Navigator.pop(ctx);
                            },
                            child: const Text('SALVA VOTI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        toolbarHeight: 110, 
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Gestione Voti', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.manage_accounts),
                      tooltip: 'Modifica Ruoli',
                      onPressed: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const AdminRolesPage())
                      ),
                    ),
                    // Rimosse le icone di download API e del calendario
                  ],
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    dropdownColor: Colors.red[900],
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    value: selectedMatchDay,
                    items: List.generate(8, (i) => i + 1).map((val) => DropdownMenuItem(value: val, child: Text('Giornata $val'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedMatchDay = val);
                        _fetchData();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.red))
        : Column(
            children: [
              Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cerca calciatore o nazionale...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        searchQuery = val;
                        _applyFilters();
                      },
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Tutti', 'CT', 'P', 'D', 'C', 'A'].map((role) {
                          bool isSel = roleFilter == role;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ChoiceChip(
                              selectedColor: _getRoleColor(role == 'Tutti' ? 'CT' : role).withValues(alpha: 0.3),
                              label: Text(role),
                              selected: isSel,
                              onSelected: (sel) {
                                if (sel) {
                                  roleFilter = role;
                                  _applyFilters();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: filteredPlayers.isEmpty
                  ? const Center(child: Text('Nessun giocatore trovato nelle rose.'))
                  : ListView.builder(
                      itemCount: filteredPlayers.length,
                      itemBuilder: (context, index) {
                        final stat = filteredPlayers[index];
                        
                        List<Widget> badges = [];
                        if (stat.goalsScored > 0) badges.add(Text('⚽x${stat.goalsScored} '));
                        if (stat.assists > 0) badges.add(Text('👟x${stat.assists} '));
                        if (stat.ownGoals > 0) badges.add(Text('🤦‍♂️x${stat.ownGoals} '));
                        if (stat.yellowCards > 0) badges.add(const Text('🟨 '));
                        if (stat.redCards > 0) badges.add(const Text('🟥 '));

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: _getRoleColor(stat.role), child: Text(stat.role, style: const TextStyle(color: Colors.white))),
                            title: Text(stat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${stat.team} ${_getFlagOnly(stat.team)}', style: const TextStyle(fontSize: 12)), 
                                if (badges.isNotEmpty) Row(children: badges),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                stat.role == 'CT' 
                                  ? (stat.coachMultiplier > 0 ? '+${stat.coachMultiplier}' : stat.coachMultiplier.toString())
                                  : stat.baseGrade.toStringAsFixed(1), 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                            ),
                            onTap: () => _openGradingSheet(stat),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}