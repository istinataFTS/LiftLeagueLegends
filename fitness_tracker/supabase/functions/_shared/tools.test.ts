import { assertEquals, assertNotEquals } from "@std/assert";
import { MUTATION_TOOLS, QUERY_TOOLS, TOOL_REGISTRY } from "./tools.ts";

// ── Registry shape ───────────────────────────────────────────────────────────

Deno.test("tools: every tool has name, description, and parameters.type == object", () => {
  for (const tool of TOOL_REGISTRY) {
    assertNotEquals(tool.name, "", `Tool name must not be empty`);
    assertNotEquals(
      tool.description,
      "",
      `Tool "${tool.name}" description must not be empty`,
    );

    const params = tool.parameters as Record<string, unknown>;
    assertEquals(
      params.type,
      "object",
      `Tool "${tool.name}" parameters.type must be "object"`,
    );
  }
});

Deno.test("tools: every required field is present in properties", () => {
  for (const tool of TOOL_REGISTRY) {
    const params = tool.parameters as {
      properties?: Record<string, unknown>;
      required?: string[];
    };
    const properties = params.properties ?? {};
    const required = params.required ?? [];
    for (const field of required) {
      assertEquals(
        field in properties,
        true,
        `Tool "${tool.name}" required field "${field}" is missing from properties`,
      );
    }
  }
});

// ── Echo removal gate ────────────────────────────────────────────────────────

Deno.test("tools: echo tool is NOT present in TOOL_REGISTRY", () => {
  const names = TOOL_REGISTRY.map((t) => t.name);
  assertEquals(
    names.includes("echo"),
    false,
    "echo stub must be removed from TOOL_REGISTRY in C-5",
  );
});

// ── MUTATION_TOOLS ───────────────────────────────────────────────────────────

Deno.test("tools: MUTATION_TOOLS contains exactly the 6 mutation tool names", () => {
  const expected = new Set([
    "logWorkoutSet",
    "editWorkoutSet",
    "deleteWorkoutSet",
    "logNutrition",
    "editNutritionLog",
    "deleteNutritionLog",
  ]);
  assertEquals(
    MUTATION_TOOLS.size,
    6,
    "MUTATION_TOOLS must have exactly 6 entries",
  );
  for (const name of expected) {
    assertEquals(
      MUTATION_TOOLS.has(name),
      true,
      `MUTATION_TOOLS must contain "${name}"`,
    );
  }
});

// ── QUERY_TOOLS ──────────────────────────────────────────────────────────────

Deno.test("tools: QUERY_TOOLS contains exactly the 6 query tool names", () => {
  const expected = new Set([
    "getWeeklyVolume",
    "getDailyMacros",
    "getRecentSets",
    "getDailyNutritionLog",
    "getWorkoutForDay",
    "getTrainingDays",
  ]);
  assertEquals(QUERY_TOOLS.size, 6, "QUERY_TOOLS must have exactly 6 entries");
  for (const name of expected) {
    assertEquals(
      QUERY_TOOLS.has(name),
      true,
      `QUERY_TOOLS must contain "${name}"`,
    );
  }
});

// ── Registry completeness ────────────────────────────────────────────────────

Deno.test("tools: TOOL_REGISTRY contains exactly 13 tools", () => {
  assertEquals(
    TOOL_REGISTRY.length,
    13,
    "TOOL_REGISTRY must have exactly 13 tools",
  );
});

Deno.test("tools: all mutation and query tools are present in TOOL_REGISTRY", () => {
  const registryNames = new Set(TOOL_REGISTRY.map((t) => t.name));
  for (const name of MUTATION_TOOLS) {
    assertEquals(
      registryNames.has(name),
      true,
      `TOOL_REGISTRY must contain mutation tool "${name}"`,
    );
  }
  for (const name of QUERY_TOOLS) {
    assertEquals(
      registryNames.has(name),
      true,
      `TOOL_REGISTRY must contain query tool "${name}"`,
    );
  }
});

Deno.test("tools: clarify tool is present in TOOL_REGISTRY", () => {
  const names = TOOL_REGISTRY.map((t) => t.name);
  assertEquals(
    names.includes("clarify"),
    true,
    "TOOL_REGISTRY must contain the clarify tool",
  );
});

// ── Per-tool required fields ──────────────────────────────────────────────────

Deno.test("tools: logWorkoutSet requires exerciseName, reps, weight", () => {
  const tool = TOOL_REGISTRY.find((t) => t.name === "logWorkoutSet")!;
  const required = (tool.parameters as { required: string[] }).required;
  assertEquals(required.includes("exerciseName"), true);
  assertEquals(required.includes("reps"), true);
  assertEquals(required.includes("weight"), true);
});

Deno.test("tools: editWorkoutSet requires setId and exerciseName", () => {
  const tool = TOOL_REGISTRY.find((t) => t.name === "editWorkoutSet")!;
  const required = (tool.parameters as { required: string[] }).required;
  assertEquals(required.includes("setId"), true);
  assertEquals(required.includes("exerciseName"), true);
});

Deno.test("tools: deleteWorkoutSet requires setId and exerciseName", () => {
  const tool = TOOL_REGISTRY.find((t) => t.name === "deleteWorkoutSet")!;
  const required = (tool.parameters as { required: string[] }).required;
  assertEquals(required.includes("setId"), true);
  assertEquals(required.includes("exerciseName"), true);
});

Deno.test("tools: logNutrition requires mealName", () => {
  const tool = TOOL_REGISTRY.find((t) => t.name === "logNutrition")!;
  const required = (tool.parameters as { required: string[] }).required;
  assertEquals(required.includes("mealName"), true);
});

Deno.test("tools: editNutritionLog requires logId and mealName", () => {
  const tool = TOOL_REGISTRY.find((t) => t.name === "editNutritionLog")!;
  const required = (tool.parameters as { required: string[] }).required;
  assertEquals(required.includes("logId"), true);
  assertEquals(required.includes("mealName"), true);
});

Deno.test("tools: deleteNutritionLog requires logId and mealName", () => {
  const tool = TOOL_REGISTRY.find((t) => t.name === "deleteNutritionLog")!;
  const required = (tool.parameters as { required: string[] }).required;
  assertEquals(required.includes("logId"), true);
  assertEquals(required.includes("mealName"), true);
});

Deno.test("tools: clarify requires question", () => {
  const tool = TOOL_REGISTRY.find((t) => t.name === "clarify")!;
  const required = (tool.parameters as { required: string[] }).required;
  assertEquals(required.includes("question"), true);
});

Deno.test("tools: getTrainingDays is registered and in QUERY_TOOLS, not MUTATION_TOOLS", () => {
  const registryNames = new Set(TOOL_REGISTRY.map((t) => t.name));
  assertEquals(
    registryNames.has("getTrainingDays"),
    true,
    "TOOL_REGISTRY must contain getTrainingDays",
  );
  assertEquals(
    QUERY_TOOLS.has("getTrainingDays"),
    true,
    "QUERY_TOOLS must contain getTrainingDays",
  );
  assertEquals(
    MUTATION_TOOLS.has("getTrainingDays"),
    false,
    "MUTATION_TOOLS must NOT contain getTrainingDays",
  );
});

Deno.test("tools: getWorkoutForDay is registered and in QUERY_TOOLS, not MUTATION_TOOLS", () => {
  const registryNames = new Set(TOOL_REGISTRY.map((t) => t.name));
  assertEquals(
    registryNames.has("getWorkoutForDay"),
    true,
    "TOOL_REGISTRY must contain getWorkoutForDay",
  );
  assertEquals(
    QUERY_TOOLS.has("getWorkoutForDay"),
    true,
    "QUERY_TOOLS must contain getWorkoutForDay",
  );
  assertEquals(
    MUTATION_TOOLS.has("getWorkoutForDay"),
    false,
    "MUTATION_TOOLS must NOT contain getWorkoutForDay",
  );
});

Deno.test("tools: getDailyNutritionLog is registered and in QUERY_TOOLS, not MUTATION_TOOLS", () => {
  const registryNames = new Set(TOOL_REGISTRY.map((t) => t.name));
  assertEquals(
    registryNames.has("getDailyNutritionLog"),
    true,
    "TOOL_REGISTRY must contain getDailyNutritionLog",
  );
  assertEquals(
    QUERY_TOOLS.has("getDailyNutritionLog"),
    true,
    "QUERY_TOOLS must contain getDailyNutritionLog",
  );
  assertEquals(
    MUTATION_TOOLS.has("getDailyNutritionLog"),
    false,
    "MUTATION_TOOLS must NOT contain getDailyNutritionLog",
  );
});

Deno.test("tools: query tools have no required fields", () => {
  for (const name of QUERY_TOOLS) {
    const tool = TOOL_REGISTRY.find((t) => t.name === name)!;
    const required = (tool.parameters as { required: string[] }).required;
    assertEquals(
      required.length,
      0,
      `Query tool "${name}" must have no required fields`,
    );
  }
});

Deno.test("tools: day-scoped query tools instruct model to resolve dates explicitly", () => {
  const dayTools = [
    "getDailyNutritionLog",
    "getDailyMacros",
    "getWorkoutForDay",
  ];
  for (const name of dayTools) {
    const tool = TOOL_REGISTRY.find((t) => t.name === name)!;
    const dateDesc = (tool.parameters as {
      properties: Record<string, { description: string }>;
    })
      .properties.date.description;
    assertEquals(
      dateDesc.includes("do not default to today"),
      true,
      `Tool "${name}" date description must instruct not to default to today`,
    );
  }
});
