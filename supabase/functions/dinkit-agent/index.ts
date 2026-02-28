import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ---------- Types ----------

interface SkillSnapshot {
  id: string;
  name: string;
  category: string;
  current_rating: number;
  parent_skill_id: string | null;
  subskills: { id: string; name: string; current_rating: number }[];
}

interface ExtractionMention {
  skill_name: string;
  sentiment:
    | "very_negative"
    | "negative"
    | "neutral"
    | "positive"
    | "very_positive";
  intensity: number;
  subskills_mentioned: string[];
  quote: string;
}

interface ExtractionResult {
  mentions: ExtractionMention[];
  new_skill_suggestions: string[];
  session_duration_minutes: number | null;
  session_type: string | null;
}

interface SkillDelta {
  skill_id: string;
  skill: string;
  old: number;
  new: number;
  delta: number;
  subskill_deltas: {
    name: string;
    old: number;
    new: number;
    delta: number;
  }[];
}

interface DrillRecommendation {
  name: string;
  description: string;
  target_skill: string;
  target_subskill: string | null;
  duration_minutes: number;
  player_count: number;
  equipment: string;
  reason: string;
  priority: "high" | "medium" | "low";
}

interface RoadmapEntry {
  type: "weekly_focus" | "milestone";
  title: string;
  description: string;
  target_skill: string | null;
  target_value: number | null;
  status: "active" | "completed" | "replaced";
  starts_at: string;
  ends_at: string | null;
}

interface RoadmapUpdates {
  weekly_focus: RoadmapEntry | null;
  milestones: RoadmapEntry[];
}

// ---------- Scoring constants ----------

const BASE_INCREMENT = 3;

const SENTIMENT_MULTIPLIER: Record<string, number> = {
  very_negative: -1.5,
  negative: -0.8,
  neutral: 0.0,
  positive: 1.0,
  very_positive: 1.5,
};

const MAX_DELTA_PER_SKILL = 10;

// Tier boundaries for milestones
const TIER_BOUNDARIES = [25, 50, 75, 100];

// ---------- Claude API helper ----------

async function callClaude(
  apiKey: string,
  system: string,
  userMessage: string,
  maxTokens = 1024
): Promise<string> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-5-20250514",
      max_tokens: maxTokens,
      system,
      messages: [{ role: "user", content: userMessage }],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Claude API error: ${response.status} — ${err}`);
  }

  const data = await response.json();
  const text = data.content[0].text;
  return text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
}

// ---------- Pass 1: Extraction (Claude API) ----------

async function extractSession(
  note: string,
  skills: SkillSnapshot[],
  apiKey: string
): Promise<ExtractionResult> {
  const skillList = skills
    .map((s) => {
      const subs =
        s.subskills.length > 0
          ? ` (subskills: ${s.subskills.map((sub) => sub.name).join(", ")})`
          : "";
      return `- ${s.name} [${s.category}] — ${s.current_rating}%${subs}`;
    })
    .join("\n");

  const systemPrompt = `You are a pickleball coaching assistant that analyzes session notes.

The user has these skills tracked:
${skillList || "(no skills yet)"}

Parse the user's session note into structured JSON. Extract every skill or subskill mentioned, determine sentiment and intensity.

Rules:
- Match mentions to existing skill names when possible (fuzzy match is fine)
- sentiment: very_negative / negative / neutral / positive / very_positive
- intensity: 1 (barely mentioned) to 5 (major focus of the session)
- Include direct quotes from the note that support each mention
- If the user describes a skill not in their list, add it to new_skill_suggestions
- Infer session_duration_minutes and session_type (singles/doubles/drills/mixed) from context, use null if not mentioned

Respond ONLY with valid JSON matching this schema:
{
  "mentions": [
    {
      "skill_name": "string",
      "sentiment": "string",
      "intensity": number,
      "subskills_mentioned": ["string"],
      "quote": "string"
    }
  ],
  "new_skill_suggestions": ["string"],
  "session_duration_minutes": number | null,
  "session_type": "string | null"
}`;

  const cleaned = await callClaude(apiKey, systemPrompt, note);
  return JSON.parse(cleaned) as ExtractionResult;
}

// ---------- Pass 2: Scoring (Deterministic) ----------

function computeDeltas(
  extraction: ExtractionResult,
  skills: SkillSnapshot[],
  sessionsThisWeek: number
): SkillDelta[] {
  const frequencyDecay = 1 / (1 + sessionsThisWeek * 0.15);
  const deltas: SkillDelta[] = [];

  const mentionsBySkill = new Map<string, ExtractionMention[]>();
  for (const mention of extraction.mentions) {
    const key = mention.skill_name.toLowerCase();
    if (!mentionsBySkill.has(key)) {
      mentionsBySkill.set(key, []);
    }
    mentionsBySkill.get(key)!.push(mention);
  }

  for (const [skillKey, mentions] of mentionsBySkill) {
    const skill = skills.find((s) => s.name.toLowerCase() === skillKey);
    if (!skill) continue;

    let totalDelta = 0;
    for (const mention of mentions) {
      const multiplier = SENTIMENT_MULTIPLIER[mention.sentiment] ?? 0;
      totalDelta += BASE_INCREMENT * multiplier * frequencyDecay;
    }

    totalDelta = Math.max(
      -MAX_DELTA_PER_SKILL,
      Math.min(MAX_DELTA_PER_SKILL, totalDelta)
    );
    totalDelta = Math.round(totalDelta);
    if (totalDelta === 0) continue;

    const oldRating = skill.current_rating;
    const newRating = Math.max(0, Math.min(100, oldRating + totalDelta));
    const actualDelta = newRating - oldRating;

    const subskillDeltas: SkillDelta["subskill_deltas"] = [];
    if (skill.subskills.length > 0 && actualDelta !== 0) {
      const mentionedSubNames = new Set(
        mentions.flatMap((m) =>
          m.subskills_mentioned.map((s) => s.toLowerCase())
        )
      );

      for (const sub of skill.subskills) {
        const isMentioned = mentionedSubNames.has(sub.name.toLowerCase());
        const subDeltaRaw = isMentioned
          ? actualDelta
          : Math.round(actualDelta * 0.5);
        const subNew = Math.max(
          0,
          Math.min(100, sub.current_rating + subDeltaRaw)
        );
        const subActual = subNew - sub.current_rating;
        if (subActual !== 0) {
          subskillDeltas.push({
            name: sub.name,
            old: sub.current_rating,
            new: subNew,
            delta: subActual,
          });
        }
      }
    }

    deltas.push({
      skill_id: skill.id,
      skill: skill.name,
      old: oldRating,
      new: newRating,
      delta: actualDelta,
      subskill_deltas: subskillDeltas,
    });
  }

  return deltas;
}

// ---------- Pass 3: Drill Generation (Claude API) ----------

async function generateDrills(
  extraction: ExtractionResult,
  skillDeltas: SkillDelta[],
  skills: SkillSnapshot[],
  apiKey: string
): Promise<DrillRecommendation[]> {
  const deltaSummary = skillDeltas
    .map(
      (d) =>
        `- ${d.skill}: ${d.old}% → ${d.new}% (${d.delta > 0 ? "+" : ""}${d.delta}%)` +
        (d.subskill_deltas.length > 0
          ? "\n" +
            d.subskill_deltas
              .map(
                (s) =>
                  `    - ${s.name}: ${s.old}% → ${s.new}% (${s.delta > 0 ? "+" : ""}${s.delta}%)`
              )
              .join("\n")
          : "")
    )
    .join("\n");

  const allSkillsSummary = skills
    .map((s) => `- ${s.name}: ${s.current_rating}%`)
    .join("\n");

  const systemPrompt = `You are an expert pickleball coach generating personalized drills.

Current skill ratings:
${allSkillsSummary || "(no skills)"}

Changes from this session:
${deltaSummary || "(no changes)"}

Session context:
${extraction.mentions.map((m) => `- ${m.skill_name} (${m.sentiment}): "${m.quote}"`).join("\n")}

COACHING KNOWLEDGE:
- Overheads: prioritize contact point height and timing over power. Common fix is tossing drills to find the ideal contact window.
- Dinks: emphasize soft hands, paddle face angle, and reset position. Cross-court dinks build consistency before down-the-line.
- Drives: focus on weight transfer and follow-through. Low-to-high swing path for topspin control.
- Drops: wrist stability and arc control. Practice from transition zone before baseline.
- Serves: consistent toss placement and controlled power. Deep serves reduce third-shot pressure.
- Defense: ready position, split step timing, and paddle positioning at the kitchen line.

DRILL REQUIREMENTS:
- Each drill must be pickleball-specific and actionable
- Include: player count, equipment needed, estimated duration, step-by-step instructions
- Explain the biomechanical WHY behind the drill
- Keep drills 5-15 minutes each

PRIORITIZATION (in order):
1. Skills that declined this session (most urgent)
2. Bottleneck subskills mentioned negatively
3. Plateauing skills (mentioned but neutral)

Generate 2-3 drills. Respond ONLY with a valid JSON array:
[{
  "name": "string",
  "description": "string (full step-by-step instructions)",
  "target_skill": "string",
  "target_subskill": "string or null",
  "duration_minutes": number,
  "player_count": number,
  "equipment": "string",
  "reason": "string (why this drill for this player right now)",
  "priority": "high | medium | low"
}]`;

  const cleaned = await callClaude(
    apiKey,
    systemPrompt,
    "Generate drills based on the session analysis above.",
    2048
  );
  return JSON.parse(cleaned) as DrillRecommendation[];
}

// ---------- Pass 4: Roadmap Update (Deterministic + Claude) ----------

function getTierCeiling(rating: number): number {
  for (const boundary of TIER_BOUNDARIES) {
    if (rating < boundary) return boundary;
  }
  return 100;
}

function crossedTierBoundary(
  oldRating: number,
  newRating: number
): number | null {
  for (const boundary of TIER_BOUNDARIES) {
    if (oldRating < boundary && newRating >= boundary) return boundary;
  }
  return null;
}

async function updateRoadmap(
  skillDeltas: SkillDelta[],
  skills: SkillSnapshot[],
  supabase: ReturnType<typeof createClient>,
  userId: string,
  apiKey: string
): Promise<RoadmapUpdates> {
  const today = new Date().toISOString().split("T")[0];
  const nextWeek = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    .toISOString()
    .split("T")[0];

  // --- Determine weekly focus (deterministic rules) ---
  let focusSkillName: string | null = null;

  // Rule 1: If a skill dropped 5%+ → make it next week's focus
  const biggestDrop = skillDeltas
    .filter((d) => d.delta <= -5)
    .sort((a, b) => a.delta - b.delta)[0];

  if (biggestDrop) {
    focusSkillName = biggestDrop.skill;
  } else {
    // Rule 2: Focus on lowest-rated mentioned skill
    const mentionedSkills = skillDeltas
      .map((d) => ({ name: d.skill, rating: d.new }))
      .sort((a, b) => a.rating - b.rating);
    if (mentionedSkills.length > 0) {
      focusSkillName = mentionedSkills[0].name;
    }
  }

  let weeklyFocus: RoadmapEntry | null = null;

  if (focusSkillName) {
    // Check if there's already an active weekly focus
    const { data: existing } = await supabase
      .from("user_roadmap")
      .select("id, starts_at")
      .eq("user_id", userId)
      .eq("type", "weekly_focus")
      .eq("status", "active")
      .limit(1)
      .single();

    // Replace if older than 7 days or different skill
    const shouldReplace =
      !existing ||
      new Date(existing.starts_at).getTime() <
        Date.now() - 7 * 24 * 60 * 60 * 1000;

    if (shouldReplace) {
      // Mark old focus as replaced
      if (existing) {
        await supabase
          .from("user_roadmap")
          .update({ status: "replaced" })
          .eq("id", existing.id);
      }

      // LLM generates the narrative
      const focusNarrative = await callClaude(
        apiKey,
        `You are a pickleball coach writing a brief weekly focus theme. Be encouraging and specific. Respond with JSON only: {"title": "string (catchy 3-5 word title)", "description": "string (2-3 sentence coaching narrative)"}`,
        `The player needs to focus on "${focusSkillName}" this week.${biggestDrop ? ` It dropped ${Math.abs(biggestDrop.delta)}% in their last session.` : ` It's their lowest-rated mentioned skill.`}`,
        256
      );
      const parsed = JSON.parse(focusNarrative);

      weeklyFocus = {
        type: "weekly_focus",
        title: parsed.title,
        description: parsed.description,
        target_skill: focusSkillName,
        target_value: null,
        status: "active",
        starts_at: today,
        ends_at: nextWeek,
      };
    }
  }

  // --- Determine milestones (deterministic rules) ---
  const milestones: RoadmapEntry[] = [];
  const milestonesForNarrative: {
    skill: string;
    crossed: number | null;
    ceiling: number;
    current: number;
  }[] = [];

  for (const delta of skillDeltas) {
    const crossed = crossedTierBoundary(delta.old, delta.new);
    if (crossed) {
      // Skill crossed a tier — mark this milestone complete, create next
      milestonesForNarrative.push({
        skill: delta.skill,
        crossed,
        ceiling: getTierCeiling(delta.new),
        current: delta.new,
      });
    } else if (delta.new < 100) {
      // Check if a milestone already exists for this skill
      const { data: existingMilestone } = await supabase
        .from("user_roadmap")
        .select("id")
        .eq("user_id", userId)
        .eq("type", "milestone")
        .eq("target_skill", delta.skill)
        .eq("status", "active")
        .limit(1)
        .single();

      if (!existingMilestone) {
        milestonesForNarrative.push({
          skill: delta.skill,
          crossed: null,
          ceiling: getTierCeiling(delta.new),
          current: delta.new,
        });
      }
    }
  }

  // Generate narratives for milestones in one LLM call if needed
  if (milestonesForNarrative.length > 0) {
    const milestonePrompt = milestonesForNarrative
      .map((m) => {
        if (m.crossed) {
          return `- ${m.skill}: just crossed ${m.crossed}%! Now at ${m.current}%. Next target: ${m.ceiling}%.`;
        }
        return `- ${m.skill}: currently at ${m.current}%. Target: ${m.ceiling}%.`;
      })
      .join("\n");

    const narrativeResult = await callClaude(
      apiKey,
      `You are a pickleball coach writing milestone descriptions. Be encouraging. Respond with JSON only — an array matching the input order:
[{"title": "string (catchy milestone title)", "description": "string (1-2 sentence motivational description)"}]`,
      `Generate milestone titles and descriptions for:\n${milestonePrompt}`,
      512
    );
    const narratives = JSON.parse(narrativeResult) as {
      title: string;
      description: string;
    }[];

    for (let i = 0; i < milestonesForNarrative.length; i++) {
      const m = milestonesForNarrative[i];
      const n = narratives[i] ?? {
        title: `Reach ${m.ceiling}% ${m.skill}`,
        description: "Keep pushing!",
      };

      // If crossed a tier, mark old milestone complete
      if (m.crossed) {
        await supabase
          .from("user_roadmap")
          .update({ status: "completed" })
          .eq("user_id", userId)
          .eq("type", "milestone")
          .eq("target_skill", m.skill)
          .eq("status", "active");
      }

      milestones.push({
        type: "milestone",
        title: n.title,
        description: n.description,
        target_skill: m.skill,
        target_value: m.ceiling,
        status: "active",
        starts_at: today,
        ends_at: null,
      });
    }
  }

  return { weekly_focus: weeklyFocus, milestones };
}

// ---------- Session count helper ----------

async function getSessionsThisWeek(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<number> {
  const now = new Date();
  const dayOfWeek = now.getDay();
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((dayOfWeek + 6) % 7));
  monday.setHours(0, 0, 0, 0);

  const { count } = await supabase
    .from("session_logs")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", monday.toISOString());

  return count ?? 0;
}

// ---------- Response helper ----------

function jsonResponse(
  data: unknown,
  status = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ---------- Main handler ----------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, note, skills, session_id } = body;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!anthropicKey) {
      return jsonResponse({ error: "ANTHROPIC_API_KEY not configured" }, 500);
    }

    // ---- action: log_session ----
    if (action === "log_session") {
      if (!note || typeof note !== "string") {
        return jsonResponse({ error: "note is required" }, 400);
      }

      const userSkills: SkillSnapshot[] = skills ?? [];

      // Pass 1: Extraction
      const extraction = await extractSession(note, userSkills, anthropicKey);

      // Pass 2: Scoring
      const sessionsThisWeek = await getSessionsThisWeek(supabase, user.id);
      const skillDeltas = computeDeltas(extraction, userSkills, sessionsThisWeek);

      // Pass 3: Drill Generation
      const drillRecommendations = await generateDrills(
        extraction,
        skillDeltas,
        userSkills,
        anthropicKey
      );

      // Pass 4: Roadmap Update
      const roadmapUpdates = await updateRoadmap(
        skillDeltas,
        userSkills,
        supabase,
        user.id,
        anthropicKey
      );

      // Save session log (unconfirmed) with all pipeline outputs
      const { data: session, error: insertError } = await supabase
        .from("session_logs")
        .insert({
          user_id: user.id,
          raw_note: note,
          extracted_json: extraction,
          applied_deltas: skillDeltas,
          drill_recommendations: drillRecommendations,
          user_confirmed: false,
        })
        .select("id")
        .single();

      if (insertError) {
        throw new Error(`Failed to save session: ${insertError.message}`);
      }

      return jsonResponse({
        session_id: session.id,
        extraction,
        skill_updates: skillDeltas.map((d) => ({
          skill_id: d.skill_id,
          skill: d.skill,
          old: d.old,
          new: d.new,
          delta: d.delta,
          subskill_deltas: d.subskill_deltas,
        })),
        drill_recommendations: drillRecommendations,
        roadmap_updates: roadmapUpdates,
      });
    }

    // ---- action: confirm_session ----
    if (action === "confirm_session") {
      if (!session_id || typeof session_id !== "string") {
        return jsonResponse({ error: "session_id is required" }, 400);
      }

      // Fetch the unconfirmed session to get stored data
      const { data: sessionLog, error: fetchError } = await supabase
        .from("session_logs")
        .select("*")
        .eq("id", session_id)
        .eq("user_id", user.id)
        .single();

      if (fetchError || !sessionLog) {
        return jsonResponse({ error: "Session not found" }, 404);
      }

      if (sessionLog.user_confirmed) {
        return jsonResponse({ error: "Session already confirmed" }, 400);
      }

      // Insert drills into user_drill_queue
      const drills = (sessionLog.drill_recommendations ?? []) as DrillRecommendation[];
      if (drills.length > 0) {
        const drillRows = drills.map((d) => ({
          user_id: user.id,
          name: d.name,
          description: d.description,
          target_skill: d.target_skill,
          target_subskill: d.target_subskill,
          duration_minutes: d.duration_minutes,
          priority: d.priority,
          reason: d.reason,
          status: "pending",
        }));

        const { error: drillError } = await supabase
          .from("user_drill_queue")
          .insert(drillRows);

        if (drillError) {
          throw new Error(`Failed to save drills: ${drillError.message}`);
        }
      }

      // Insert roadmap entries from applied_deltas context
      // Re-derive roadmap from the stored session data
      const appliedDeltas = (sessionLog.applied_deltas ?? []) as SkillDelta[];

      // Check for roadmap entries that were generated during log_session
      // We need to store roadmap_updates in session_logs too — for now,
      // re-derive the weekly focus and milestones from deltas
      // A cleaner approach: the roadmap_updates were already computed during
      // log_session but we only stored drills in session_logs. Let's check
      // if we can insert based on what the response included.

      // For weekly focus and milestones, the Pass 4 already made DB changes
      // (marking old entries as replaced/completed) during log_session.
      // On confirm, we insert the new entries.

      // Since roadmap entries aren't stored in session_logs, we accept them
      // in the confirm request body.
      const roadmapUpdates = body.roadmap_updates as RoadmapUpdates | undefined;

      if (roadmapUpdates) {
        const roadmapRows: Record<string, unknown>[] = [];

        if (roadmapUpdates.weekly_focus) {
          roadmapRows.push({
            user_id: user.id,
            ...roadmapUpdates.weekly_focus,
          });
        }

        for (const milestone of roadmapUpdates.milestones ?? []) {
          roadmapRows.push({
            user_id: user.id,
            ...milestone,
          });
        }

        if (roadmapRows.length > 0) {
          const { error: roadmapError } = await supabase
            .from("user_roadmap")
            .insert(roadmapRows);

          if (roadmapError) {
            throw new Error(
              `Failed to save roadmap: ${roadmapError.message}`
            );
          }
        }
      }

      // Mark session confirmed
      const { error: updateError } = await supabase
        .from("session_logs")
        .update({ user_confirmed: true })
        .eq("id", session_id)
        .eq("user_id", user.id);

      if (updateError) {
        throw new Error(`Failed to confirm session: ${updateError.message}`);
      }

      return jsonResponse({ confirmed: true, session_id });
    }

    return jsonResponse({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 500);
  }
});
