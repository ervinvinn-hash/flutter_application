// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminGroupsScreen extends StatefulWidget {
  const AdminGroupsScreen({super.key});

  @override
  State<AdminGroupsScreen> createState() => _AdminGroupsScreenState();
}

class _AdminGroupsScreenState extends State<AdminGroupsScreen> {
  bool isLoading = true;
  bool isSaving = false;
  List<Map<String, dynamic>> teams = [];

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final data = await Supabase.instance.client
          .from('fantasy_teams')
          .select('id, team_name, owner_name, group_name')
          .order('team_name'); // Ordina alfabeticamente
          
      setState(() {
        teams = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveGroups() async {
    setState(() => isSaving = true);
    try {
      for (var team in teams) {
        // Se il gruppo è '-', lo salviamo come null sul database (non assegnato)
        String? groupToSave = team['group_name'] == '-' ? null : team['group_name'];
        
        await Supabase.instance.client.from('fantasy_teams').update({
          'group_name': groupToSave,
        }).eq('id', team['id']);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gironi assegnati e salvati con successo!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Assegnazione Gironi'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red[50],
                  child: const Text(
                    'Inserisci l\'esito del sorteggio dal vivo. Scegli A o B per ogni squadra, poi premi "Salva" in basso per aggiornare i database e le classifiche.',
                    style: TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      
                      // Gestiamo i valori nulli se una squadra non è ancora assegnata
                      String currentGroup = team['group_name'] ?? '-';
                      if (currentGroup != 'A' && currentGroup != 'B') currentGroup = '-';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(team['team_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text(team['owner_name'] ?? 'Allenatore Ignoto', style: const TextStyle(color: Colors.grey)),
                          trailing: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: '-', label: Text('?')),
                              ButtonSegment(value: 'A', label: Text('A')),
                              ButtonSegment(value: 'B', label: Text('B')),
                            ],
                            selected: {currentGroup},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                team['group_name'] = newSelection.first;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : _saveGroups,
                      icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save),
                      label: const Text('SALVA GIRONI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}