// Importa i moduli necessari per Supabase Edge Functions
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Configura i client di Supabase usando le variabili d'ambiente di sistema
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const supabase = createClient(supabaseUrl, supabaseKey)

serve(async (req) => {
  try {
    const today = new Date().toISOString().split('T')[0]
    const apiKey = Deno.env.get('API_KEY')

    // 1. Chiamata API per le partite del giorno
    const res = await fetch(`https://v3.football.api-sports.io/fixtures?date=${today}`, {
      headers: { 'x-apisports-key': apiKey }
    })
    const data = await res.json()
    const fixtures = data.response

    if (!fixtures || fixtures.length === 0) {
      return new Response(JSON.stringify({ message: "Nessuna partita oggi" }), { status: 200 })
    }

    // 2. Elaborazione voti (Logica simile a quella che avevi su Dart)
    for (const fix of fixtures) {
      const fixId = fix.fixture.id
      const statsRes = await fetch(`https://v3.football.api-sports.io/fixtures/players?fixture=${fixId}`, {
        headers: { 'x-apisports-key': apiKey }
      })
      const statsData = await statsRes.json()
      
      if (!statsData.response) continue

      for (const team of statsData.response) {
        for (const p of team.players) {
          const stats = p.statistics[0]
          
          // Esegui l'upsert su Supabase
          await supabase.from('matchday_stats').upsert({
            player_id: p.player.id,
            base_grade: stats.games.rating ?? 6.0,
            goals_scored: stats.goals.total ?? 0,
            assists: stats.goals.assists ?? 0,
            yellow_cards: stats.cards.yellow ?? 0,
            red_cards: stats.cards.red ?? 0,
            penalty_missed: stats.penalty.missed ?? 0,
            penalty_saved: stats.penalty.saved ?? 0,
            own_goals: stats.goals.own ?? 0,
            man_of_the_match: false,
            clean_sheet: (stats.games.minutes > 0 && stats.goals.conceded === 0)
          })
        }
      }
    }

    return new Response(JSON.stringify({ message: "Aggiornamento completato" }), { status: 200 })
    
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})