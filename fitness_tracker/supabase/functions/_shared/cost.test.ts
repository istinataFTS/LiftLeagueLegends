import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { costForChat, PRICING_VERSION, round6 } from "./cost.ts";

Deno.test("PRICING_VERSION is a non-empty string", () => {
  assertEquals(typeof PRICING_VERSION, "string");
  assertEquals(PRICING_VERSION.length > 0, true);
});

Deno.test("costForChat: known token counts produce expected cost", () => {
  // 1 000 000 input tokens @ $0.150/M + 1 000 000 output tokens @ $0.600/M = $0.75
  const cost = costForChat("gpt-4o-mini-2024-07-18", 1_000_000, 1_000_000);
  assertEquals(cost, 0.75);
});

Deno.test("costForChat: 100 input + 50 output tokens", () => {
  const cost = costForChat("gpt-4o-mini-2024-07-18", 100, 50);
  const expected = round6(100 * (0.150 / 1_000_000) + 50 * (0.600 / 1_000_000));
  assertEquals(cost, expected);
});

Deno.test("costForChat: throws on unknown model", () => {
  assertThrows(
    () => costForChat("unknown-model" as never, 100, 100),
    Error,
  );
});

Deno.test("round6: rounds to 6 decimal places", () => {
  assertEquals(round6(0.1234567), 0.123457);
  assertEquals(round6(0.123456), 0.123456);
  assertEquals(round6(0), 0);
});

Deno.test("round6: round-trip precision matches DB numeric(10,6)", () => {
  const val = 0.000432;
  assertEquals(round6(val), val);
});
