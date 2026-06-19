import 'dart:async';
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
import 'admin_trades_screen.dart';
import 'trade_center_screen.dart';
import 'Giornate_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
        fontFamily: 'Roboto', 
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

class DashboardScreen extends StatefulWidget {
  final String teamId;
  final String teamName;
  final bool isAdmin;

  const DashboardScreen({super.key, required this.teamId, required this.teamName, required this.isAdmin});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final RealtimeChannel _tradeChannel;
  
  // --- VARIABILE PER IL PALLINO ROSSO DELLE NOTIFICHE ---
  bool hasNewNotifications = false;

  @override
  void initState() {
    super.initState();
    _setupRealtimeNotifications();
  }

  void _setupRealtimeNotifications() {
    _tradeChannel = Supabase.instance.client.channel('public:pending_trades');
    
    _tradeChannel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'pending_trades',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord['receiver_team_id'] == widget.teamId && mounted) {
          // Accende la campanellina quando arriva uno scambio!
          setState(() {
            hasNewNotifications = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔔 MERCATO: Hai ricevuto una nuova proposta di scambio!'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            )
          );
        }
      }
    ).onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'pending_trades',
      callback: (payload) async {
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;
        
        if (newRecord['status'] == 'accepted' && oldRecord['status'] != 'accepted') {
          await _showDetailedTradeNotification(newRecord);
        }
      }
    ).subscribe();
  }

  Future<void> _showDetailedTradeNotification(Map<String, dynamic> record) async {
    try {
      final client = Supabase.instance.client;

      final senderTeamData = await client.from('fantasy_teams').select('team_name').eq('id', record['sender_team_id']).maybeSingle();
      final receiverTeamData = await client.from('fantasy_teams').select('team_name').eq('id', record['receiver_team_id']).maybeSingle();
      
      String senderTeam = senderTeamData?['team_name'] ?? 'Squadra Ignota';
      String receiverTeam = receiverTeamData?['team_name'] ?? 'Squadra Ignota';

      List<dynamic> senderPlayerIds = record['sender_player_ids'];
      final senderPlayersData = await client.from('players').select('name').inFilter('id', senderPlayerIds);
      String senderPlayers = senderPlayersData.map((p) => p['name']).join(', ');

      List<dynamic> receiverPlayerIds = record['receiver_player_ids'];
      final receiverPlayersData = await client.from('players').select('name').inFilter('id', receiverPlayerIds);
      String receiverPlayers = receiverPlayersData.map((p) => p['name']).join(', ');

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false, 
          builder: (BuildContext ctx) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF141E30), Color(0xFF243B55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.amberAccent, width: 2), 
                  boxShadow: [
                    BoxShadow(color: Colors.amberAccent.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5, offset: const Offset(0, 0)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 28),
                        const Expanded(
                          child: Text(
                            ' SCAMBIO ', 
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 28),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.amberAccent, thickness: 1, height: 30),
                    const SizedBox(height: 10),
                    
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.handshake, color: Colors.white.withValues(alpha: 0.1), size: 90), 
                        const Icon(Icons.handshake, color: Colors.white, size: 75), 
                        const Positioned(
                          top: 0, right: 0,
                          child: Icon(Icons.star, color: Colors.amberAccent, size: 24), 
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70), 
                        children: [
                          TextSpan(text: senderTeam, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 20)),
                          const TextSpan(text: '\nha ceduto\n'),
                          TextSpan(text: senderPlayers, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const TextSpan(text: '\n\na\n'),
                          TextSpan(text: receiverTeam, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 20)),
                          const TextSpan(text: '\n\nin cambio di\n'),
                          TextSpan(text: receiverPlayers, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black87,
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      ),
                      child: const Text('CHIUDI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    } catch (e) {
      debugPrint('Errore notifica dettagliata: $e');
    }
  }
  
  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_tradeChannel); 
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  // --- PANNELLO NOTIFICHE ---
  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_active, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Centro Notifiche', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                const Divider(height: 30),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Per vedere i dettagli delle tue proposte di scambio in sospeso, accedi alla sezione "Centro Scambi" dalla schermata principale.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.4),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TradeCenterScreen(myTeamId: widget.teamId)));
                  },
                  icon: const Icon(Icons.sync_alt),
                  label: const Text('VAI AL CENTRO SCAMBI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      }
    );
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
                _adminMenuButton(ctx, Icons.swap_horiz, 'Scambi tra Squadre', const AdminTradesScreen()), 
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

  Widget _buildGridButton(BuildContext context, String title, IconData icon, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: Colors.green[800]),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[800], height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        // --- LA NUOVA CAMPANELLINA A SINISTRA CON PALLINO ROSSO ---
        leading: IconButton(
          tooltip: 'Notifiche',
          onPressed: () {
            // Spegne il pallino rosso quando ci clicchi
            setState(() => hasNewNotifications = false);
            _showNotificationsPanel();
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications, color: Colors.white, size: 28),
              if (hasNewNotifications)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.transparent, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: const Text('FantaMondiale', style: TextStyle(color: Color.fromRGBO(255, 255, 255, 1), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent, 
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
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/sfondo.png'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken), 
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView( 
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color.fromARGB(255, 226, 193, 1), Color.fromARGB(255, 225, 102, 1)],
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
                      Text(widget.teamName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
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

                GridView.count(
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(), 
                  crossAxisCount: 2, 
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6, 
                  children: [
                    LineupGridButton(teamId: widget.teamId, teamName: widget.teamName),
                    _buildGridButton(context, 'Mercato e\nRosa', Icons.shopping_cart_outlined, RosterScreen(teamId: widget.teamId)),
                    _buildGridButton(context, 'Calendario\nRisultati', Icons.calendar_month, const CalendarScreen()),
                    _buildGridButton(context, 'Classifica\nLega', Icons.emoji_events_outlined, StandingsScreen(teamId: widget.teamId)),
                    _buildGridButton(context, 'Centro\nScambi', Icons.sync_alt, TradeCenterScreen(myTeamId: widget.teamId)),
                    _buildGridButton(context, 'Regolamento\nLega', Icons.menu_book, const RulesScreen(isAdmin: false)),
                  ],
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const GiornateScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange[800]!, Colors.orange[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.4), 
                            blurRadius: 8, 
                            offset: const Offset(0, 4)
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'CALENDARIO MONDIALI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (widget.isAdmin) ...[
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

// ============================================================================
// WIDGET: PULSANTE GRIGLIA CON COUNTDOWN INTEGRATO
// ============================================================================
class LineupGridButton extends StatefulWidget {
  final String teamId;
  final String teamName;

  const LineupGridButton({super.key, required this.teamId, required this.teamName});

  @override
  State<LineupGridButton> createState() => _LineupGridButtonState();
}

class _LineupGridButtonState extends State<LineupGridButton> {
  DateTime? _lockTime;
  DateTime? _unlockTime;
  Timer? _timer;
  
  String _countdownText = "";
  bool _isLocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeadline();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDeadline() async {
    try {
      final client = Supabase.instance.client;
      final serverTimeData = await client.rpc('get_server_time').catchError((_) => null);
      DateTime serverNow = DateTime.now();
      if (serverTimeData != null) {
        serverNow = DateTime.parse(serverTimeData.toString()).toLocal();
      }

      final matchesData = await client.from('world_cup_matches').select().order('kickoff_time', ascending: true);
      
      int currentMatchday = 1;
      try {
        var upcomingMatch = matchesData.firstWhere((m) {
          DateTime kickoffLocal = DateTime.parse(m['kickoff_time']).toLocal();
          return kickoffLocal.add(const Duration(hours: 2)).isAfter(serverNow);
        });
        currentMatchday = upcomingMatch['matchday'];
      } catch (e) {
        if (matchesData.isNotEmpty) currentMatchday = matchesData.last['matchday'];
      }

      final currentRoundMatches = matchesData.where((m) => m['matchday'] == currentMatchday).toList();
      if (currentRoundMatches.isNotEmpty) {
        List<DateTime> matchDates = currentRoundMatches
            .map((m) => DateTime.parse(m['kickoff_time']).toLocal())
            .toList();
        matchDates.sort(); 
        
        DateTime firstMatch = matchDates.first;
        DateTime lastMatch = matchDates.last;
        
        _lockTime = firstMatch.subtract(const Duration(minutes: 15));
        _unlockTime = lastMatch.add(const Duration(hours: 2));
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _lockTime == null || _unlockTime == null) return;

      DateTime now = DateTime.now();

      if (now.isAfter(_lockTime!) && now.isBefore(_unlockTime!)) {
        setState(() {
          _isLocked = true;
          _countdownText = "🔒 IN CORSO";
        });
      } else if (now.isBefore(_lockTime!)) {
        Duration diff = _lockTime!.difference(now);
        
        int days = diff.inDays;
        int hours = diff.inHours % 24;
        int minutes = diff.inMinutes % 60;
        int seconds = diff.inSeconds % 60;

        String timeStr = '';
        if (days > 0) {
          timeStr = "$days gg ${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m";
        } else {
          timeStr = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        }

        setState(() {
          _isLocked = false;
          _countdownText = timeStr;
        });
      } else {
        timer.cancel();
        _fetchDeadline(); 
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => TeamLineupScreen(teamId: widget.teamId, teamName: widget.teamName)
          )
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isLocked ? Colors.red[50] : Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        _isLocked ? Icons.lock : Icons.sports_soccer, 
                        size: 26, 
                        color: _isLocked ? Colors.red[800] : Colors.green[800]
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Schiera\nFormazione',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[800], height: 1.1),
                ),
              ],
            ),
            if (!_isLoading && _countdownText.isNotEmpty)
              Positioned(
                bottom: 8,
                child: Text(
                  _countdownText,
                  style: TextStyle(
                    color: _isLocked ? Colors.red[800] : Colors.orange[800], 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}