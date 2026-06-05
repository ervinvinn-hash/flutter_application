import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RulesScreen extends StatefulWidget {
  final bool isAdmin;
  const RulesScreen({super.key, this.isAdmin = false});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  bool isLoading = true;
  bool isSaving = false;
  Map<String, double> settings = {};
  final TextEditingController _rulesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final settingsData = await Supabase.instance.client.from('league_settings').select().eq('id', 1).maybeSingle();
      final rulesData = await Supabase.instance.client.from('league_rules').select().eq('id', 1).maybeSingle();

      setState(() {
        if (settingsData != null) {
          settings = {
            'goal': (settingsData['goal_bonus'] as num?)?.toDouble() ?? 3.0,
            'assist': (settingsData['assist_bonus'] as num?)?.toDouble() ?? 1.0,
            'yellow': (settingsData['yellow_malus'] as num?)?.toDouble() ?? -0.5,
            'red': (settingsData['red_malus'] as num?)?.toDouble() ?? -1.0,
            'motm': (settingsData['motm_bonus'] as num?)?.toDouble() ?? 0.5,
            'own_goal': (settingsData['own_goal_malus'] as num?)?.toDouble() ?? -1.0,
            'captain_goal': (settingsData['captain_goal_bonus'] as num?)?.toDouble() ?? 0.5,
            'clean_sheet': (settingsData['clean_sheet_bonus'] as num?)?.toDouble() ?? 1.0,
            'penalty_saved': (settingsData['penalty_saved_bonus'] as num?)?.toDouble() ?? 3.0,
            'penalty_missed': (settingsData['penalty_missed_malus'] as num?)?.toDouble() ?? -3.0,
            'bench_goal': (settingsData['bench_goal_bonus'] as num?)?.toDouble() ?? 1.0,
            'bench_penalty': (settingsData['bench_penalty_saved_bonus'] as num?)?.toDouble() ?? 1.0,
          };
        }
        if (rulesData != null && rulesData['content'] != null) {
          _rulesController.text = rulesData['content'];
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveRulesText() async {
    setState(() => isSaving = true);
    try {
      await Supabase.instance.client.from('league_rules').upsert({'id': 1, 'content': _rulesController.text});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Regolamento salvato!'), backgroundColor: Colors.orange[800])); // Cambiato in arancio
    } finally {
      setState(() => isSaving = false);
    }
  }

  Widget _buildScoreChip(String label, double? value) {
    if (value == null) return const SizedBox.shrink();
    bool isPositive = value > 0;
    bool isNeutral = value == 0;
    
    // Palette aggiornata ai toni dell'arancio per i bonus
    Color bgColor = isPositive ? Colors.orange[50]!.withValues(alpha: 0.9) : (isNeutral ? Colors.grey[200]!.withValues(alpha: 0.9) : Colors.red[50]!.withValues(alpha: 0.9));
    Color textColor = isPositive ? Colors.orange[900]! : (isNeutral ? Colors.black87 : Colors.red[800]!);
    String textValue = (isPositive ? '+' : '') + value.toStringAsFixed(1);

    return Container(
      width: MediaQuery.of(context).size.width * 0.42,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
          Text(textValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/sfondo.png'), // Aggiornato a png in linea col main
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Mantiene visibile lo sfondo
        appBar: AppBar(
          title: Text(widget.isAdmin ? 'Admin: Modifica Regole' : 'Regolamento', 
            style: const TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontWeight: FontWeight.bold, letterSpacing: 1.2)), // Testo nero come nel main
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color.fromRGBO(255, 255, 255, 1)), // Icone nere come nel main
        ),
        body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('VALORI BONUS E MALUS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
                  const SizedBox(height: 12),
                  
                  Card(
                    elevation: 6,
                    color: Colors.white.withValues(alpha: 0.9), // Effetto vetro mantenuto
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Statistiche Standard', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            children: [
                              _buildScoreChip('Gol ⚽', settings['goal']),
                              _buildScoreChip('Assist 👟', settings['assist']),
                              _buildScoreChip('Giallo 🟨', settings['yellow']),
                              _buildScoreChip('Rosso 🟥', settings['red']),
                              _buildScoreChip('Autogol 🤦‍♂️', settings['own_goal']),
                              _buildScoreChip('MVP 🌟', settings['motm']),
                            ],
                          ),
                          const Divider(height: 30),
                          const Text('Regole Speciali', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            children: [
                              _buildScoreChip('Gol Capitano Ⓒ', settings['captain_goal']),
                              _buildScoreChip('Port. Imbattuto 🛡️', settings['clean_sheet']),
                              _buildScoreChip('Rigore Parato 🧤', settings['penalty_saved']),
                              _buildScoreChip('Rigore Sbagl. ❌', settings['penalty_missed']),
                            ],
                          ),
                          const Divider(height: 30),
                          const Text('Regole Panchina', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            children: [
                              _buildScoreChip('Gol in Panchina', settings['bench_goal']),
                              _buildScoreChip('Rigore in Panch.', settings['bench_penalty']),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white54, thickness: 1),
                  const SizedBox(height: 20),

                  const Text('REGOLAMENTO DELLA LEGA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
                  const SizedBox(height: 12),

                  if (widget.isAdmin) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange[50]?.withValues(alpha: 0.9), // Sfondo in tono ambrato
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange), // Bordo arancio
                      ),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _rulesController,
                        maxLines: null,
                        minLines: 10,
                        decoration: const InputDecoration(hintText: 'Scrivi qui il regolamento della lega...', border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: isSaving ? null : _saveRulesText,
                      icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save),
                      label: const Text('SALVA TESTO REGOLAMENTO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red[800], // Il bottone di salvataggio admin rimane rosso per coerenza visiva
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9), // Effetto vetro
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                      ),
                      child: Text(
                        _rulesController.text.isEmpty ? 'Nessun regolamento disponibile.' : _rulesController.text,
                        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }
}