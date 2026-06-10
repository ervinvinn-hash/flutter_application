import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Player {
  final int id;
  final String name;
  final String role;
  final String team;
  final int price;
  double purchasePrice; // Corretto per i mezzi crediti

  Player(this.name, this.role, this.team, this.price, {this.id = 0, this.purchasePrice = 0.0});
}

class RosterScreen extends StatefulWidget {
  final String teamId;

  const RosterScreen({super.key, required this.teamId});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double budget = 0;
  List<Player> mySquad = [];
  List<Player> allPlayers = [];
  Set<int> purchasedPlayerIds = {}; // Il registro di TUTTI i giocatori comprati nella lega
  bool isLoading = true;

  String _selectedRoleFilter = 'Tutti';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Map<String, int> roleLimits = {'CT': 2, 'P': 3, 'D': 8, 'C': 8, 'A': 6};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDataFromDatabase();
  }

  void _sortMySquad() {
    final Map<String, int> roleOrder = {'P': 1, 'D': 2, 'C': 3, 'A': 4, 'CT': 5};
    
    mySquad.sort((a, b) {
      // 1. Ordina per Ruolo
      int roleComp = (roleOrder[a.role] ?? 99).compareTo(roleOrder[b.role] ?? 99);
      if (roleComp != 0) return roleComp;
      
      // 2. Estrapola il cognome se c'è un punto
      String lastNameA = a.name.contains('.') ? a.name.split('.').last.trim() : a.name;
      String lastNameB = b.name.contains('.') ? b.name.split('.').last.trim() : b.name;
      
      // 3. Ordina per Cognome
      return lastNameA.compareTo(lastNameB);
    });
  }

  Future<void> _fetchDataFromDatabase() async {
    try {
      // ORA CHIEDIAMO I DATI GIÀ ORDINATI DA SUPABASE
      final playersData = await Supabase.instance.client
          .from('players')
          .select()
          .order('role', ascending: true)
          .order('sort_name', ascending: true);
          
      final List<Player> loadedPlayers = playersData.map<Player>((json) {
        return Player(json['name'], json['role'], json['national_team'], json['price'], id: json['id']);
      }).toList();

      final teamData = await Supabase.instance.client.from('fantasy_teams').select().eq('id', widget.teamId).single();
      
      final allRostersData = await Supabase.instance.client.from('roster_players').select('player_id, team_id, purchase_price');
      
      List<Player> myLoadedSquad = [];
      Set<int> globalUnavailable = {};

      for (var row in allRostersData) {
        int pid = row['player_id'];
        globalUnavailable.add(pid); 

        if (row['team_id'] == widget.teamId) {
          Player p = loadedPlayers.firstWhere((player) => player.id == pid);
          p.purchasePrice = (row['purchase_price'] as num).toDouble();
          myLoadedSquad.add(p);
        }
      }

      setState(() {
        allPlayers = loadedPlayers;
        budget = (teamData['budget'] as num).toDouble(); 
        mySquad = myLoadedSquad;
        purchasedPlayerIds = globalUnavailable; 
        _sortMySquad();
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  int countRole(String role) => mySquad.where((player) => player.role == role).length;

  String getCountryWithFlag(String country) {
    final String cleanCountry = country
        .trim()
        .replaceAll('’', '\'')
        .replaceAll('`', '\''); 
    final Map<String, String> flags = {
      'Algeria': '🇩🇿', 'Arabia Saudita': '🇸🇦', 'Argentina': '🇦🇷', 'Australia': '🇦🇺',
      'Austria': '🇦🇹', 'Belgio': '🇧🇪', 'Bosnia e Herzegovina': '🇧🇦', 'Brasile': '🇧🇷',
      'Canada': '🇨🇦', 'Capo Verde': '🇨🇻', 'Colombia': '🇨🇴', 'Congo': '🇨🇩', 
      'Congo DR': '🇨🇩', 'Corea': '🇰🇷', 'Costa D\'avorio': '🇨🇮', 'Croazia': '🇭🇷',
      'Curacao': '🇨🇼', 'Curaçao': '🇨🇼', 'Ecuador': '🇪🇨', 'Egitto': '🇪🇬',
      'Francia': '🇫🇷', 'Germania': '🇩🇪', 'Ghana': '🇬🇭', 'Giappone': '🇯🇵',
      'Giordania': '🇯🇴', 'Haiti': '🇭🇹', 'Inghilterra': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'Iran': '🇮🇷',
      'Iraq': '🇮🇶', 'Italia': '🇮🇹', 'Marocco': '🇲🇦', 'Morocco': '🇲🇦',
      'Messico': '🇲🇽', 'Norvegia': '🇳🇴', 'Nuova Zelanda': '🇳🇿', 'Olanda': '🇳🇱',
      'Paesi Bassi': '🇳🇱', 'Panama': '🇵🇦', 'Paraguay': '🇵🇾', 'Portogallo': '🇵🇹',
      'Qatar': '🇶🇦', 'Repubblica Ceca': '🇨🇿', 'Scozia': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'Senegal': '🇸🇳',
      'Spagna': '🇪🇸', 'Sud Africa': '🇿🇦', 'Svezia': '🇸🇪', 'Svizzera': '🇨🇭',
      'Tunisia': '🇹🇳', 'Turchia': '🇹🇷', 'Uruguay': '🇺🇾', 'Usa': '🇺🇸',
      'Uzbekistan': '🇺🇿',
    };
    return '$cleanCountry ${flags[cleanCountry] ?? '🏳️'}';
  }

  void _showPurchaseDialog(Player player) {
    if (mySquad.contains(player)) return;
    if (countRole(player.role) >= roleLimits[player.role]!) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hai raggiunto il limite per il ruolo ${player.role}!'), backgroundColor: Colors.red));
      return;
    }

    final TextEditingController priceController = TextEditingController(text: player.price.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Acquista ${player.name}', style: TextStyle(color: Colors.orange[900])),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quotazione base: ${player.price} cr'),
              const SizedBox(height: 15),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true), // Tastiera per decimali
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Crediti spesi', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[800]!), borderRadius: BorderRadius.circular(12))
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
              onPressed: () {
                double? spent = double.tryParse(priceController.text.replaceAll(',', '.'));
                if (spent == null || spent < 1 || spent > budget) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valore non valido o crediti insufficienti')));
                  return;
                }
                Navigator.pop(context);
                _executePurchase(player, spent);
              },
              child: const Text('Conferma'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executePurchase(Player player, double spentCredits) async {
    try {
      await Supabase.instance.client.from('roster_players').insert({
        'team_id': widget.teamId, 'player_id': player.id, 'purchase_price': spentCredits,
      });
      await Supabase.instance.client.from('fantasy_teams').update({'budget': budget - spentCredits}).eq('id', widget.teamId);

      setState(() {
        budget -= spentCredits;
        player.purchasePrice = spentCredits;
        mySquad.add(player);
        purchasedPlayerIds.add(player.id); // Nascondilo subito dal listone
        _sortMySquad();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hai preso ${player.name} a $spentCredits cr!'), backgroundColor: Colors.green));
    } catch (e) {}
  }

  void _showSellDialog(Player player) {
    final TextEditingController recoverController = TextEditingController(text: player.purchasePrice.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Svincola ${player.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Acquistato a: ${player.purchasePrice} cr'),
              const SizedBox(height: 15),
              TextField(
                controller: recoverController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true), // Tastiera per decimali
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Crediti da recuperare', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.red), borderRadius: BorderRadius.circular(12))
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                double? recovered = double.tryParse(recoverController.text.replaceAll(',', '.'));
                if (recovered == null || recovered < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci un numero valido')));
                  return;
                }
                if (recovered > player.purchasePrice) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non puoi recuperare più di quanto hai speso!')));
                  return;
                }
                Navigator.pop(context);
                _executeSell(player, recovered);
              },
              child: const Text('Svincola'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeSell(Player player, double recoveredCredits) async {
    try {
      await Supabase.instance.client.from('roster_players').delete().eq('team_id', widget.teamId).eq('player_id', player.id);
      await Supabase.instance.client.from('fantasy_teams').update({'budget': budget + recoveredCredits}).eq('id', widget.teamId);

      setState(() {
        budget += recoveredCredits;
        mySquad.remove(player);
        purchasedPlayerIds.remove(player.id); // Rimettilo subito nel listone!
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Svincolato ${player.name} (+$recoveredCredits cr)'), backgroundColor: Colors.orange[800]));
    } catch (e) {}
  }

  Color getRoleColor(String role) {
    switch (role) {
      case 'P': return Colors.orange;
      case 'D': return Colors.green[700]!;
      case 'C': return Colors.blue[700]!;
      case 'A': return Colors.red[700]!;
      case 'CT': return Colors.black87;
      default: return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFilterCircle(String role, String label) {
    bool isSelected = _selectedRoleFilter == role;
    Color roleColor = role == 'Tutti' ? Colors.grey[800]! : getRoleColor(role);

    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? roleColor : Colors.white.withValues(alpha: 0.9), 
          border: Border.all(color: isSelected ? roleColor : Colors.grey[400]!, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: roleColor.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : roleColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCounter(String role, int current, int max) {
    bool isFull = current >= max;
    return Column(
      children: [
        Text(role, style: TextStyle(fontWeight: FontWeight.bold, color: getRoleColor(role))),
        Text('$current/$max', style: TextStyle(color: isFull ? Colors.red : Colors.black87, fontWeight: isFull ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildPlayerCard(Player player, bool isBought, {required bool isListone}) {
    final displayPrice = isListone ? player.price : player.purchasePrice;
    return Card(
      elevation: 2,
      color: Colors.white.withValues(alpha: 0.95), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: getRoleColor(player.role), child: Text(player.role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        subtitle: Text(getCountryWithFlag(player.team), style: const TextStyle(color: Colors.black54)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$displayPrice cr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isListone ? Colors.black87 : Colors.orange[900])),
            const SizedBox(width: 15),
            isListone
                ? ElevatedButton(
                    onPressed: isBought ? null : () => _showPurchaseDialog(player), 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isBought ? 'Preso' : 'Compra')
                  )
                : OutlinedButton(
                    onPressed: () => _showSellDialog(player), 
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                    child: const Text('Svincola')
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MODIFICA FILTRO: ORA NASCONDE I GIOCATORI COMPRATI DA *CHIUNQUE* (purchasedPlayerIds)
    List<Player> availableListone = allPlayers.where((p) {
      return !purchasedPlayerIds.contains(p.id);
    }).toList();

    List<Player> filteredListone = availableListone.where((p) {
      bool matchesRole = _selectedRoleFilter == 'Tutti' || p.role == _selectedRoleFilter;
      bool matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                           p.team.toLowerCase().contains(_searchQuery.toLowerCase());
                           
      return matchesRole && matchesSearch;
    }).toList();

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
          title: const Text('Mercato e Asta', style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color.fromRGBO(255, 255, 255, 1)),
        ),
        body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color.fromRGBO(255, 152, 0, 1))) 
          : Column(
              children: [
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    int currentIndex = _tabController.index; 
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _tabController.animateTo(0),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.list, color: currentIndex == 0 ? Colors.orange[800] : Colors.black54),
                                  Text('Listone', style: TextStyle(color: currentIndex == 0 ? Colors.black87 : Colors.black54, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.orange[900]!]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('BUDGET', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                Text('$budget cr', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                          Expanded(
                            child: GestureDetector(
                              onTap: () => _tabController.animateTo(1),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.group, color: currentIndex == 1 ? Colors.orange[800] : Colors.black54),
                                  Text('La Mia Rosa', style: TextStyle(color: currentIndex == 1 ? Colors.black87 : Colors.black54, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
                
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Column(
                        children: [
                          Container(
                            color: Colors.white.withValues(alpha: 0.7),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Cerca calciatore o nazione...',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                });
                                              },
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20.0),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.9), 
                                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildFilterCircle('Tutti', '∞'),
                                      _buildFilterCircle('CT', 'CT'),
                                      _buildFilterCircle('P', 'P'),
                                      _buildFilterCircle('D', 'D'),
                                      _buildFilterCircle('C', 'C'),
                                      _buildFilterCircle('A', 'A'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: filteredListone.isEmpty
                              ? const Center(child: Text('Nessun giocatore trovato o tutti acquistati.', style: TextStyle(color: Colors.white70)))
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                                  itemCount: filteredListone.length,
                                  itemBuilder: (context, index) {
                                    final player = filteredListone[index];
                                    return _buildPlayerCard(player, false, isListone: true);
                                  },
                                ),
                          ),
                        ],
                      ),
                      
                      Column(
                        children: [
                          Container(
                            color: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.85),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildRoleCounter('CT', countRole('CT'), roleLimits['CT']!),
                                _buildRoleCounter('P', countRole('P'), roleLimits['P']!),
                                _buildRoleCounter('D', countRole('D'), roleLimits['D']!),
                                _buildRoleCounter('C', countRole('C'), roleLimits['C']!),
                                _buildRoleCounter('A', countRole('A'), roleLimits['A']!),
                              ],
                            ),
                          ),
                          Expanded(
                            child: mySquad.isEmpty 
                              ? const Center(child: Text('La tua rosa è vuota.', style: TextStyle(color: Colors.white70)))
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                                  itemCount: mySquad.length,
                                  itemBuilder: (context, index) => _buildPlayerCard(mySquad[index], true, isListone: false),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}