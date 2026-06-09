export interface ToolDefinition {
  readonly name: string;
  readonly description: string;
  readonly parameters: object; // JSON Schema
}

// ── Mutation tools (require user confirmation before client executes) ──────

const logWorkoutSet: ToolDefinition = {
  name: "logWorkoutSet",
  description:
    "Log a new workout set for the user. Use when the user wants to record a completed exercise set. " +
    "Always include both exerciseId (if known from context) and exerciseName (human-readable). " +
    "If exerciseId is unknown, omit it — the client resolves it from exerciseName.",
  parameters: {
    type: "object",
    properties: {
      exerciseName: {
        type: "string",
        description: 'Human-readable exercise name, e.g. "Bench Press".',
      },
      exerciseId: {
        type: "string",
        description:
          "UUID from recent_exercise_ids in context. Omit if not known.",
      },
      reps: {
        type: "integer",
        minimum: 1,
        description: "Number of repetitions performed.",
      },
      weight: {
        type: "number",
        minimum: 0,
        description: "Weight lifted in the user's weight unit.",
      },
      intensity: {
        type: "integer",
        minimum: 0,
        maximum: 5,
        description:
          "Effort level 0-5: 0=warm-up, 1=very light, 2=light, 3=moderate (default), 4=hard, 5=max.",
      },
      date: {
        type: "string",
        description: "ISO date yyyy-MM-dd. Defaults to today if omitted.",
      },
    },
    required: ["exerciseName", "reps", "weight"],
  },
};

const editWorkoutSet: ToolDefinition = {
  name: "editWorkoutSet",
  description:
    "Edit an existing workout set. Use when the user wants to correct reps, weight, or intensity on a " +
    "recent set. Obtain setId from recent_sets in context. Omit fields that should not change.",
  parameters: {
    type: "object",
    properties: {
      setId: {
        type: "string",
        description: "UUID of the set to edit from recent_sets context.",
      },
      exerciseName: {
        type: "string",
        description: "Human-readable name for the confirmation card.",
      },
      reps: { type: "integer", minimum: 1 },
      weight: { type: "number", minimum: 0 },
      intensity: { type: "integer", minimum: 0, maximum: 5 },
    },
    required: ["setId", "exerciseName"],
  },
};

const deleteWorkoutSet: ToolDefinition = {
  name: "deleteWorkoutSet",
  description:
    "Delete an existing workout set. Obtain setId from recent_sets in context. " +
    "Always confirm with the user before deleting.",
  parameters: {
    type: "object",
    properties: {
      setId: {
        type: "string",
        description: "UUID of the set to delete from recent_sets context.",
      },
      exerciseName: {
        type: "string",
        description: "Human-readable name for the confirmation card.",
      },
    },
    required: ["setId", "exerciseName"],
  },
};

const logNutrition: ToolDefinition = {
  name: "logNutrition",
  description:
    "Log a nutrition entry. Use when the user wants to record food/macros. Include mealId if the meal " +
    "exists in the library (from context); otherwise log by macros directly. " +
    "Always include mealName for the confirmation card.",
  parameters: {
    type: "object",
    properties: {
      mealName: {
        type: "string",
        description: 'Human-readable meal name, e.g. "Oats".',
      },
      mealId: {
        type: "string",
        description:
          "UUID if meal exists in library. Omit for direct macro log.",
      },
      gramsConsumed: {
        type: "number",
        minimum: 0,
        description: "Grams consumed. Required if mealId is set.",
      },
      proteinGrams: { type: "number", minimum: 0 },
      carbsGrams: { type: "number", minimum: 0 },
      fatGrams: { type: "number", minimum: 0 },
      calories: { type: "number", minimum: 0 },
      loggedAt: {
        type: "string",
        description: "ISO date yyyy-MM-dd. Defaults to today if omitted.",
      },
    },
    required: ["mealName"],
  },
};

const editNutritionLog: ToolDefinition = {
  name: "editNutritionLog",
  description:
    "Edit an existing nutrition log entry. Obtain logId from recent_nutrition_logs in context. " +
    "Omit fields that should not change.",
  parameters: {
    type: "object",
    properties: {
      logId: {
        type: "string",
        description:
          "UUID of the log to edit from recent_nutrition_logs context.",
      },
      mealName: {
        type: "string",
        description: "Human-readable name for the confirmation card.",
      },
      gramsConsumed: { type: "number", minimum: 0 },
      proteinGrams: { type: "number", minimum: 0 },
      carbsGrams: { type: "number", minimum: 0 },
      fatGrams: { type: "number", minimum: 0 },
      calories: { type: "number", minimum: 0 },
    },
    required: ["logId", "mealName"],
  },
};

const deleteNutritionLog: ToolDefinition = {
  name: "deleteNutritionLog",
  description:
    "Delete an existing nutrition log entry. Obtain logId from recent_nutrition_logs in context. " +
    "Always confirm with the user before deleting.",
  parameters: {
    type: "object",
    properties: {
      logId: {
        type: "string",
        description:
          "UUID of the log to delete from recent_nutrition_logs context.",
      },
      mealName: {
        type: "string",
        description: "Human-readable name for the confirmation card.",
      },
    },
    required: ["logId", "mealName"],
  },
};

// ── Query tools (client executes locally, speaks result — no confirmation) ──

const getWeeklyVolume: ToolDefinition = {
  name: "getWeeklyVolume",
  description:
    "Retrieve the user's workout sets for a given period, optionally filtered by muscle group or exercise. " +
    'Use when the user asks "how many X sets did I do last week / this week / recently".',
  parameters: {
    type: "object",
    properties: {
      muscleGroup: {
        type: "string",
        description:
          'Muscle group to filter by, e.g. "chest", "back". Omit for all.',
      },
      exerciseName: {
        type: "string",
        description: "Exercise name to filter by. Omit for all exercises.",
      },
      startDate: {
        type: "string",
        description: "ISO date yyyy-MM-dd. Defaults to start of current week.",
      },
      endDate: {
        type: "string",
        description: "ISO date yyyy-MM-dd. Defaults to today.",
      },
    },
    required: [],
  },
};

const getDailyMacros: ToolDefinition = {
  name: "getDailyMacros",
  description:
    "Retrieve total macros (protein, carbs, fat, calories) logged for a given day. " +
    'Use when the user asks "what did I eat today", "how many calories yesterday", etc.',
  parameters: {
    type: "object",
    properties: {
      date: {
        type: "string",
        description: "ISO date yyyy-MM-dd. Defaults to today if omitted.",
      },
    },
    required: [],
  },
};

const getRecentSets: ToolDefinition = {
  name: "getRecentSets",
  description:
    "Retrieve the user's most recent sets, optionally filtered by exercise name. " +
    'Use when the user asks "what did I last bench press" or "show me my recent squats".',
  parameters: {
    type: "object",
    properties: {
      exerciseName: {
        type: "string",
        description: "Exercise name to filter. Omit for all recent sets.",
      },
      limit: {
        type: "integer",
        minimum: 1,
        maximum: 10,
        description: "Max results. Default 5.",
      },
    },
    required: [],
  },
};

const getDailyNutritionLog: ToolDefinition = {
  name: "getDailyNutritionLog",
  description:
    "List the individual meals/foods the user logged on a given day (names and calories), " +
    'NOT just the macro totals. Use when the user asks "what did I eat today / yesterday / on <date>". ' +
    "For total calories/macros only, use getDailyMacros instead.",
  parameters: {
    type: "object",
    properties: {
      date: {
        type: "string",
        description: "ISO date yyyy-MM-dd. Defaults to today.",
      },
    },
    required: [],
  },
};

// ── Clarify pseudo-tool (client maps to plain text response) ────────────────

const clarify: ToolDefinition = {
  name: "clarify",
  description:
    "Ask the user ONE clarifying question before proceeding. Use when the user's intent is ambiguous " +
    "and a single question would resolve it. Do NOT use for general conversation — only for " +
    "resolving ambiguity about a logging or query action.",
  parameters: {
    type: "object",
    properties: {
      question: {
        type: "string",
        description: "The clarifying question to ask the user.",
      },
    },
    required: ["question"],
  },
};

export const TOOL_REGISTRY: ReadonlyArray<ToolDefinition> = [
  logWorkoutSet,
  editWorkoutSet,
  deleteWorkoutSet,
  logNutrition,
  editNutritionLog,
  deleteNutritionLog,
  getWeeklyVolume,
  getDailyMacros,
  getRecentSets,
  getDailyNutritionLog,
  clarify,
];

// ── Tool category helpers (used by voice-chat/index.ts) ─────────────────────

export const MUTATION_TOOLS: ReadonlySet<string> = new Set([
  "logWorkoutSet",
  "editWorkoutSet",
  "deleteWorkoutSet",
  "logNutrition",
  "editNutritionLog",
  "deleteNutritionLog",
]);

export const QUERY_TOOLS: ReadonlySet<string> = new Set([
  "getWeeklyVolume",
  "getDailyMacros",
  "getRecentSets",
  "getDailyNutritionLog",
]);
