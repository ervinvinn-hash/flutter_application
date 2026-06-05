import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; 
import 'roster_screen.dart';
import 'rules_screen.dart';
import 'lineup_screen.dart'; 
import 'standings_screen.dart';
import 'calendar_screen.dart';
import 'admin_votes_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_groups_screen.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  await Supabase.initialize(
    url: 'https://wsyvhkbtlpybekzmpewk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzeXZoa2J0bHB5YmVrem1wZXdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNzE4OTAsImV4cCI6MjA5NDk0Nzg5MH0._vgvmyXsNsMPBAjQqaMVMLL_SFz9T3Vhwp0bjg4ukds',
  );

  final prefs = await SharedPreferences.getInstance();
  final String? savedTeamId = prefs.getString('teamId');
  final String? savedTeamName = prefs.getString('teamName');
  final bool isAdmin = prefs.getBool('isAdmin') ?? false;

  runApp(FantaMondialeApp(
    initialTeamId: savedTeamId,
    initialTeamName: savedTeamName,
    isAdmin: isAdmin,
  ));
}

class FantaMondialeApp extends StatelessWidget {
  final String? initialTeamId;
  final String? initialTeamName;
  final bool isAdmin;

  const FantaMondialeApp({super.key, this.initialTeamId, this.initialTeamName, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FantaMondiale',
      theme: ThemeData(
        // Tema Globale Moderno
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
        fontFamily: 'Roboto', // Usa un font di sistema pulito
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
      ),
      home: initialTeamId == null 
        ? const LoginScreen() 
        : DashboardScreen(teamId: initialTeamId!, teamName: initialTeamName!, isAdmin: isAdmin),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final String teamId;
  final String teamName;
  final bool isAdmin;

  const DashboardScreen({super.key, required this.teamId, required this.teamName, required this.isAdmin});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Widget _adminMenuButton(BuildContext context, IconData icon, String label, Widget screen) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        Navigator.pop(context); 
        Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
      },
    );
  }

  void _showAdminPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const Text('Pannello di Controllo', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 20),
                _adminMenuButton(ctx, Icons.admin_panel_settings, 'Gestione Voti', const AdminVotesScreen()),
                const SizedBox(height: 10),
                _adminMenuButton(ctx, Icons.schema, 'Assegnazione Gironi', const AdminGroupsScreen()),
                const SizedBox(height: 10),
                _adminMenuButton(ctx, Icons.edit_document, 'Modifica Regolamento', const RulesScreen(isAdmin: true)),
                const SizedBox(height: 10),
                _adminMenuButton(ctx, Icons.tune, 'Modificatori Calcolo', const AdminSettingsScreen()),
              ],
            ),
          ),
        );
      }
    );
  }

  // --- WIDGET PERSONALIZZATO PER I PULSANTI A GRIGLIA ---
  Widget _buildGridButton(BuildContext context, String title, IconData icon, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7), // Effetto vetro leggero
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: Colors.green[800]),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // L'immagine va anche sotto l'app bar!
      appBar: AppBar(
        title: const Text('FantaMondiale VIP', style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent, // AppBar Trasparente
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 0, 0, 0)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Esci',
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Container(
        // SFONDO STADIO
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/sfondo.png'), // Immagine stadio
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken), // Scurisce l'immagine per far leggere il testo
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( 
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // --- CARD LA TUA SQUADRA (Con Gradiente Oro/Verde) ---
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color.fromARGB(255, 226, 193, 1), const Color.fromARGB(255, 225, 102, 1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      const Text('LA TUA SQUADRA', style: TextStyle(fontSize: 14, color: Colors.white70, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text(teamName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_soccer, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Pronti per il mondiale!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 12.0),
                  child: Text('MENU PRINCIPALE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),

                // --- GRIGLIA PULSANTI MODERNA ---
                GridView.count(
                  shrinkWrap: true, // Importante dentro un SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // Disabilita lo scroll interno alla griglia
                  crossAxisCount: 2, // 2 colonne
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1, // Rende i riquadri leggermente rettangolari
                  children: [
                    _buildGridButton(context, 'Schiera\nFormazione', Icons.sports_soccer, TeamLineupScreen(teamId: teamId, teamName: teamName)),
                    _buildGridButton(context, 'Mercato e\nRosa', Icons.shopping_cart_outlined, RosterScreen(teamId: teamId)),
                    _buildGridButton(context, 'Calendario\nRisultati', Icons.calendar_month, const CalendarScreen()),
                    _buildGridButton(context, 'Classifica\nLega', Icons.emoji_events_outlined, StandingsScreen(teamId: teamId)),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Bottone Regolamento (A larghezza piena sotto la griglia)
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RulesScreen(isAdmin: false))),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book, color: Colors.blue[800]),
                        const SizedBox(width: 12),
                        const Text('Regolamento Lega', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                
                // --- SEZIONE ADMIN ---
                if (isAdmin) ...[
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.red[900]!, Colors.redAccent[700]!]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAdminPanel(context),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield, color: Colors.white),
                              SizedBox(width: 12),
                              Text('PANNELLO AMMINISTRATORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
