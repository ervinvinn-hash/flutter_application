import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerStat {
  final int id;
  final String role;
  final bool isStarter;
  final bool isBench;
  final double baseGrade;
  final int goalsScored;
  final int assists;
  final int yellowCards;
  final int redCards;
  final bool manOfTheMatch;
  final double coachMultiplier;
  final bool cleanSheet;
  final int penaltySaved;
  final int penaltyMissed;
  final int ownGoals; 

  PlayerStat({
    required this.id, required this.role, required this.isStarter, required this.isBench,
    required this.baseGrade, required this.goalsScored, required this.assists,
    required this.yellowCards, required this.redCards, required this.manOfTheMatch,
    required this.coachMultiplier, required this.cleanSheet,
    required this.penaltySaved, required this.penaltyMissed, required this.ownGoals
  });
}

class CalculatorService {
  
  // Legge TUTTE le impostazioni dal database
  Future<Map<String, double>> _getLeagueSettings() async {
    final data = await Supabase.instance.client.from('league_settings').select().eq('id', 1).single();
    return {
      'goal': (data['goal_bonus'] as num?)?.toDouble() ?? 3.0,
      'assist': (data['assist_bonus'] as num?)?.toDouble() ?? 1.0,
      'yellow': (data['yellow_malus'] as num?)?.toDouble() ?? -0.5,
      'red': (data['red_malus'] as num?)?.toDouble() ?? -1.0,
      'motm': (data['motm_bonus'] as num?)?.toDouble() ?? 0.5,
      'captain_goal': (data['captain_goal_bonus'] as num?)?.toDouble() ?? 0.5,
      'clean_sheet': (data['clean_sheet_bonus'] as num?)?.toDouble() ?? 1.0,
      'pen_saved': (data['penalty_saved_bonus'] as num?)?.toDouble() ?? 3.0,
      'pen_missed': (data['penalty_missed_malus'] as num?)?.toDouble() ?? -3.0,
      'own_goal': (data['own_goal_malus'] as num?)?.toDouble() ?? -1.0,
      'bench_goal': (data['bench_goal_bonus'] as num?)?.toDouble() ?? 1.0,
      'bench_pen': (data['bench_penalty_saved_bonus'] as num?)?.toDouble() ?? 1.0,
    };
  }

  Future<double> calculateTeamScore(List<PlayerStat> roster, PlayerStat? coach, PlayerStat? captain) async {
    final settings = await _getLeagueSettings();
    double total = 0.0;

    // --- 1. GESTIONE SOSTITUZIONI AUTOMATICHE ---
    // Titolari che hanno preso voto
    Set<int> effectiveStarters = roster.where((p) => p.isStarter && p.baseGrade > 0).map((p) => p.id).toSet();
    // Titolari senza voto (s.v.)
    List<PlayerStat> missingStarters = roster.where((p) => p.isStarter && p.baseGrade == 0).toList();
    // Panchinari che hanno preso voto
    List<PlayerStat> availableBench = roster.where((p) => p.isBench && p.baseGrade > 0).toList();
    
    int subsMade = 0;

    // Procediamo ai cambi (Massimo 3)
    for (var missing in missingStarters) {
      if (subsMade >= 3) break; 
      
      // Cerca il primo panchinaro disponibile con lo STESSO RUOLO
      int benchIndex = availableBench.indexWhere((b) => b.role == missing.role);
      if (benchIndex != -1) {
        PlayerStat sub = availableBench[benchIndex];
        effectiveStarters.add(sub.id); // Entra in campo
        availableBench.removeAt(benchIndex); // Rimuovi dai disponibili
        subsMade++;
      }
    }

    // --- 2. CALCOLO PUNTEGGI ---
    for (var p in roster) {
      // Se è un titolare effettivo (originale o subentrato)
      if (effectiveStarters.contains(p.id)) {
        double pScore = p.baseGrade;

        // Malus e Bonus Standard
        pScore += (p.goalsScored * settings['goal']!);
        pScore += (p.assists * settings['assist']!);
        pScore += (p.yellowCards * settings['yellow']!);
        pScore += (p.redCards * settings['red']!);
        pScore += (p.ownGoals * settings['own_goal']!); 
        pScore += (p.penaltySaved * settings['pen_saved']!);
        pScore += (p.penaltyMissed * settings['pen_missed']!);
        
        // Bonus Speciali
        if (p.manOfTheMatch) pScore += settings['motm']!;
        if (p.cleanSheet && p.role == 'P') pScore += settings['clean_sheet']!;
        
        // Bonus Capitano (si applica solo se il capitano segna)
        if (p == captain && p.goalsScored > 0) {
          pScore += (p.goalsScored * settings['captain_goal']!);
        }

        total += pScore;
      } 
      // Se è rimasto in panchina (non è subentrato)
      else if (p.isBench && !effectiveStarters.contains(p.id)) {
        // Applica le regole speciali per i bonus "dalla panchina" stabiliti nell'Admin
        if (p.goalsScored > 0) total += (p.goalsScored * settings['bench_goal']!);
        if (p.penaltySaved > 0) total += (p.penaltySaved * settings['bench_pen']!);
      }
    }

    // Aggiungi modificatore allenatore (se presente)
    if (coach != null) total += coach.coachMultiplier; 
    
    return total;
  }

  Map<String, int> calculateMatchResult(double homeScore, double awayScore, bool isKnockout) {
    int homeGoals = _calculateGoalsFromScore(homeScore);
    int awayGoals = _calculateGoalsFromScore(awayScore);

    // --- REGOLA FASE A ELIMINAZIONE DIRETTA ---
    // Se c'è un pareggio ai gol, passa chi ha il punteggio decimale assoluto più alto
    if (isKnockout && homeGoals == awayGoals) {
      if (homeScore > awayScore) {
        homeGoals++;
      } else if (awayScore > homeScore) {
        awayGoals++;
      }
    }

    return {'homeGoals': homeGoals, 'awayGoals': awayGoals};
  }

  // REGOLE UFFICIALI FASCE FANTACALCIO (Scaglioni di 6 punti a partire da 66)
  int _calculateGoalsFromScore(double score) {
    if (score < 66) return 0;
    if (score < 72) return 1;
    if (score < 78) return 2;
    if (score < 84) return 3;
    if (score < 90) return 4;
    if (score < 96) return 5;
    if (score < 102) return 6;
    return 7;
  }
}