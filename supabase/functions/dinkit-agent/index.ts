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
  pending_drill_count: number;
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
  suggested_rating: number | null;
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

const BASE_INCREMENT = 5;

const SENTIMENT_MULTIPLIER: Record<string, number> = {
  very_negative: -1.5,
  negative: -0.8,
  neutral: 0.0,
  positive: 1.0,
  very_positive: 1.5,
};

const INTENSITY_MULTIPLIER: Record<number, number> = {
  1: 0.5,
  2: 1.0,
  3: 1.5,
  4: 2.5,
  5: 4.0,
};

// For absolute claims ("mastered it", "terrible at it"), blend aggressively toward the target.
// Higher intensity = trust the user's self-assessment more.
const ABSOLUTE_BLEND_FACTOR: Record<number, number> = {
  1: 0.5,
  2: 0.65,
  3: 0.8,
  4: 0.9,
  5: 0.95,
};

const MAX_DELTA_PER_SKILL = 30;

// Max pending drills per skill before we stop recommending more
const PENDING_DRILL_CAP = 5;

// Tier boundaries for milestones
const TIER_BOUNDARIES = [25, 50, 75, 100];

interface SaturatedSkillInfo {
  skill_name: string;
  pending_count: number;
}

function getSaturatedSkills(skills: SkillSnapshot[]): SaturatedSkillInfo[] {
  return skills
    .filter((s) => s.pending_drill_count >= PENDING_DRILL_CAP)
    .map((s) => ({
      skill_name: s.name,
      pending_count: s.pending_drill_count,
    }));
}

// ---------- Claude API helper ----------

async function callClaude(
  apiKey: string,
  system: string,
  userMessage: string,
  maxTokens = 1024,
  fast = false
): Promise<string> {
  const model = fast
    ? "claude-haiku-4-5-20251001"
    : "claude-sonnet-4-5-20250929";
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
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

// ---------- Intent Classification (heuristic, no API call) ----------

type Intent = "session_log" | "create_subskills" | "create_skill";

function extractCurrentMessage(note: string): string {
  const lines = note.split("\n");
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i].trim();
    if (line.startsWith("User: ")) {
      return line.substring(6).trim();
    }
  }
  return note;
}

function mentionsExistingSkill(
  text: string,
  skills: SkillSnapshot[]
): boolean {
  const lower = text.toLowerCase();
  return skills.some((skill) => {
    const nameL = skill.name.toLowerCase();
    if (lower.includes(nameL)) return true;
    return skill.subskills.some((sub) =>
      lower.includes(sub.name.toLowerCase())
    );
  });
}

function classifyIntent(note: string, skills: SkillSnapshot[]): Intent {
  const currentMessage = extractCurrentMessage(note);
  const lower = currentMessage.toLowerCase();

  // Check subskill patterns first (more specific)
  const subskillPatterns = [
    /create\s+(sub\s*skills?|breakdowns?)/,
    /suggest\s+(sub\s*skills?|breakdowns?)/,
    /break\s*(down|up)\s+.*(skill|into)/,
    /add\s+sub\s*skills?\s+(for|to)/,
    /what\s+(sub\s*skills?|components?)\s+(should|could|can)/,
    /generate\s+sub\s*skills?/,
    /sub\s*skills?\s+for\s+/,
  ];
  for (const pattern of subskillPatterns) {
    if (pattern.test(lower)) return "create_subskills";
  }

  // Session-like language should never trigger skill creation
  const sessionIndicators =
    /\b(worked on|working on|practiced|played|drilled|trained|focused on|improved|improving|struggled with|got better|session|today|yesterday)\b/;
  if (sessionIndicators.test(lower)) return "session_log";

  // Check skill creation patterns
  const skillPatterns = [
    /(?:create|add|start\s+tracking)\s+(?:a\s+)?(?:new\s+)?skill\b/,
    /(?:add|create)\s+(?:a\s+)?(?:new\s+)?\w+[\w\s]*\bas\s+(?:a\s+)?skill\b/,
    /(?:add|create)\s+(?:a\s+)?(?:new\s+)?skill\s+(?:called|named|for)\s+/,
    /i\s+want\s+to\s+(?:add|create)\s+(?:a\s+)?(?:new\s+)?skill/,
    /^add\s+(?:a\s+)?(?:new\s+)?(?:skill\s+)?\w+\s+skill$/,
  ];

  let matchesCreation = false;
  for (const pattern of skillPatterns) {
    if (pattern.test(lower)) {
      matchesCreation = true;
      break;
    }
  }

  if (matchesCreation) {
    if (mentionsExistingSkill(currentMessage, skills)) return "session_log";
    return "create_skill";
  }

  return "session_log";
}

// ---------- Subskill Generation ----------

interface SubskillSuggestion {
  name: string;
  description: string;
  suggested_rating: number;
  parent_skill_id: string;
}

async function generateSubskills(
  note: string,
  skills: SkillSnapshot[],
  apiKey: string
): Promise<SubskillSuggestion[]> {
  const skillList = skills
    .map((s) => {
      const subs =
        s.subskills.length > 0
          ? ` (existing subskills: ${s.subskills.map((sub) => sub.name).join(", ")})`
          : "";
      return `- ${s.name} [${s.category}] id:${s.id} — ${s.current_rating}%${subs}`;
    })
    .join("\n");

  const systemPrompt = `You are a pickleball coaching assistant. The user wants to create subskills for one of their tracked skills.

Current skills:
${skillList || "(no skills yet)"}

Based on the user's request, identify which parent skill they're referring to and generate 3-5 subskills.

Rules:
- Each subskill should be a specific, measurable aspect of the parent skill
- Don't duplicate existing subskills
- Suggest a starting rating based on the parent skill's current rating (adjust up/down based on typical relative difficulty)
- Use the parent skill's ID as parent_skill_id

Respond ONLY with valid JSON:
[{
  "name": "string",
  "description": "string (1-2 sentence description)",
  "suggested_rating": number (0-100),
  "parent_skill_id": "string (UUID of the parent skill)"
}]`;

  const cleaned = await callClaude(apiKey, systemPrompt, note, 1024);
  return JSON.parse(cleaned) as SubskillSuggestion[];
}

// ---------- Skill Creation ----------

interface SkillCreationSuggestion {
  name: string;
  category: string;
  description: string;
  suggested_rating: number;
  icon_name: string;
}

async function generateSkill(
  note: string,
  skills: SkillSnapshot[],
  apiKey: string
): Promise<SkillCreationSuggestion[]> {
  const existingSkillNames = skills.map((s) => s.name).join(", ");

  const systemPrompt = `You are a pickleball coaching assistant. The user wants to create a new skill to track.

Existing skills: ${existingSkillNames || "(none)"}

Based on the user's request, suggest 1-3 new skills to create. Pick the most appropriate category for each.

Valid categories: dinking, drops, drives, defense, offense, strategy, serves

Rules:
- Don't suggest skills that already exist
- Pick an appropriate starting rating (0-100) based on context, default to 30 for beginners
- Pick an SF Symbol icon name that matches the skill (e.g. "figure.pickleball", "target", "shield.fill", "bolt.fill")
- Keep descriptions concise (1-2 sentences)

Respond ONLY with valid JSON:
[{
  "name": "string",
  "category": "string (one of: dinking, drops, drives, defense, offense, strategy, serves)",
  "description": "string",
  "suggested_rating": number,
  "icon_name": "string (SF Symbol name)"
}]`;

  const cleaned = await callClaude(apiKey, systemPrompt, note, 1024);
  return JSON.parse(cleaned) as SkillCreationSuggestion[];
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

Parse the user's session note into structured JSON. Extract every skill or subskill mentioned, determine sentiment, intensity, and what rating level the language implies.

Rules:
- CRITICAL: Always match mentions to existing skill names using fuzzy/partial matching. "ready position" should match "Ready Position For Speedups". A partial name match to an existing skill is ALWAYS preferred over suggesting a new skill.
- Only add to new_skill_suggestions if there is absolutely NO existing skill with a similar or overlapping name
- sentiment: very_negative / negative / neutral / positive / very_positive
- intensity: 1 (barely mentioned) to 5 (major focus of the session)
- suggested_rating: What proficiency level (0-100) does the user's language imply for this skill? Use these thresholds for ABSOLUTE claims about current ability:
  - "mastered", "nailed it", "perfected", "automatic", "second nature" → 90-100
  - "super comfortable", "really confident", "very good at", "dialed in" → 75-90
  - "comfortable", "confident", "solid", "consistent" → 60-75
  - "decent at", "okay with", "not bad" → 40-55
  - "not great at", "needs work", "inconsistent" → 25-40
  - "struggled with", "kept failing", "couldn't get it" → 15-30
  - "terrible at", "can't do it at all", "completely lost" → 5-15
  Use null ONLY for relative/comparative language that doesn't imply an absolute level:
  - "getting better", "improved a bit", "making progress" → null (positive sentiment)
  - "didn't improve", "same as before", "no change" → null (neutral sentiment)
  - "got worse", "regressed", "worse than last time" → null (negative sentiment)
  IMPORTANT: When the user describes their CURRENT level of ability (not just change), always provide a suggested_rating. Phrases like "I feel comfortable" or "I've mastered it" describe where they ARE, not just how they changed.
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
      "suggested_rating": number | null,
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

    // Check if any mention has a suggested_rating (absolute claim like "mastered")
    const bestAbsoluteMention = mentions
      .filter((m) => m.suggested_rating != null)
      .sort((a, b) => b.intensity - a.intensity)[0];

    let totalDelta = 0;
    const oldRating = skill.current_rating;

    if (bestAbsoluteMention && bestAbsoluteMention.suggested_rating != null) {
      // Absolute rating mode: jump toward the suggested rating aggressively.
      // No frequency decay — "I mastered this" means the same on session 1 or 5.
      const target = bestAbsoluteMention.suggested_rating;
      const blend = ABSOLUTE_BLEND_FACTOR[bestAbsoluteMention.intensity] ?? 0.8;
      totalDelta = Math.round((target - oldRating) * blend);
    } else {
      // Relative delta mode: incremental changes
      for (const mention of mentions) {
        const sentimentMult = SENTIMENT_MULTIPLIER[mention.sentiment] ?? 0;
        const intensityMult = INTENSITY_MULTIPLIER[mention.intensity] ?? 1.0;
        totalDelta += BASE_INCREMENT * sentimentMult * intensityMult * frequencyDecay;
      }

      // Rating gap scaling for relative deltas
      const bestMention = mentions.reduce((best, m) => {
        const score = (SENTIMENT_MULTIPLIER[m.sentiment] ?? 0) * m.intensity;
        const bestScore = (SENTIMENT_MULTIPLIER[best.sentiment] ?? 0) * best.intensity;
        return score > bestScore ? m : best;
      }, mentions[0]);

      if (bestMention && totalDelta > 0) {
        const gapBoost = 1.0 + (100 - oldRating) / 100;
        totalDelta *= gapBoost;
      } else if (bestMention && totalDelta < 0) {
        const gapBoost = 1.0 + oldRating / 100;
        totalDelta *= gapBoost;
      }

      totalDelta = Math.round(totalDelta);

      // Cap only applies to relative deltas, not absolute claims
      totalDelta = Math.max(
        -MAX_DELTA_PER_SKILL,
        Math.min(MAX_DELTA_PER_SKILL, totalDelta)
      );
    }

    if (totalDelta === 0) continue;
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
  saturatedSkillNames: Set<string>,
  apiKey: string
): Promise<DrillRecommendation[]> {
  // If every mentioned skill is saturated, skip drill generation entirely
  const nonSaturatedDeltas = skillDeltas.filter(
    (d) => !saturatedSkillNames.has(d.skill)
  );
  if (nonSaturatedDeltas.length === 0 && skillDeltas.length > 0) {
    return [];
  }

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

  const saturatedWarning =
    saturatedSkillNames.size > 0
      ? `\nSATURATED SKILLS (do NOT generate drills for these — their drill queue is full):\n${[...saturatedSkillNames].map((n) => `- ${n}`).join("\n")}\nThese skills already have too many pending drills. Do NOT generate drills for them, and do NOT generate drills for other skills just to fill a quota.\n`
      : "";

  const systemPrompt = `You are an expert pickleball coach generating personalized drills.

Current skill ratings:
${allSkillsSummary || "(no skills)"}

Changes from this session:
${deltaSummary || "(no changes)"}

Session context:
${extraction.mentions.map((m) => `- ${m.skill_name} (${m.sentiment}): "${m.quote}"`).join("\n")}
${saturatedWarning}
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

CRITICAL RULES:
- ONLY generate drills for skills that were discussed in this session. Never recommend drills for skills the player did not mention.
- It is perfectly fine to return 0, 1, or 2 drills. Do NOT pad with unrelated drills just to reach a quota.
- If all session-relevant skills are saturated (drill queue full), return an empty array [].

PRIORITIZATION (in order):
1. Skills that declined this session (most urgent)
2. Bottleneck subskills mentioned negatively
3. Plateauing skills (mentioned but neutral)

Generate 0 to 3 drills. Respond ONLY with a valid JSON array (empty array [] is valid):
[{
  "name": "string",
  "description": "string (full step-by-step instructions)",
  "target_skill": "string (MUST be a skill from this session)",
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
  let drills = JSON.parse(cleaned) as DrillRecommendation[];

  // Safety net: filter out any drills that target saturated skills
  if (saturatedSkillNames.size > 0) {
    drills = drills.filter((d) => !saturatedSkillNames.has(d.target_skill));
  }

  // Safety net: filter out drills targeting skills not mentioned in this session
  const mentionedSkillNamesLower = new Set(
    skillDeltas.map((d) => d.skill.toLowerCase())
  );
  drills = drills.filter((d) =>
    mentionedSkillNamesLower.has(d.target_skill.toLowerCase())
  );

  return drills;
}

// ---------- Coach Insight (Claude API, fast model) ----------

async function generateCoachInsight(
  extraction: ExtractionResult,
  skillDeltas: SkillDelta[],
  apiKey: string
): Promise<string> {
  const deltaSummary = skillDeltas
    .map(
      (d) =>
        `${d.skill}: ${d.old}% → ${d.new}% (${d.delta > 0 ? "+" : ""}${d.delta}%)`
    )
    .join(", ");

  const mentionSummary = extraction.mentions
    .map((m) => `${m.skill_name} (${m.sentiment}): "${m.quote}"`)
    .join("\n");

  const insight = await callClaude(
    apiKey,
    `You are a concise pickleball coach giving quick session feedback. Respond with a short plain text analysis (2-3 sentences max). No JSON, no markdown, no bullet points. Be direct — highlight what went well, what needs attention, and one actionable takeaway. Reference specific skills by name.`,
    `Session notes:\n${mentionSummary}\n\nSkill changes: ${deltaSummary || "none"}`,
    200,
    true
  );

  return insight;
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

      // LLM generates the narrative (fast model — simple text generation)
      const focusNarrative = await callClaude(
        apiKey,
        `You are a pickleball coach writing a brief weekly focus theme. Be encouraging and specific. Respond with JSON only: {"title": "string (catchy 3-5 word title)", "description": "string (2-3 sentence coaching narrative)"}`,
        `The player needs to focus on "${focusSkillName}" this week.${biggestDrop ? ` It dropped ${Math.abs(biggestDrop.delta)}% in their last session.` : ` It's their lowest-rated mentioned skill.`}`,
        256,
        true
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
      512,
      true
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

      // Classify intent (heuristic — no API call)
      const intent = classifyIntent(note, userSkills);

      if (intent === "create_subskills") {
        // Generate subskill suggestions instead of running the session pipeline
        const subskillSuggestions = await generateSubskills(
          note,
          userSkills,
          anthropicKey
        );

        // Save a session log for tracking
        const { data: session, error: insertError } = await supabase
          .from("session_logs")
          .insert({
            user_id: user.id,
            raw_note: note,
            extracted_json: { mentions: [], new_skill_suggestions: [], session_duration_minutes: null, session_type: null },
            applied_deltas: [],
            drill_recommendations: [],
            user_confirmed: false,
          })
          .select("id")
          .single();

        if (insertError) {
          throw new Error(`Failed to save session: ${insertError.message}`);
        }

        return jsonResponse({
          session_id: session.id,
          extraction: { mentions: [], new_skill_suggestions: [], session_duration_minutes: null, session_type: null },
          skill_updates: [],
          drill_recommendations: [],
          roadmap_updates: null,
          subskill_suggestions: subskillSuggestions,
          skill_suggestions: [],
        });
      }

      if (intent === "create_skill") {
        // Generate skill creation suggestions
        const skillSuggestions = await generateSkill(
          note,
          userSkills,
          anthropicKey
        );

        // Save a session log for tracking
        const { data: session, error: insertError } = await supabase
          .from("session_logs")
          .insert({
            user_id: user.id,
            raw_note: note,
            extracted_json: { mentions: [], new_skill_suggestions: [], session_duration_minutes: null, session_type: null },
            applied_deltas: [],
            drill_recommendations: [],
            user_confirmed: false,
          })
          .select("id")
          .single();

        if (insertError) {
          throw new Error(`Failed to save session: ${insertError.message}`);
        }

        return jsonResponse({
          session_id: session.id,
          extraction: { mentions: [], new_skill_suggestions: [], session_duration_minutes: null, session_type: null },
          skill_updates: [],
          drill_recommendations: [],
          roadmap_updates: null,
          subskill_suggestions: [],
          skill_suggestions: skillSuggestions,
        });
      }

      // Pass 1: Extraction + session count (parallel — independent)
      const [extraction, sessionsThisWeek] = await Promise.all([
        extractSession(note, userSkills, anthropicKey),
        getSessionsThisWeek(supabase, user.id),
      ]);

      // Filter out new_skill_suggestions that fuzzy-match existing skills/subskills
      extraction.new_skill_suggestions =
        extraction.new_skill_suggestions.filter((suggestion) => {
          const sLower = suggestion.toLowerCase().trim();
          return !userSkills.some((skill) => {
            const nameL = skill.name.toLowerCase();
            if (nameL === sLower || nameL.includes(sLower) || sLower.includes(nameL))
              return true;
            return skill.subskills.some((sub) => {
              const subL = sub.name.toLowerCase();
              return subL === sLower || subL.includes(sLower) || sLower.includes(subL);
            });
          });
        });

      // Pass 2: Scoring (deterministic, instant)
      const skillDeltas = computeDeltas(extraction, userSkills, sessionsThisWeek);

      // Identify saturated skills (too many pending drills)
      const saturatedSkills = getSaturatedSkills(userSkills);
      const saturatedSkillNames = new Set(saturatedSkills.map((s) => s.skill_name));

      // Pass 3 + 4 + Insight: Drill generation + Roadmap update + Coach insight (parallel)
      const [drillRecommendations, roadmapUpdates, coachInsight] = await Promise.all([
        generateDrills(extraction, skillDeltas, userSkills, saturatedSkillNames, anthropicKey),
        updateRoadmap(skillDeltas, userSkills, supabase, user.id, anthropicKey),
        generateCoachInsight(extraction, skillDeltas, anthropicKey),
      ]);

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

      // Only include saturated skills that were actually mentioned in this session
      const mentionedSkillNames = new Set(
        extraction.mentions.map((m) => m.skill_name.toLowerCase())
      );
      const relevantSaturated = saturatedSkills.filter((s) =>
        mentionedSkillNames.has(s.skill_name.toLowerCase())
      );

      return jsonResponse({
        session_id: session.id,
        extraction,
        coach_insight: coachInsight,
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
        skill_suggestions: [],
        saturated_skills: relevantSaturated.length > 0 ? relevantSaturated : undefined,
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
