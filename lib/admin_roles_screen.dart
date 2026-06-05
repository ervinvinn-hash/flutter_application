import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRolesPage extends StatefulWidget {
  const AdminRolesPage({super.key});

  @override
  State<AdminRolesPage> createState() => _AdminRolesPageState();
}

class _AdminRolesPageState extends State<AdminRolesPage> {
  List<dynamic> allPlayers = []; 
  List<dynamic> filteredPlayers = []; 
  bool isLoading = true;
  String searchQuery = "";
  String filterRole = "Tutti"; 

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    try {
      // 1. Chiediamo a Supabase di ordinare i dati!
      final response = await Supabase.instance.client
          .from('players')
          .select('*')
          .order('role', ascending: true)      // Prima ordina per Ruolo (A, C, D, P)
          .order('sort_name', ascending: true); // Poi ordina per Cognome
      
      setState(() {
        allPlayers = response;
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Errore caricamento: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      filteredPlayers = allPlayers.where((p) {
        // Cerca sia nel nome completo che nel sort_name
        final matchesSearch = p['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || 
                              (p['sort_name']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
        final matchesRole = (filterRole == "Tutti" || p['role'] == filterRole);
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _updateRole(int playerId, String newRole) async {
    await Supabase.instance.client
        .from('players')
        .update({'role': newRole})
        .eq('id', playerId);
        
    _fetchPlayers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestione Rose")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Cerca giocatore...", 
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) { 
                searchQuery = value; 
                _applyFilters(); 
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["Tutti", "P", "D", "C", "A"].map((role) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(role),
                  selected: filterRole == role,
                  onSelected: (_) { 
                    setState(() { filterRole = role; _applyFilters(); }); 
                  },
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredPlayers.isEmpty 
                  ? const Center(child: Text("Nessun giocatore trovato"))
                  : ListView.builder(
                      itemCount: filteredPlayers.length,
                      itemBuilder: (context, index) {
                        final p = filteredPlayers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Naz: ${p['national_team']}"),
                            trailing: DropdownButton<String>(
                              value: p['role'],
                              underline: Container(),
                              items: ['P', 'D', 'C', 'A'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (val) => _updateRole(p['id'], val!),
                            ),
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