import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = true;
  bool isLoggingIn = false;
  List<Map<String, dynamic>> teams = [];
  Map<String, dynamic>? selectedTeam;
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final data = await Supabase.instance.client
          .from('fantasy_teams')
          .select('id, team_name, pin, is_admin')
          .order('team_name');
      setState(() {
        teams = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  Future<void> _login() async {
    if (selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona la tua squadra!'), backgroundColor: Colors.orange));
      return;
    }

    String enteredPin = _pinController.text.trim();
    String correctPin = selectedTeam!['pin']?.toString() ?? '0000';

    if (enteredPin == correctPin) {
      setState(() => isLoggingIn = true);
      
      // Salvataggio permanente nel telefono
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teamId', selectedTeam!['id']);
      await prefs.setString('teamName', selectedTeam!['team_name']);
      await prefs.setBool('isAdmin', selectedTeam!['is_admin'] ?? false);

      if (!mounted) return;
      // Reindirizza alla Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            teamId: selectedTeam!['id'],
            teamName: selectedTeam!['team_name'],
            isAdmin: selectedTeam!['is_admin'] ?? false,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('PIN errato! Riprova.'), backgroundColor: Colors.red[800]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/sfondo.png'), // Lo stesso sfondo VIP
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Fa vedere lo sfondo
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icona Coppa Oro
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.emoji_events, size: 90, color: Colors.amber),
                  ),
                  const SizedBox(height: 20),
                  const Text('FantaMondiale', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0)),
                  const SizedBox(height: 8),
                  const Text('Accedi alla tua squadra', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 1.2)),
                  const SizedBox(height: 40),
                  
                  if (isLoading)
                    const Center(child: CircularProgressIndicator(color: Colors.orange))
                  else ...[
                    Card(
                      elevation: 10,
                      color: Colors.white.withOpacity(0.9), // Effetto vetro
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            DropdownButtonFormField<Map<String, dynamic>>(
                              decoration: InputDecoration(
                                labelText: 'Seleziona Squadra',
                                labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[800]!, width: 2), borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.5),
                              ),
                              dropdownColor: Colors.white.withOpacity(0.95),
                              icon: Icon(Icons.arrow_drop_down_circle, color: Colors.orange[800]),
                              items: teams.map((team) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: team, 
                                  child: Text(team['team_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => selectedTeam = val),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold, color: Colors.black87),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: 'PIN DI ACCESSO',
                                labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, letterSpacing: 1),
                                prefixIcon: Icon(Icons.lock, color: Colors.orange[800]),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange[800]!, width: 2), borderRadius: BorderRadius.circular(16)),
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: isLoggingIn ? null : _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(55),
                                backgroundColor: Colors.orange[800], // Pulsante VIP
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 5,
                              ),
                              child: isLoggingIn 
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                                : const Text('ENTRA IN CAMPO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}