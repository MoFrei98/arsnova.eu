#!/usr/bin/env node
// Handsession-Treiber Labor Thema 4: kleine Q&A-Session mit den sechs Referenzfragen aus
// #456 §12, bedient über dieselbe tRPC-API wie Host- und Teilnehmeransicht.
//
//   node lab-thema4/probes/handsession.mjs create         Session anlegen, 6 Fragen, 2 Upvotes
//   node lab-thema4/probes/handsession.mjs ask [Text]     neue Frage (neuer Snapshot)
//   node lab-thema4/probes/handsession.mjs vote           eine weitere Stimme abgeben
//   node lab-thema4/probes/handsession.mjs request [ms]   Summary anfordern und auf Ergebnis warten
//   node lab-thema4/probes/handsession.mjs runtime        Laufzeitstand einmal abfragen
//   node lab-thema4/probes/handsession.mjs preview        Kontextvorschau (Kernwerte)
//
// Jeder Befehl gibt genau eine JSON-Zeile aus. Der Zustand (Host-Token, Teilnehmer-Capabilities)
// liegt außerhalb des Repos in $HAND_STATE (Standard ~/lab-hand-state.json) und wird nie committet.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createHttpTrpcSingle } from '../../scripts/load/lib/trpc-runtime.mjs';
import { configureQaSessionIfNeeded } from '../../scripts/load/lib/configure-qa-if-needed.mjs';

const TRPC_URL = String(process.env.TRPC_URL || 'http://127.0.0.1:3000/trpc').trim();
const STATE = process.env.HAND_STATE || join(homedir(), 'lab-hand-state.json');
const REFERENCE_QUESTIONS = [
  'Können wir mehr Beispiele zur linearen Regression bearbeiten?',
  'Gibt es ein weiteres Beispiel zur linearen Regression?',
  'Ist Kapitel 4 klausurrelevant?',
  'Müssen wir den vierten Abschnitt für die Prüfung lernen?',
  'Soll die Anwesenheit verpflichtend sein?',
  'Sollten wir eine Anwesenheitspflicht einführen?',
];

const nowIso = () => new Date().toISOString();
const out = (record) => process.stdout.write(`${JSON.stringify({ at: nowIso(), ...record })}\n`);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function loadState() {
  if (!existsSync(STATE)) throw new Error(`Kein Handsession-Zustand in ${STATE}. Erst "create".`);
  return JSON.parse(readFileSync(STATE, 'utf8'));
}
function saveState(state) {
  writeFileSync(STATE, JSON.stringify(state, null, 2), { mode: 0o600 });
}

/** Roh-HTTP-Aufruf, damit HTTP-Status und Dauer sichtbar bleiben. */
async function call(kind, procedure, input, headers) {
  const started = performance.now();
  const url =
    kind === 'query'
      ? `${TRPC_URL}/${procedure}?input=${encodeURIComponent(JSON.stringify(input))}`
      : `${TRPC_URL}/${procedure}`;
  const response = await fetch(url, {
    method: kind === 'query' ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: kind === 'query' ? undefined : JSON.stringify(input),
  });
  const body = await response.json().catch(() => null);
  return {
    httpStatus: response.status,
    ms: Math.round(performance.now() - started),
    data: body?.result?.data ?? null,
    error: body?.error ? { code: body.error.data?.code ?? null, message: body.error.message } : null,
  };
}

function describe(runtime) {
  const r = runtime?.result;
  if (!r) return { status: null };
  return {
    status: r.status,
    effectiveMode: r.execution?.effectiveMode ?? null,
    attemptedMode: r.execution?.attemptedMode ?? null,
    fallbackReason: r.execution?.fallback?.reason ?? null,
    retry: r.execution?.fallback?.retry ?? null,
    statements: r.statements?.length ?? 0,
    sources: r.sources?.length ?? 0,
    limitations: r.limitations ?? [],
    modelVersion: r.modelVersion ?? null,
    snapshotHash: r.snapshotHash ? `${r.snapshotHash.slice(0, 12)}…` : null,
    analyzedAt: r.analyzedAt ?? null,
  };
}

async function create() {
  const publicTrpc = createHttpTrpcSingle(TRPC_URL);
  const { code, hostToken, sessionId } = await publicTrpc.session.create.mutate({
    type: 'Q_AND_A',
    title: `Labor Thema 4 Handsession ${new Date().toISOString().slice(0, 16)}`,
    moderationMode: false,
    qaModerationMode: false,
    quickFeedbackEnabled: false,
    allowCustomNicknames: true,
    nicknameTheme: 'HIGH_SCHOOL',
    anonymousMode: false,
    teamMode: false,
  });
  const hostTrpc = createHttpTrpcSingle(TRPC_URL, hostToken);
  await configureQaSessionIfNeeded(hostTrpc, code, { qaTitle: 'Labor Handsession' });
  const participants = [];
  for (let index = 0; index < 3; index += 1) {
    const joined = await publicTrpc.session.join.mutate({
      code,
      nickname: `Labor ${index + 1}`,
      anonymousClientId: globalThis.crypto.randomUUID(),
      joinIdempotencyKey: globalThis.crypto.randomUUID(),
    });
    participants.push({ participantId: joined.participantId, capability: joined.rejoinToken });
  }
  await hostTrpc.session.startQa.mutate({ code });
  const state = { code, sessionId, hostToken, participants, questions: [], votes: 0, asked: 0 };
  // Fragen A, C, E von Teilnehmer 1; B, D, F von Teilnehmer 2.
  for (let index = 0; index < REFERENCE_QUESTIONS.length; index += 1) {
    const author = participants[index % 2];
    const client = createHttpTrpcSingle(TRPC_URL, undefined, undefined, undefined, author.capability);
    const created = await client.qa.submit.mutate({
      sessionId,
      participantId: author.participantId,
      text: REFERENCE_QUESTIONS[index],
      idempotencyKey: globalThis.crypto.randomUUID(),
    });
    state.questions.push({ id: created.question.id, text: created.question.text });
  }
  saveState(state);
  for (let i = 0; i < 2; i += 1) await vote(state, false);
  out({ cmd: 'create', code, sessionId, questions: state.questions.length, votes: state.votes });
}

async function ask(text) {
  const state = loadState();
  state.asked += 1;
  const author = state.participants[state.asked % 2];
  const client = createHttpTrpcSingle(TRPC_URL, undefined, undefined, undefined, author.capability);
  const questionText = text || `Laborfrage ${state.asked}: Wie hängen die Beispiele mit der Klausur zusammen?`;
  const started = performance.now();
  const created = await client.qa.submit.mutate({
    sessionId: state.sessionId,
    participantId: author.participantId,
    text: questionText,
    idempotencyKey: globalThis.crypto.randomUUID(),
  });
  state.questions.push({ id: created.question.id, text: created.question.text });
  saveState(state);
  out({ cmd: 'ask', ms: Math.round(performance.now() - started), questions: state.questions.length });
}

async function vote(state = loadState(), print = true) {
  // Teilnehmer 3 stimmt reihum für die Fragen, jede höchstens einmal.
  const voter = state.participants[2];
  const target = state.questions[state.votes % state.questions.length];
  const client = createHttpTrpcSingle(TRPC_URL, undefined, undefined, undefined, voter.capability);
  const started = performance.now();
  await client.qa.vote.mutate({
    questionId: target.id,
    participantId: voter.participantId,
    direction: 'UP',
  });
  state.votes += 1;
  saveState(state);
  if (print) out({ cmd: 'vote', ms: Math.round(performance.now() - started), question: target.text });
}

async function request(maxWaitMs) {
  const state = loadState();
  const headers = { 'x-host-token': state.hostToken };
  const started = performance.now();
  const enqueue = await call('mutation', 'qa.requestSummary', { sessionId: state.sessionId, locale: 'de' }, headers);
  let runtime = enqueue.data;
  const polls = [];
  while (runtime?.result?.status === 'pending' && performance.now() - started < maxWaitMs) {
    await sleep(250);
    const poll = await call('query', 'qa.summaryRuntime', { sessionId: state.sessionId }, headers);
    polls.push(poll.httpStatus);
    runtime = poll.data ?? runtime;
  }
  out({
    cmd: 'request',
    enqueueHttp: enqueue.httpStatus,
    enqueueMs: enqueue.ms,
    enqueueError: enqueue.error,
    enqueueStatus: enqueue.data?.result?.status ?? null,
    pollHttp: [...new Set(polls)],
    totalMs: Math.round(performance.now() - started),
    ...describe(runtime),
  });
}

async function runtimeOnce() {
  const state = loadState();
  const poll = await call('query', 'qa.summaryRuntime', { sessionId: state.sessionId }, {
    'x-host-token': state.hostToken,
  });
  out({ cmd: 'runtime', http: poll.httpStatus, ms: poll.ms, error: poll.error, ...describe(poll.data) });
}

async function preview() {
  const state = loadState();
  const result = await call('query', 'qa.summaryContextPreview', { sessionId: state.sessionId, locale: 'de' }, {
    'x-host-token': state.hostToken,
  });
  const p = result.data;
  out({
    cmd: 'preview',
    http: result.httpStatus,
    selectedMode: p?.selectedMode ?? null,
    fallback: p?.fallback ?? null,
    questionCorpus: p?.promptContext?.context?.questions?.corpus ?? null,
    represented: p?.promptContext?.context?.questions?.corpus?.represented ?? null,
    sourceCount: p?.promptContext?.context?.sources?.length ?? null,
    packedInputTokens: p?.promptContext?.budget?.packedInputTokens ?? null,
    truncations: p?.promptContext?.budget?.truncations ?? null,
  });
}

const [command, arg] = process.argv.slice(2);
try {
  if (command === 'create') await create();
  else if (command === 'ask') await ask(arg);
  else if (command === 'vote') await vote();
  else if (command === 'request') await request(Number(arg) || 60_000);
  else if (command === 'runtime') await runtimeOnce();
  else if (command === 'preview') await preview();
  else throw new Error('Befehl: create | ask | vote | request [ms] | runtime | preview');
} catch (error) {
  out({ cmd: command, error: error instanceof Error ? error.message : String(error) });
  process.exitCode = 1;
}
