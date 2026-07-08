import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminRealMatchesScreen extends StatefulWidget {
  const AdminRealMatchesScreen({super.key});

  @override
  State<AdminRealMatchesScreen> createState() => _AdminRealMatchesScreenState();
}

class _AdminRealMatchesScreenState extends State<AdminRealMatchesScreen> {
  bool isLoading = true;
  
  // Mappa per salvare lo stato delle 8 partite (4 Quarti, 2 Semi, 2 Finali)
  Map<String, Map<String, dynamic>> realMatches = {};

  final List<String> matchKeys = [
    'QF1', 'QF2', 'QF3', 'QF4', // Quarti
    'SF1', 'SF2',               // Semifinali
    'F1', 'F3'                  // Finale 1/2 e Finale 3/4
  ];

  @override
  void initState() {
    super.initState();
    _fetchRealMatches();
  }

  Future<void> _fetchRealMatches() async {
    setState(() => isLoading = true);
    try {
      // Scarica le partite del mondiale reale dal DB (le identifichiamo con un "match_code" che aggiungeremo)
      final data = await Supabase.instance.client.from('world_cup_matches').select();
      
      Map<String, Map<String, dynamic>> loaded = {};
      for (var row in data) {
        String? code = row['match_code'];
        if (code != null && matchKeys.contains(code)) {
          loaded[code] = row;
        }
      }

      setState(() {
        realMatches = loaded;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      setState(() => isLoading = false);
    }
  }

  void _showMatchEditor(String code, String titleLabel) {
    var match = realMatches[code];
    
    TextEditingController homeCtrl = TextEditingController(text: match?['home_team'] ?? '');
    TextEditingController awayCtrl = TextEditingController(text: match?['away_team'] ?? '');
    
    // Suggeriamo la giornata in base al turno (es. Quarti = 4, Semi = 5, Finali = 6)
    int defaultDay = code.startsWith('QF') ? 4 : (code.startsWith('SF') ? 5 : 6);
    int matchDay = match?['matchday'] ?? defaultDay;

    DateTime? selectedDate = match?['kickoff_time'] != null ? DateTime.parse(match!['kickoff_time']).toLocal() : DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              // ✅ RIGA CORRETTA:
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 30),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Modifica $titleLabel', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    const Divider(height: 30),
                    
                    Row(
                      children: [
                        Expanded(child: TextField(controller: homeCtrl, decoration: const InputDecoration(labelText: 'Squadra 1 (Casa)', border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: awayCtrl, decoration: const InputDecoration(labelText: 'Squadra 2 (Trasferta)', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // IMPOSTAZIONE DATA E ORA (Fondamentale per il blocco formazioni)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[200]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Orario Calcio d\'Inizio (Blocca Formazioni)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(DateFormat('dd/MM/yyyy').format(selectedDate!)),
                                  onPressed: () async {
                                    final d = await showDatePicker(context: context, initialDate: selectedDate!, firstDate: DateTime(2024), lastDate: DateTime(2030));
                                    if (d != null) setModalState(() => selectedDate = DateTime(d.year, d.month, d.day, selectedTime.hour, selectedTime.minute));
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.access_time),
                                  label: Text(selectedTime.format(context)),
                                  onPressed: () async {
                                    final t = await showTimePicker(context: context, initialTime: selectedTime);
                                    if (t != null) {
                                      setModalState(() {
                                        selectedTime = t;
                                        selectedDate = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, t.hour, t.minute);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<int>(
                      value: matchDay,
                      decoration: const InputDecoration(labelText: 'Giornata Fanta (Es. 4 per i Quarti)', border: OutlineInputBorder()),
                      items: List.generate(6, (i) => i + 4).map((val) => DropdownMenuItem(value: val, child: Text('Giornata $val'))).toList(),
                      onChanged: (v) => setModalState(() => matchDay = v!),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _saveMatch(
                          id: match?['id'],
                          code: code,
                          home: homeCtrl.text.isEmpty ? 'TBD' : homeCtrl.text,
                          away: awayCtrl.text.isEmpty ? 'TBD' : awayCtrl.text,
                          kickoff: selectedDate!.toUtc().toIso8601String(), // Salva in UTC per coerenza col server
                          matchday: matchDay,
                        );
                      },
                      child: const Text('SALVA PARTITA REALE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _saveMatch({int? id, required String code, required String home, required String away, required String kickoff, required int matchday}) async {
    try {
      final client = Supabase.instance.client;
      final payload = {
        'match_code': code, // Usiamo questo per riconoscere lo slot nel tabellone
        'home_team': home,
        'away_team': away,
        'kickoff_time': kickoff,
        'matchday': matchday,
      };

      if (id == null) {
        await client.from('world_cup_matches').insert(payload);
      } else {
        await client.from('world_cup_matches').update(payload).eq('id', id);
      }
      
      _fetchRealMatches();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiornato! Formazioni ricalibrate.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  // --- WIDGET GRAFICI DEL TABELLONE ---

  Widget _buildMatchBox(String code, String label) {
    var match = realMatches[code];
    String home = match?['home_team'] ?? '???';
    String away = match?['away_team'] ?? '???';
    String time = match?['kickoff_time'] != null ? DateFormat('dd/MM HH:mm').format(DateTime.parse(match!['kickoff_time']).toLocal()) : 'Da definire';

    return GestureDetector(
      onTap: () => _showMatchEditor(code, label),
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: code.startsWith('F1') ? Colors.amber : Colors.blue[800]!, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 2))],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: code.startsWith('F1') ? Colors.amber : Colors.blue[800], borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
              child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: code.startsWith('F1') ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                children: [
                  Text(home, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Text('vs', style: TextStyle(color: Colors.grey, fontSize: 10))),
                  Text(away, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.blue[900]),
                  const SizedBox(width: 4),
                  Text(time, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage('assets/sfondo.png'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken)),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
          title: const Text('Mondiale Reale', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [IconButton(icon: const Icon(Icons.info_outline), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modifica le date per aggiornare il blocco formazioni automaticamente!'))))],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : InteractiveViewer(
                constrained: false, // Permette lo scroll libero in tutte le direzioni
                minScale: 0.5,
                maxScale: 2.0,
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  // Mettiamo un'altezza minima per tenere il tabellone centrato
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 100),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // COLONNA 1: QUARTI DI FINALE
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMatchBox('QF1', 'QUARTO 1'),
                          const SizedBox(height: 20),
                          _buildMatchBox('QF2', 'QUARTO 2'),
                          const SizedBox(height: 60), // Spazio centrale
                          _buildMatchBox('QF3', 'QUARTO 3'),
                          const SizedBox(height: 20),
                          _buildMatchBox('QF4', 'QUARTO 4'),
                        ],
                      ),
                      const SizedBox(width: 40), // Distanza tra colonne
                      
                      // COLONNA 2: SEMIFINALI
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMatchBox('SF1', 'SEMIFINALE 1'),
                          const SizedBox(height: 120), // Spazio maggiore per centrarle rispetto ai quarti
                          _buildMatchBox('SF2', 'SEMIFINALE 2'),
                        ],
                      ),
                      const SizedBox(width: 40),
                      
                      // COLONNA 3: FINALI
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMatchBox('F1', 'FINALE 1°/2° POSTO 🏆'),
                          const SizedBox(height: 40),
                          _buildMatchBox('F3', 'FINALE 3°/4° POSTO 🥉'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}