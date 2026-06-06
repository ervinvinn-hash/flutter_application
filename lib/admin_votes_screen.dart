import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  });
}

class AdminVotesScreen extends StatefulWidget {
  const AdminVotesScreen({super.key});

  @override
  State<AdminVotesScreen> createState() => _AdminVotesScreenState();
}

class _AdminVotesScreenState extends State<AdminVotesScreen> {
  bool isFetchingApi = false;

  String _normalizeName(String name) {
    return name.toLowerCase()
        .replaceAll('á', 'a').replaceAll('à', 'a')
        .replaceAll('é', 'e').replaceAll('è', 'e')
        .replaceAll('í', 'i').replaceAll('ì', 'i')
        .replaceAll('ó', 'o').replaceAll('ò', 'o')
        .replaceAll('ú', 'u').replaceAll('ù', 'u')
        .replaceAll('ñ', 'n').replaceAll('ç', 'c')
        .replaceAll('-', ' ').replaceAll('.', '').replaceAll('\'', ' ')
        .trim();
  }

  Future<void> _importFromApiFootball() async {
    setState(() => isFetchingApi = true);
    try {
      final String apiKey = 'bce05b8a0e7f20ab55f3cf2a69f7102b'; 
      String today = DateTime.now().toIso8601String().split('T')[0];

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ricerca partite del $today...'), backgroundColor: Colors.orange[800]));

      final fixturesRes = await http.get(
        Uri.parse('https://v3.football.api-sports.io/fixtures?date=$today'),
        headers: {'x-apisports-key': apiKey},
      );
      
      final fixturesData = json.decode(fixturesRes.body);
      final List fixtures = fixturesData['response'];

      if (fixtures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nessuna partita giocata in questa data!'), backgroundColor: Colors.red));
        setState(() => isFetchingApi = false);
        return;
      }

      int updatedCount = 0;

      for (var fix in fixtures) {
        int fixId = fix['fixture']['id'];
        
        final statsRes = await http.get(
          Uri.parse('https://v3.football.api-sports.io/fixtures/players?fixture=$fixId'),
          headers: {'x-apisports-key': apiKey},
        );
        
        final statsData = json.decode(statsRes.body);
        if (statsData['response'] == null || statsData['response'].isEmpty) continue;
        
        final List teamsStats = statsData['response'];

        for (var team in teamsStats) {
          final List playersList = team['players'];
          
          for (var p in playersList) {
            final playerInfo = p['player'];
            final stats = p['statistics'][0];
            
            String apiName = _normalizeName(playerInfo['name'].toString());
            double rating = double.tryParse(stats['games']['rating']?.toString() ?? '6.0') ?? 6.0;
            
            int goals = stats['goals']['total'] ?? 0;
            int assists = stats['goals']['assists'] ?? 0;
            int yellows = stats['cards']['yellow'] ?? 0;
            int reds = stats['cards']['red'] ?? 0;
            int penMissed = stats['penalty']['missed'] ?? 0;
            int penSaved = stats['penalty']['saved'] ?? 0;
            
            int minutesPlayed = stats['games']['minutes'] ?? 0;
            int goalsConceded = stats['goals']['conceded'] ?? 0;
            
            bool matchTrovato = false;

            for (var myPlayer in playersToGrade) {
              String myName = _normalizeName(myPlayer.name);
              
              if (myName.contains(apiName) || apiName.contains(myName.split(' ').last)) {
                matchTrovato = true;
                print('✅ MATCH OK: API[$apiName] salvato su [$myName]');
                
                setState(() {
                  myPlayer.baseGrade = double.parse(rating.toStringAsFixed(1));
                  myPlayer.goalsScored = goals;
                  myPlayer.assists = assists;
                  myPlayer.yellowCards = yellows;
                  myPlayer.redCards = reds;
                  myPlayer.penaltyMissed = penMissed;
                  myPlayer.penaltySaved = penSaved;
                  myPlayer.ownGoals = 0; 
                  myPlayer.manOfTheMatch = false; 
                  myPlayer.cleanSheet = (minutesPlayed > 0 && goalsConceded == 0 && (myPlayer.role == 'P' || myPlayer.role == 'D'));
                });
                
                await _savePlayerStat(myPlayer);
                updatedCount++;
                break;
              }
            }
            if (!matchTrovato && minutesPlayed > 0) {
               print('❌ PERSO: L\'API ha inviato [$apiName] ma non è nel database!');
            }
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Magia completata! 🪄 Aggiornati $updatedCount giocatori.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore Automazione: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isFetchingApi = false);
    }
  }

  Future<void> _popolaDatabaseGiocatori() async {
    final String apiKey = 'bce05b8a0e7f20ab55f3cf2a69f7102b'; 
    final int leagueId = 1; 
    final int season = 2026;

    setState(() => isFetchingApi = true); 

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fase 1: Scarico le Nazionali dal server...')));

      final teamsRes = await http.get(
        Uri.parse('https://v3.football.api-sports.io/teams?league=$leagueId&season=$season'),
        headers: {'x-apisports-key': apiKey},
      );

      final teamsData = json.decode(teamsRes.body);
      if (teamsData['response'] == null) throw Exception("Nessuna squadra trovata");
      final List teams = teamsData['response'];

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trovate ${teams.length} Nazionali. Inizio il download dei giocatori...')));

      int giocatoriTotali = 0;

      for (var t in teams) {
        int teamId = t['team']['id'];
        String apiTeamName = t['team']['name']; 
        
        final Map<String, String> traduzioneNazioni = {
          'Italy': 'Italia', 'France': 'Francia', 'Germany': 'Germania',
          'England': 'Inghilterra', 'Spain': 'Spagna', 'Brazil': 'Brasile',
          'Belgium': 'Belgio', 'Netherlands': 'Paesi Bassi', 'Croatia': 'Croazia',
          'Portugal': 'Portogallo', 'Morocco': 'Marocco', 'Japan': 'Giappone',
          'South Korea': 'Corea', 'Ivory Coast': 'Costa d\'avorio', 'Saudi Arabia': 'Arabia Saudita',
          'Switzerland': 'Svizzera', 'Sweden': 'Svezia', 'South Africa': 'Sud Africa',
          'Norway': 'Norvegia', 'New Zealand': 'Nuova Zelanda', 'Scotland': 'Scozia',
          'Denmark': 'Danimarca', 'Poland': 'Polonia', 'Wales': 'Galles',
          'Cameroon': 'Camerun', 'Mexico': 'Messico', 'United States': 'USA',
        };

        String teamName = traduzioneNazioni[apiTeamName] ?? apiTeamName;

        final squadRes = await http.get(
          Uri.parse('https://v3.football.api-sports.io/players/squads?team=$teamId'),
          headers: {'x-apisports-key': apiKey},
        );

        final squadData = json.decode(squadRes.body);
        
        if (squadData['response'] != null && squadData['response'].isNotEmpty) {
          final List players = squadData['response'][0]['players'];
          List<Map<String, dynamic>> giocatoriDaInserire = [];

          for (var p in players) {
            String name = p['name'];
            String position = p['position'];
            
            String fantaRole = 'C'; 
            if (position == 'Goalkeeper') fantaRole = 'P';
            else if (position == 'Defender') fantaRole = 'D';
            else if (position == 'Midfielder') fantaRole = 'C';
            else if (position == 'Attacker') fantaRole = 'A';

            // --- NUOVO: Calcolo il cognome pulito ---
            String sortName = name.contains('.') ? name.split('.').last.trim() : name;

            giocatoriDaInserire.add({
              'name': name,
              'sort_name': sortName, // <-- Colonna aggiunta
              'role': fantaRole,
              'national_team': teamName,
              'price': 10, 
            });
          }

          await Supabase.instance.client.from('players').insert(giocatoriDaInserire);
          giocatoriTotali += giocatoriDaInserire.length;
        }

        await Future.delayed(const Duration(seconds: 7));
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TUTTO FINITO! 🥳 Inseriti $giocatoriTotali giocatori.'), backgroundColor: Colors.green));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isFetchingApi = false);
    }
  }

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
          ));
        }
      }

      // Ordiniamo in locale prima per ruolo e poi per cognome
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
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voto salvato per ${stat.name}'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e'), backgroundColor: Colors.red));
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

  String getCountryWithFlag(String country) {
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
      'Tunisia': '🇹🇳', 'Turchia': '🇹🇷', 'Uruguay': '🇺🇾', 'USA': '🇺🇸', 'Uzbekistan': '🇺🇿',
    };
    return '$cleanCountry ${flags[cleanCountry] ?? '🏳️'}';
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
                              Text(getCountryWithFlag(stat.team), style: const TextStyle(color: Colors.grey)), 
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30, thickness: 2),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VOTO BASE:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32), onPressed: () => setModalState(() => stat.baseGrade -= 0.5)),
                            SizedBox(width: 50, child: Text(stat.baseGrade.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                            IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: () => setModalState(() => stat.baseGrade += 0.5)),
                          ],
                        )
                      ],
                    ),
                    const Divider(),

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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () {
                        _savePlayerStat(stat);
                        setState(() {}); 
                        Navigator.pop(ctx);
                      },
                      child: const Text('SALVA VOTI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
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
            // RIGA 1: TITOLO
            const Text('Gestione Voti', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // RIGA 2: ICONE A SINISTRA E MENU A DESTRA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // GRUPPO BOTTONI (Solo Rose e Download Manuale)
                Row(
                  children: [
                    // Nel build dell'AppBar di AdminVotesScreen:
                    IconButton(
                      icon: const Icon(Icons.manage_accounts),
                      tooltip: 'Modifica Ruoli',
                      onPressed: () => Navigator.push(
                      context, 
                    MaterialPageRoute(builder: (context) => const AdminRolesPage())
                     ),
                  ),
                    IconButton(
                      icon: const Icon(Icons.group_add),
                      tooltip: 'Scarica Rose Ufficiali',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _popolaDatabaseGiocatori,
                    ),
                    const SizedBox(width: 16),
                    isFetchingApi 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Scarica Voti Ora (Singolo)',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _importFromApiFootball,
                        ),
                  ],
                ),
                // MENU A TENDINA GIORNATA
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
                                Text(getCountryWithFlag(stat.team), style: const TextStyle(fontSize: 12)), 
                                if (badges.isNotEmpty) Row(children: badges),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                              child: Text(stat.baseGrade.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
