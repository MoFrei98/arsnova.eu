// Budget-Probe Labor Thema 4 (read-only): Wie setzt sich das 4.096er-Budget der
// Summary V2 für die Release-Fixtures zusammen, und wie groß wäre der volle Kontext?
//
// Ausführen im Repo-Root (Windows-Checkout mit node_modules und generiertem Prisma-Client):
//   npx tsx lab-thema4/probes/budget-probe.ts
// Schreibt nach lab-thema4/rohdaten/budget/: budget-probe.json und die gepackten
// Kontexte als kanonisches JSON (Eingabe für tokenize-probe.sh).
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  MODERATION_ANALYSIS_CONTEXT_CONTRACT_VERSION,
  MODERATION_PROMPT_CONTEXT_MINIMAL_FIXTURE_V1,
  MODERATION_PROMPT_CONTEXT_REFERENCE_FIXTURE_V1,
  ModerationAnalysisContextV1Schema,
} from '@arsnova/shared-types';
import {
  QA_SUMMARY_MODERATION_PACKING_PROFILE as PROFILE,
  QA_SUMMARY_TECHNICAL_DEFINITION_TEXT,
  QA_SUMMARY_TECHNICAL_INSTRUCTION_TEXT,
  prepareModerationSummaryContextFromAnalysis,
} from '../../apps/backend/src/lib/moderationSummaryContext';
import {
  canonicalModerationPromptJson,
  packModerationPromptContext,
} from '../../apps/backend/src/lib/moderationPromptContextPacking';

const OUT_DIR = join('lab-thema4', 'rohdaten', 'budget');
mkdirSync(OUT_DIR, { recursive: true });

function analysis(fixture: typeof MODERATION_PROMPT_CONTEXT_REFERENCE_FIXTURE_V1) {
  const clone = structuredClone(fixture);
  return ModerationAnalysisContextV1Schema.parse({
    schemaVersion: clone.schemaVersion,
    contractVersion: MODERATION_ANALYSIS_CONTEXT_CONTRACT_VERSION,
    assembledAt: '2026-01-15T10:05:00.000Z',
    context: { ...clone.context, locale: 'de', representation: 'analysis-candidates' },
  });
}

const fixtures = {
  minimal: MODERATION_PROMPT_CONTEXT_MINIMAL_FIXTURE_V1,
  reference_six_questions: MODERATION_PROMPT_CONTEXT_REFERENCE_FIXTURE_V1,
} as const;

const result: Record<string, unknown> = {
  profile: {
    modelProfile: PROFILE.modelProfile,
    contextWindowTokens: PROFILE.contextWindowTokens,
    reservedOutputTokens: PROFILE.reservedOutputTokens,
    safetyMarginTokens: PROFILE.safetyMarginTokens,
    estimator: '1 UTF-8-Byte = 1 Token (estimateModerationPromptUtf8Tokens)',
  },
};

for (const [name, fixture] of Object.entries(fixtures)) {
  const input = analysis(fixture as typeof MODERATION_PROMPT_CONTEXT_REFERENCE_FIXTURE_V1);
  const prepared = prepareModerationSummaryContextFromAnalysis({ analysis: input });
  const budget = prepared.request.promptContext.budget;
  const unbounded = packModerationPromptContext({
    analysis: input,
    profile: { ...PROFILE, contextWindowTokens: 65_536 },
  });
  const sources = prepared.request.promptContext.context.sources;
  result[name] = {
    packed4096: {
      instructionTokens: budget.instructionTokens,
      definitionTokens: budget.definitionTokens,
      dataTokens: budget.dataTokens,
      packedInputTokens: budget.packedInputTokens,
      freeAfterPacking:
        PROFILE.contextWindowTokens -
        PROFILE.reservedOutputTokens -
        PROFILE.safetyMarginTokens -
        budget.packedInputTokens,
      sources: sources.length,
      sourceKinds: sources.map((source) => source.kind),
      truncations: budget.truncations,
    },
    unboundedWindow: {
      dataTokens: unbounded.budget.dataTokens,
      packedInputTokens: unbounded.budget.packedInputTokens,
      sources: unbounded.context.sources.length,
    },
  };
  writeFileSync(
    join(OUT_DIR, `packed-4096-${name}.json`),
    canonicalModerationPromptJson(prepared.request.promptContext.context),
  );
  writeFileSync(
    join(OUT_DIR, `packed-unbounded-${name}.json`),
    canonicalModerationPromptJson(unbounded.context),
  );
}
writeFileSync(join(OUT_DIR, 'instruction.txt'), QA_SUMMARY_TECHNICAL_INSTRUCTION_TEXT);
writeFileSync(join(OUT_DIR, 'definition.txt'), QA_SUMMARY_TECHNICAL_DEFINITION_TEXT);
writeFileSync(join(OUT_DIR, 'budget-probe.json'), `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify(result, null, 2));
