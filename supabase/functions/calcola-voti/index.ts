// Importa i moduli necessari per Supabase Edge Functions
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Configura i client di Supabase
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const supabase = createClient(supabaseUrl, supabaseKey)

// Funzione per la pausa di sicurezza
const delay = (ms: number) => new Promise(res => setTimeout(res, ms));

// Funzione per pulire e confrontare i nomi dei giocatori (Identica a quella su Flutter)
const normalizeName = (name: string) => {
  return name.toLowerCase()
    .replace(/[áà]/g, 'a').replace(/[éè]/g, 'e')
    .replace(/[íì]/g, 'i').replace(/[óò]/g, 'o')
    .replace(/[úù]/g, 'u').replace(/ñ/g, 'n').replace(/ç/g, 'c')
    .replace(/[-.']/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
};

serve(async (req) => {
  try {
    const apiKey = Deno.env.get('API_KEY') ?? ''

    // 1. TRUCCO DELLE 6 ORE (Per risolvere il "Bug di Mezzanotte")
    const now = new Date();
    now.setHours(now.getHours() - 6);
    const targetDate = now.toISOString().split('T')[0];

    console.log(`Avvio sincronizzazione voti per la data calcistica: ${targetDate}`);

    // 2. RECUPERA IL MATCHDAY (Giornata) DAL DATABASE
    let currentMatchday = 1;
    const { data: matches } = await supabase
      .from('world_cup_matches')
      .select('matchday, kickoff_time')
      .order('kickoff_time', { ascending: true });
      
    if (matches && matches.length > 0) {
      // Cerca una partita che si gioca nella data di oggi
      const todayMatch = matches.find((m: any) => m.kickoff_time.startsWith(targetDate));
      if (todayMatch) {
        currentMatchday = todayMatch.matchday;
      } else {
        // Se non trova partite oggi, prende la prima futura disponibile
        const targetDateObj = new Date(targetDate);
        const futureMatch = matches.find((m: any) => new Date(m.kickoff_time) >= targetDateObj);
        currentMatchday = futureMatch ? futureMatch.matchday : matches[matches.length - 1].matchday;
      }
    }
    console.log(`Matchday calcolato: Giornata ${currentMatchday}`);

    // 3. RECUPERA I GIOCATORI LOCALI (Necessario per trovare l'ID corretto)
    const { data: localPlayers } = await supabase.from('players').select('id, name');

    // 4. CHIAMATA API PARTITE
    const res = await fetch(`https://v3.football.api-sports.io/fixtures?date=${targetDate}`, {
      headers: { 'x-apisports-key': apiKey }
    })
    const data = await res.json()
    const fixtures = data.response

    if (!fixtures || fixtures.length === 0) {
      return new Response(JSON.stringify({ message: `Nessuna partita giocata il ${targetDate}` }), { status: 200 })
    }

    let aggiornati = 0;

    // 5. ELABORAZIONE VOTI
    for (const fix of fixtures) {
      const fixId = fix.fixture.id
      
      console.log(`Attendo 7 secondi prima di scaricare la partita ${fixId}...`);
      await delay(7000);

      const statsRes = await fetch(`https://v3.football.api-sports.io/fixtures/players?fixture=${fixId}`, {
        headers: { 'x-apisports-key': apiKey }
      })
      const statsData = await statsRes.json()
      
      if (!statsData.response) continue

      for (const team of statsData.response) {
        for (const p of team.players) {
          const stats = p.statistics[0]
          const apiName = normalizeName(p.player.name);
          
          // 6. MATCHING DEL NOME (Trova l'ID nel tuo DB)
          const localPlayer = localPlayers?.find((lp: any) => {
            const myName = normalizeName(lp.name);
            const myLastName = myName.split(' ').pop() || myName;
            return myName.includes(apiName) || apiName.includes(myLastName);
          });

          // Se il giocatore non è nel tuo database, passa oltre
          if (!localPlayer) continue;

          // Arrotondamento voti
          const rawRating = parseFloat(stats.games.rating ?? '6.0') || 6.0;
          const rating = Math.round(rawRating * 2) / 2.0;
          
          // 7. UPSERT DEFINITIVO
          await supabase.from('matchday_stats').upsert({
            match_day: currentMatchday,     // <--- Aggiunto il matchday dinamico!
            player_id: localPlayer.id,      // <--- Aggiunto il VERO ID del tuo database!
            base_grade: rating,
            goals_scored: stats.goals.total ?? 0,
            assists: stats.goals.assists ?? 0,
            yellow_cards: stats.cards.yellow ?? 0,
            red_cards: stats.cards.red ?? 0,
            penalty_missed: stats.penalty.missed ?? 0,
            penalty_saved: stats.penalty.saved ?? 0,
            own_goals: stats.goals.own ?? 0,
            man_of_the_match: false,
            clean_sheet: (stats.games.minutes > 0 && (stats.goals.conceded ?? 0) === 0),
            goals_conceded: stats.goals.conceded ?? 0
          })
          
          aggiornati++;
        }
      }
    }

    return new Response(JSON.stringify({ message: `Successo! Giornata ${currentMatchday}: ${aggiornati} giocatori aggiornati.` }), { status: 200 })
    
  } catch (error) {
    console.error("Errore durante l'esecuzione:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})