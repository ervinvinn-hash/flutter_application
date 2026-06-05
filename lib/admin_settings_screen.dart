import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool isLoading = true;
  bool isSaving = false;

  // Tutte le variabili del gioco (impostate di default con il segno corretto)
  double goalBonus = 3.0;
  double assistBonus = 1.0;
  double yellowMalus = -0.5; // Reso negativo di default
  double redMalus = -1.0; // Reso negativo di default
  double motmBonus = 0.5;
  double captainGoalBonus = 0.5;
  double cleanSheetBonus = 1.0;
  double penaltySavedBonus = 3.0;
  double penaltyMissedMalus = -3.0; // Reso negativo di default
  
  // NUOVE VARIABILI
  double ownGoalMalus = -1.0; // Reso negativo di default
  double benchGoalBonus = 1.0;
  double benchPenaltySavedBonus = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final data = await Supabase.instance.client.from('league_settings').select().eq('id', 1).maybeSingle();
      if (data != null) {
        setState(() {
          goalBonus = (data['goal_bonus'] as num).toDouble();
          assistBonus = (data['assist_bonus'] as num).toDouble();
          yellowMalus = (data['yellow_malus'] as num).toDouble();
          redMalus = (data['red_malus'] as num).toDouble();
          motmBonus = (data['motm_bonus'] as num).toDouble();
          captainGoalBonus = (data['captain_goal_bonus'] as num).toDouble();
          cleanSheetBonus = (data['clean_sheet_bonus'] as num).toDouble();
          penaltySavedBonus = (data['penalty_saved_bonus'] as num).toDouble();
          penaltyMissedMalus = (data['penalty_missed_malus'] as num).toDouble();
          
          ownGoalMalus = (data['own_goal_malus'] as num?)?.toDouble() ?? -1.0;
          benchGoalBonus = (data['bench_goal_bonus'] as num?)?.toDouble() ?? 1.0;
          benchPenaltySavedBonus = (data['bench_penalty_saved_bonus'] as num?)?.toDouble() ?? 1.0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => isSaving = true);
    try {
      await Supabase.instance.client.from('league_settings').upsert({
        'id': 1,
        'goal_bonus': goalBonus,
        'assist_bonus': assistBonus,
        'yellow_malus': yellowMalus,
        'red_malus': redMalus,
        'motm_bonus': motmBonus,
        'captain_goal_bonus': captainGoalBonus,
        'clean_sheet_bonus': cleanSheetBonus,
        'penalty_saved_bonus': penaltySavedBonus,
        'penalty_missed_malus': penaltyMissedMalus,
        'own_goal_malus': ownGoalMalus,
        'bench_goal_bonus': benchGoalBonus,
        'bench_penalty_saved_bonus': benchPenaltySavedBonus,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impostazioni aggiornate!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isSaving = false);
    }
  }

  Widget _buildCounter(String title, double value, Function(double) onChanged) {
    // Logica per il colore e il segno
    Color textColor = value > 0 ? Colors.green[700]! : (value < 0 ? Colors.red[700]! : Colors.black);
    String textValue = (value > 0 ? '+' : '') + value.toStringAsFixed(1);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28),
                  onPressed: () {
                    // Rimossa la restrizione "if (value > 0)", ora può andare in negativo
                    onChanged(value - 0.5);
                  },
                ),
                SizedBox(
                  width: 55, // Allargato per fare spazio al segno
                  child: Text(
                    textValue, 
                    textAlign: TextAlign.center, 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                  onPressed: () => onChanged(value + 0.5),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bonus / Malus'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Modifica i valori. Usa valori positivi per i bonus e negativi per i malus.', 
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                
                _buildCounter('Gol (⚽)', goalBonus, (v) => setState(() => goalBonus = v)),
                _buildCounter('Assist (👟)', assistBonus, (v) => setState(() => assistBonus = v)),
                _buildCounter('Giallo (🟨)', yellowMalus, (v) => setState(() => yellowMalus = v)),
                _buildCounter('Rosso (🟥)', redMalus, (v) => setState(() => redMalus = v)),
                _buildCounter('Uomo Partita (🌟)', motmBonus, (v) => setState(() => motmBonus = v)),
                _buildCounter('Autogol (🤦‍♂️)', ownGoalMalus, (v) => setState(() => ownGoalMalus = v)),
                
                const Divider(height: 30, thickness: 2),
                const Text('Bonus Speciali', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 10),
                
                _buildCounter('Gol Capitano (Ⓒ)', captainGoalBonus, (v) => setState(() => captainGoalBonus = v)),
                _buildCounter('Portiere Imbattuto (🛡️)', cleanSheetBonus, (v) => setState(() => cleanSheetBonus = v)),
                _buildCounter('Rigore Parato (🧤)', penaltySavedBonus, (v) => setState(() => penaltySavedBonus = v)),
                _buildCounter('Rigore Sbagliato (❌)', penaltyMissedMalus, (v) => setState(() => penaltyMissedMalus = v)),

                const Divider(height: 30, thickness: 2),
                const Text('Bonus Panchina', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 10),

                _buildCounter('Gol in Panchina (🪑⚽)', benchGoalBonus, (v) => setState(() => benchGoalBonus = v)),
                _buildCounter('Rig. Parato in Panchina (🪑🧤)', benchPenaltySavedBonus, (v) => setState(() => benchPenaltySavedBonus = v)),
                
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : _saveSettings,
                  icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save),
                  label: Text(isSaving ? 'Salvataggio...' : 'Salva nel Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
    );
  }
}