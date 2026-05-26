import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';

const WORKFLOW_PATH = '../../../.github/workflows/supabase-deploy.yml';

Deno.test('supabase-deploy workflow uses auto-discovery (no hardcoded function names)', async () => {
  const yaml = await Deno.readTextFile(new URL(WORKFLOW_PATH, import.meta.url));

  // Locate the Deploy functions step.
  const deployStepMatch = yaml.match(/name:\s*Deploy functions[\s\S]*?(?=- name:|\Z)/);
  assert(deployStepMatch, 'Deploy functions step not found in workflow');
  const step = deployStepMatch[0];

  // Auto-discovery markers we expect.
  assert(
    step.includes('for dir in supabase/functions/*/'),
    'Deploy step must iterate supabase/functions/*/ — found hardcoded form instead',
  );
  assert(
    step.includes('supabase functions deploy "$name"'),
    'Deploy step must deploy by enumerated $name, not a literal',
  );

  // Anti-pattern check: no `supabase functions deploy <literal-name>`.
  const literalDeploy = step.match(/supabase functions deploy (?!"\$name")(\S+)/);
  assertEquals(
    literalDeploy,
    null,
    `Found hardcoded function name in deploy step: ${literalDeploy?.[1]} — use auto-discovery`,
  );
});

Deno.test('supabase-deploy workflow has a smoke-test step', async () => {
  const yaml = await Deno.readTextFile(new URL(WORKFLOW_PATH, import.meta.url));
  assert(
    /name:\s*Smoke-test deployed functions/.test(yaml),
    'Smoke-test step is missing — re-add it to prevent silent function-missing regressions',
  );
});
