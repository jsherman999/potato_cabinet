# Potato Cabinet — Build Plan

A single-file, in-browser simulation of a functioning U.S. presidential cabinet.
Each of the 15 cabinet secretaries is an LLM agent; a "chief of staff" orchestrator
agent decomposes a problem, dispatches work to the relevant departments, coordinates
them to completion, and synthesizes a result. An optional "president" agent can
replace the human by scanning current news, picking a solvable problem, and handing
an Executive Plan to the chief of staff.

The cabinet is rendered as talking potatoes.

---

## 1. Assumptions & key decisions (stated, not silently chosen)

Per CLAUDE.md §1, these are the interpretations I'm committing to. Each is a place
the design could go another way; flag any you want changed before build.

1. **One self-contained `index.html`.** All HTML/CSS/JS inlined. **No build step and
   no external runtime dependencies** (no React/Vue CDN, no bundler). Pure vanilla JS.
   The readme's "embed all needed scripting… in the html, if possible" is read as a
   hard requirement, and CDN script tags count as external hosting, so we avoid them.
2. **API calls go directly from the browser** to OpenRouter / OpenAI / Anthropic.
   This is feasible because all three support CORS:
   - OpenAI & OpenRouter: standard CORS on `/chat/completions`.
   - Anthropic: requires the request header `anthropic-dangerous-direct-browser-access: true`
     plus `anthropic-version: 2023-06-01`.
3. **Keys are entered at runtime** in a settings panel and kept in `localStorage`
   (with a "forget keys" button). This is a single-user local tool, so the user's own
   keys living in their own browser is acceptable; we will say so plainly in the UI and
   never transmit keys anywhere except the three model providers.
4. **Models are configurable in a `CONFIG` constants block** at the top of the script,
   defaulting to (readme-driven + validated live on 2026-06-15, see §11):
   - Secretaries (×15): a cheap, capable model — default **`openai/gpt-4o-mini`** via
     OpenRouter. Validated ultra-cheap alternative: **`qwen/qwen3-235b-a22b-2507`**
     ($0.09/$0.10 per 1M) which routed and grounded as well as far pricier models.
     Configurable per seat.
   - Orchestrator (chief of staff): higher capability — default **`claude-sonnet-4-6`**
     (Anthropic). The JSON decomposition step is also handled cleanly by
     **`openai/gpt-4.1-mini`** (user's pick for JSON/text; validated), a cheaper option.
   - President: **`claude-opus-4-8`** (Anthropic), per readme.
   - **Web-research role** (president's news snapshot; link/attachment enrichment):
     **`google/gemini-2.5-flash:online`** via OpenRouter (user's pick for inexpensive web
     research; the `:online` suffix enables web search and returns citations — validated).
5. **Voice** uses the built-in browser **Web Speech API** (`speechSynthesis`) — no
   dependency, works offline, distinct voice/pitch per potato. Quality varies by OS;
   it is optional and toggleable.
6. **President's "news snapshot"**: default path is the Anthropic **`web_search`
   server-side tool** (works from a direct browser call, runs server-side). Fallback:
   a textarea where the user pastes headlines. No backend is introduced.
7. **Links/attachments in user input**: handled by (a) a file input the browser reads
   locally, and (b) a paste-the-text box. Arbitrary URL fetching is CORS-limited in the
   browser, so links are passed as text to web-search/web-fetch-capable models rather
   than fetched by our JS.

Open question worth your call before/at build (non-blocking — I'll default as above):
the **default secretary model**. `gpt-4o-mini` via OpenRouter is the cheap default;
if you'd rather default to a stronger model (e.g. `claude-haiku-4-5` or a larger
OpenRouter model) say so and I'll set it.

---

## 2. The cabinet (drives the system prompts)

The 15 statutory executive departments, in order of presidential succession, each with
a one-line scope used to seed its agent's system prompt:

| # | Seat | Department | Core responsibility (prompt seed) |
|---|------|-----------|-----------------------------------|
| 1 | Secretary of State | State | Foreign policy, diplomacy, treaties, embassies |
| 2 | Secretary of the Treasury | Treasury | Federal finance, taxation, debt, sanctions, currency |
| 3 | Secretary of Defense | Defense | Military forces, national defense operations |
| 4 | Attorney General | Justice | Federal law enforcement, prosecution, civil rights |
| 5 | Secretary of the Interior | Interior | Public lands, natural resources, national parks, tribal affairs |
| 6 | Secretary of Agriculture | USDA | Farming, food supply, rural development, nutrition programs |
| 7 | Secretary of Commerce | Commerce | Trade, business, economic data, weather (NOAA), patents |
| 8 | Secretary of Labor | Labor | Workforce, wages, workplace safety, unemployment |
| 9 | Secretary of Health and Human Services | HHS | Public health, Medicare/Medicaid, FDA, CDC |
| 10 | Secretary of Housing and Urban Development | HUD | Housing, urban development, homelessness |
| 11 | Secretary of Transportation | DOT | Highways, aviation, rail, transit safety |
| 12 | Secretary of Energy | Energy | Energy policy, the grid, nuclear security, R&D |
| 13 | Secretary of Education | Education | Schools, student aid, education policy |
| 14 | Secretary of Veterans Affairs | VA | Veteran healthcare, benefits, services |
| 15 | Secretary of Homeland Security | DHS | Borders, immigration, disaster response (FEMA), cybersecurity |

Plus the **Chief of Staff** (orchestrator) and the **President** (optional driver).

This table is the single source of truth: it generates the avatars, the labels, and
each agent's system prompt.

---

## 3. Architecture

```
                ┌──────────────────────────────────────────────┐
   Human  ───►  │  Chief of Staff (orchestrator)                │
   (or)         │   1. decompose problem → which departments    │
   President ─► │   2. write a task brief per department        │
                │   3. dispatch (parallel) & await results      │
                │   4. coordinate (optional 2nd round)          │
                │   5. synthesize final solution                │
                └───────┬───────────────────────┬──────────────┘
                        │ task briefs            │ results
                ┌───────▼───────┐        ┌───────▼───────┐
                │ Secretary A   │  ...   │ Secretary N   │   (15 agents)
                └───────────────┘        └───────────────┘
```

Modules inside the single file (logical sections, not separate files):

- **`CONFIG`** — providers, default models per role, endpoints, toggles, voice settings.
- **`CABINET`** — the table above as data; generates prompts + UI.
- **`providers.js` (inline)** — one `callLLM({provider, model, system, messages, tools?, json?})`
  that normalizes the three APIs:
  - OpenAI / OpenRouter: `POST /chat/completions`, `system` folded into messages,
    `response_format: {type:"json_object"}` when `json`.
  - Anthropic: `POST /v1/messages`, `system` top-level, `messages` as content blocks,
    `web_search`/`web_fetch` server tools when requested, browser-access header set.
  Returns a normalized `{text, toolResults?, usage}`.
- **`orchestrator.js` (inline)** — the decompose → dispatch → synthesize loop. The
  decomposition step asks the model for **structured JSON**:
  `{ "assignments": [ { "seat": "USDA", "brief": "…", "priority": 1 } ], "rationale": "…" }`
  so dispatch is deterministic and not regex-parsed from prose.
- **`agents.js` (inline)** — per-secretary call wrappers; each carries its department
  system prompt + the current task context so it can answer questions later.
- **`ui.js` (inline)** — the potato grid, status/animation, speech bubbles, chat,
  per-potato Q&A.
- **`tts.js` (inline)** — `speechSynthesis` wrapper, one voice profile per seat.
- **`state`** — a single `appState` object + a `render()` function (minimal reactive
  pattern; re-render on change). No framework.

---

## 4. Orchestration flow (the core loop)

1. **Intake.** User (or president) submits an English problem, optionally with pasted
   text / a read-in file. Stored as the "case file."
2. **Decompose.** Chief of staff is prompted with the case file + the cabinet table and
   returns the JSON `assignments` (which departments, and a tailored brief for each).
   Few-shot examples seeded from the readme:
   - *Drought / farmer revenue shortfall* → `[USDA]` with a brief to draft temporary
     funding via existing USDA programs.
   - *Threatening military buildup in Europe* → `[State, Defense]` with a coordinated
     mitigation brief for each, and `coordination: true`.
3. **Announce & dispatch.** Each assigned potato announces "I've been tasked…" (text +
   optional voice), enters `working` state, and its agent is called **in parallel**.
4. **Collect.** Each secretary returns a department response; potato announces
   completion and flips to `done`.
5. **Coordinate (optional).** If `coordination: true`, the chief of staff feeds the
   first-round results back to the involved secretaries for one alignment round
   (e.g. State and Defense reconcile their plans).
6. **Synthesize.** Chief of staff merges department outputs into one "single general
   solution," shown in the main transcript.
7. **Q&A stays live.** After completion the case file remains in context so the user can
   click any secretary and ask follow-ups.

---

## 5. UI

- **Layout:** president centered on top; 15 secretaries in a responsive grid below.
  Each tile = animated potato avatar + name label + department label + a status pip.
- **Potato avatar:** inline **SVG** potato with a `<path>` mouth that animates open/closed
  while `speaking`; eyes; a small department glyph/color accent. CSS keyframes for idle
  bob; mouth animation driven by speech (toggle on `speechSynthesis` boundary events, or
  a simple interval while speaking if boundary events are unavailable).
- **States** (drive border/pip color + animation): `idle`, `assigned`, `working`
  (pulsing), `done`, `speaking`, `error`.
- **Speech bubble** above each potato shows its latest line (announcement / answer).
- **Main panel:** the case-file input (text + file input + paste box), a "Run" button,
  a "President: auto-pick a problem" button, and the running transcript of orchestrator
  + department messages.
- **Per-potato Q&A:** click a potato → input box → its agent answers, scoped to (a) the
  current case file if relevant, else (b) general department responsibilities.
- **Settings panel:** API keys (3), per-role model overrides, voice on/off, "forget keys."

---

## 6. Voice (optional)

- `speechSynthesis.getVoices()` → assign each seat a stable
  `{voiceURI, pitch, rate}` profile (deterministic by index) so each potato sounds
  distinct. President gets a distinct, slower, lower profile.
- Speak on: assignment announcement, completion announcement, and Q&A answers.
- A global mute toggle; default **on** but degrade silently if no voices are available.

---

## 7. President agent (can be Phase 5 or threaded earlier)

- Model: `claude-opus-4-8`.
- News snapshot: call with the Anthropic **`web_search`** tool to pull a "snapshot of the
  moment," or accept pasted headlines as fallback.
- Output: an **Executive Plan** (problem statement + desired outcome + constraints),
  produced as text + a short structured header, then injected into the chief-of-staff
  intake exactly as a human submission would be — so the rest of the pipeline is unchanged.
- This is why the orchestrator intake is provider-agnostic from step 1: the president is
  just another producer of a "case file."

---

## 8. Build phases (each with a verification check, per CLAUDE.md §4)

```
0. Skeleton + provider adapter + key entry
   → verify: a "test connection" button gets a valid reply from each of the 3 providers.
1. Cabinet data + potato grid UI (static states)
   → verify: 16 potatoes render with labels; manually toggling state changes the visual.
2. Orchestration core (decompose → dispatch → synthesize), no voice/animation yet
   → verify: "drought" routes to USDA only; "military buildup in Europe" routes to
     State+Defense with coordination; final synthesis text appears.
3. Announcements + TTS + talking-mouth animation
   → verify: assigned potatoes announce + speak on dispatch and on completion.
4. Per-secretary Q&A
   → verify: ask Ag Secretary about the active drought case → context-specific answer;
     ask a department with no active task → general-scope answer.
5. President agent (news snapshot → Executive Plan → hands to chief of staff)
   → verify: clicking "auto-pick a problem" runs the full pipeline end-to-end unattended.
```

Phases 0–2 are the load-bearing core; 3–5 are layered enhancements.

---

## 9. Risks & tradeoffs (surfaced, not hidden)

- **Key exposure / CORS:** keys live in the browser; acceptable for a local single-user
  tool but must be stated in-UI. Anthropic needs the explicit browser-access header.
- **Cost & latency:** a single run can fire the orchestrator + up to 15 secretaries +
  synthesis. Mitigations: only assigned departments are called; cheap default secretary
  model; parallel dispatch; show per-agent spinners so latency is visible.
- **News without a backend:** depends on a web-search-capable model (Anthropic
  `web_search`) or pasted headlines. Pure offline "current news" is not possible in-browser.
- **TTS variance:** voice quality/availability differs across OS/browser; feature is
  optional and degrades gracefully.
- **Attachments/links:** browser can read local files and pasted text, but cannot fetch
  arbitrary cross-origin URLs; links are handed to the model as text.
- **Single-file size:** 16 prompts + UI + adapters will make one large HTML file; kept
  manageable by generating avatars/prompts from the `CABINET` data table rather than
  hand-writing each.

---

## 10. What "done" looks like

A single `index.html` the user opens locally; enters keys; types (or lets the president
pick) a real-world problem; watches the right potato secretaries get tasked, work,
announce, and report; reads a synthesized cross-department solution; and can interrogate
any secretary about it — all in the browser, no server.

---

## 11. Model research findings (validated live, 2026-06-15)

Tested against a live, web-sourced current event — the federal government barring
Los Angeles's LAHSA from federal homelessness funds (June 2026), fetched via
`google/gemini-2.5-flash:online` with citations. Two probes:

- **Probe 1 — grounded JSON routing (viability):** all 6 models returned valid strict
  JSON, all correctly routed to **HUD** as primary, all named **real** federal programs
  (Continuum of Care, ESG, HUD-VASH, HOME, Section 8). No fabricated programs.
- **Probe 2 — ungrounded specifics (hallucination):** asked for exact LAHSA/HUD figures
  with no context provided. All 6 honestly declined and cited their knowledge cutoff;
  **none fabricated** figures. Confirms the design: gather facts with a web model, then
  feed them as grounded context to the secretary agents.

**Cost (exact OpenRouter-charged $, both probes combined; live OpenRouter pricing):**

| Model | $ in /1M | $ out /1M | tok in | tok out | Cost (2 probes) | Proj. $/1k calls |
|---|---:|---:|---:|---:|---:|---:|
| meta-llama/llama-3.3-70b-instruct | 0.100 | 0.320 | 226 | 198 | $0.000098 | $0.05 |
| qwen/qwen3-235b-a22b-2507 | 0.090 | 0.100 | 236 | 339 | $0.000152 | $0.08 |
| deepseek/deepseek-chat-v3-0324 | 0.200 | 0.770 | 192 | 398 | $0.000340 | $0.17 |
| openai/gpt-4.1-mini | 0.400 | 1.600 | 194 | 227 | $0.000441 | $0.22 |
| google/gemini-2.5-flash | 0.300 | 2.500 | 181 | 322 | $0.000859 | $0.43 |
| openai/gpt-5.4-mini | 0.750 | 4.500 | 192 | 367 | $0.001796 | $0.90 |

Takeaways:
- **Cheapest viable secretary models:** `llama-3.3-70b` and `qwen3-235b-a22b-2507` —
  correct routing + honest hedging at ~$0.05–0.08 per 1,000 calls.
- `gpt-4.1-mini` — reliable strict JSON; good fit for the orchestrator's decomposition.
- `gemini-2.5-flash:online` — the web-research role (returns citations). Plain calls are
  ~$0.43/1k; the `:online` web search adds a per-search surcharge.
- `gpt-5.4-mini` — newest 5.x mini, but ~4× `gpt-4.1-mini` / ~18× the cheapest options
  (reasoning tokens inflate output). Reserve for hard reasoning, not routine seats.

Endpoint note: the dev machine's `.zshrc` points `ANTHROPIC_BASE_URL` at a GLM-5 proxy;
real-Anthropic calls (Opus 4.8 president, Sonnet 4.6 orchestrator) must force
`https://api.anthropic.com` explicitly.
