export type FunctionName = "voice-chat" | "voice-transcribe";

export interface AuthedUser {
  readonly id: string; // auth.users.id (uuid)
  readonly jwt: string; // raw JWT, used for user-scoped DB reads
}

export interface UsageMetrics {
  readonly inputTokens?: number;
  readonly outputTokens?: number;
}

export interface UsageLogInput extends UsageMetrics {
  readonly userId: string;
  readonly functionName: FunctionName;
  readonly model: string;
  readonly latencyMs: number;
  readonly sessionId?: string;
  readonly status: string; // 'OK' or structured error code
}

export type Turn =
  | { role: "user"; content: string }
  | { role: "assistant"; content: string; toolCall?: ToolCall }
  | { role: "tool"; content: string; toolCallId: string };

export interface ToolCall {
  readonly id: string;
  readonly name: string;
  readonly arguments: Record<string, unknown>;
}

export interface RecentSetContext {
  readonly setId: string;
  readonly exerciseName: string;
  readonly weight: number;
  readonly reps: number;
  readonly intensity: number;
  readonly date: string; // ISO yyyy-MM-dd
}

export interface RecentNutritionLogContext {
  readonly logId: string;
  readonly mealName: string;
  readonly calories: number;
  readonly date: string; // ISO yyyy-MM-dd
}

export interface VoiceContext {
  readonly currentDate: string; // ISO yyyy-MM-dd
  readonly weightUnit: "kg" | "lb";
  readonly recentExerciseIds?: readonly string[];
  readonly recentSets?: readonly RecentSetContext[];
  readonly recentNutritionLogs?: readonly RecentNutritionLogContext[];
}
