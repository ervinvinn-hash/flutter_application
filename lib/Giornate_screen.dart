import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GiornateScreen extends StatefulWidget {
  const GiornateScreen({super.key});

  @override
  State<GiornateScreen> createState() => _GiornateScreenState();
}

class _GiornateScreenState extends State<GiornateScreen> {
  bool _isLoading = true;
  Map<int, List<Map<String, dynamic>>> _groupedMatches = {};

  @override
  void initState() {
    super.initState();
    _fetchCalendarData();
  }

  Future<void> _fetchCalendarData() async {
    try {
      final client = Supabase.instance.client;
      // Recupera tutte le partite ordinate per data e ora
      final data = await client.from('world_cup_matches').select().order('kickoff_time', ascending: true);

      Map<int, List<Map<String, dynamic>>> temporaryGroup = {};
      for (var match in data) {
        int mday = match['matchday'];
        temporaryGroup.putIfAbsent(mday, () => []).add(match);
      }

      setState(() {
        _groupedMatches = temporaryGroup;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento calendario: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  // Helper per estrarre la bandierina (antiproiettile!)
  String _getFlagOnly(String country) {
    if (country.isEmpty) return '🏳️';
    final String cleanCountry = country.trim().toLowerCase(); 

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Calendario Mondiali', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/sfondo.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : _groupedMatches.isEmpty
                  ? const Center(child: Text('Nessun match caricato nel database.', style: TextStyle(color: Colors.white70, fontSize: 16)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _groupedMatches.keys.length,
                      itemBuilder: (context, index) {
                        int matchday = _groupedMatches.keys.elementAt(index);
                        List<Map<String, dynamic>> matches = _groupedMatches[matchday]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9), 
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              iconColor: Colors.orange[800],
                              collapsedIconColor: Colors.black54,
                              title: Text(
                                'GIORNATA $matchday',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900], letterSpacing: 1),
                              ),
                              subtitle: Text('${matches.length} partite in programma', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                              children: matches.map((m) {
                                DateTime kickoff = DateTime.parse(m['kickoff_time']);
                                // CORRETTO QUI: Rimosso "intl." prima di DateFormat
                                String formattedDate = DateFormat('dd/MM — HH:mm').format(kickoff.toLocal()); 

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(m['home_team'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                                            const SizedBox(width: 6),
                                            Text(_getFlagOnly(m['home_team']), style: const TextStyle(fontSize: 18)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.orange[900]!]),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          formattedDate,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            Text(_getFlagOnly(m['away_team']), style: const TextStyle(fontSize: 18)),
                                            const SizedBox(width: 6),
                                            Text(m['away_team'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}