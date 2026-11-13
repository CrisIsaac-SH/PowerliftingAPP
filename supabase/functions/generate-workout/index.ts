import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type LiftKey = "squat" | "bench" | "deadlift";

const starters: Record<LiftKey, number> = {
  squat: 20,
  bench: 20,
  deadlift: 40,
};

function liftKey(name: string): LiftKey | null {
  const value = name.toLowerCase();
  if (value.includes("squat") || value.includes("sentadilla")) return "squat";
  if (value.includes("bench") || value.includes("banca")) return "bench";
  if (value.includes("deadlift") || value.includes("muerto")) return "deadlift";
  return null;
}

function epley(weight: number, reps: number): number {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps === 1) return weight;
  return weight * (1 + reps / 30);
}

function roundToPlate(kg: number): number {
  const rounded = Math.round(kg / 2.5) * 2.5;
  return rounded < 20 ? 20 : rounded;
}

// Cortes de una preparación típica de powerlifting, no de un estudio de esta app.
// Más de 8 semanas: hay tiempo para acumular volumen.
// De 4 a 8: bloque de fuerza, menos repeticiones y más intensidad.
// Menos de 4: pico, baja el volumen para llegar fresco.
// La semana de la competencia afina todavía más.
function schemeForWeeks(weeksOut: number | null): { sets: number; reps: number; percent: number; phase: string } {
  if (weeksOut == null) return { sets: 3, reps: 5, percent: 0.85, phase: "base" };
  if (weeksOut > 8) return { sets: 4, reps: 6, percent: 0.75, phase: "volumen" };
  if (weeksOut >= 4) return { sets: 4, reps: 3, percent: 0.85, phase: "fuerza" };
  if (weeksOut >= 1) return { sets: 3, reps: 2, percent: 0.9, phase: "pico" };
  return { sets: 2, reps: 1, percent: 0.92, phase: "competencia" };
}

function liftsForWeekday(weekday: number): LiftKey[] {
  switch (weekday) {
    case 1:
      return ["squat", "bench"];
    case 2:
      return ["bench"];
    case 3:
      return ["deadlift", "bench"];
    case 4:
      return ["squat"];
    case 5:
      return ["squat", "deadlift"];
    case 6:
      return ["bench", "deadlift"];
    default:
      return ["squat"];
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: auth } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Sesión no válida" }), {
        status: 401,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const userId = userData.user.id;
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const dateText = typeof body?.date === "string" ? body.date : new Date().toISOString().slice(0, 10);
    const [year, month, day] = dateText.split("-").map((part: string) => Number(part));
    const today = new Date(Date.UTC(year, (month || 1) - 1, day || 1));
    const weekday = today.getUTCDay() === 0 ? 7 : today.getUTCDay();
    const monday = new Date(today);
    monday.setUTCDate(today.getUTCDate() - (weekday - 1));
    const weekStart = monday.toISOString().slice(0, 10);

    const { data: goal } = await supabase
      .from("weekly_goals")
      .select("id, weekly_lift_goals(target_weight_kg, exercises(name))")
      .eq("athlete_id", userId)
      .eq("week_start", weekStart)
      .maybeSingle();

    const goalWeight = new Map<LiftKey, number>();
    const liftGoals = (goal?.weekly_lift_goals ?? []) as Array<{
      target_weight_kg: number | null;
      exercises: { name: string } | null;
    }>;
    for (const row of liftGoals) {
      const key = liftKey(row.exercises?.name ?? "");
      const weight = Number(row.target_weight_kg ?? 0);
      if (key && weight > 0) goalWeight.set(key, weight);
    }

    const { data: sets } = await supabase
      .from("sets")
      .select("weight, reps, rpe, status, exercises(name), workouts!inner(user_id, date)")
      .eq("workouts.user_id", userId);

    const best = new Map<LiftKey, number>();
    const doneThisWeek = new Set<LiftKey>();
    const highRpe = new Set<LiftKey>();
    for (const row of sets ?? []) {
      if (row.status && row.status !== "completed") continue;
      const key = liftKey(row.exercises?.name ?? "");
      if (!key) continue;
      const rm = epley(Number(row.weight ?? 0), Number(row.reps ?? 0));
      if (rm > (best.get(key) ?? 0)) best.set(key, rm);
      const workoutDate = String(row.workouts?.date ?? "");
      if (workoutDate >= weekStart && workoutDate <= dateText) {
        doneThisWeek.add(key);
        if (Number(row.rpe ?? 0) >= 9) highRpe.add(key);
      }
    }

    const { data: meet } = await supabase
      .from("meets")
      .select("name, meet_date")
      .eq("athlete_id", userId)
      .gte("meet_date", dateText)
      .order("meet_date")
      .limit(1)
      .maybeSingle();

    let weeksOut: number | null = null;
    if (meet?.meet_date) {
      const meetDate = new Date(`${meet.meet_date}T00:00:00Z`);
      weeksOut = Math.floor((meetDate.getTime() - today.getTime()) / (7 * 24 * 60 * 60 * 1000));
    }
    const plan = schemeForWeeks(weeksOut);

    const { data: checkin } = await supabase
      .from("daily_checkins")
      .select("sleep_hours, soreness, feeling")
      .eq("athlete_id", userId)
      .eq("checkin_date", dateText)
      .maybeSingle();
    const tired = checkin != null && (
      Number(checkin.sleep_hours ?? 8) < 6 ||
      Number(checkin.soreness ?? 1) >= 4 ||
      checkin.feeling === "mal"
    );

    const { data: programs } = await supabase
      .from("training_programs")
      .select("coach_notes, start_date, end_date")
      .eq("athlete_id", userId)
      .eq("status", "active")
      .lte("start_date", dateText)
      .gte("end_date", dateText);

    let emphasis: LiftKey | null = null;
    const covering = (programs ?? []) as Array<{ coach_notes: string | null; start_date: string }>;
    covering.sort((a, b) => b.start_date.localeCompare(a.start_date));
    const note = (covering[0]?.coach_notes ?? "").toLowerCase();
    emphasis = liftKey(note);

    const chosen = new Set<LiftKey>();
    if (emphasis) chosen.add(emphasis);
    const source = goalWeight.size > 0 ? [...goalWeight.keys()] : liftsForWeekday(weekday);
    for (const lift of source) {
      if (!doneThisWeek.has(lift)) chosen.add(lift);
    }
    if (chosen.size === 0) {
      for (const lift of source) chosen.add(lift);
    }

    let setCount = plan.sets;
    if (tired) setCount = Math.max(1, setCount - 1);

    const planned = [];
    for (const lift of chosen) {
      const fromGoal = goalWeight.get(lift);
      const fromHistory = best.get(lift);
      let weight = fromGoal ??
        (fromHistory ? roundToPlate(fromHistory * plan.percent) : starters[lift]);
      if (highRpe.has(lift)) weight = roundToPlate(weight * 0.9);
      else if (tired) weight = roundToPlate(weight * 0.95);
      for (let n = 0; n < setCount; n++) {
        planned.push({
          exercise: lift,
          target_weight_kg: weight,
          target_reps: plan.reps,
          target_rpe: tired ? 7 : 8,
        });
      }
    }

    return new Response(JSON.stringify({
      sets: planned,
      phase: plan.phase,
      weeks_out: weeksOut,
      meet: meet?.name ?? null,
    }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});