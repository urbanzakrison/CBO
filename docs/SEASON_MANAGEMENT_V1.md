# CBO Season Management v1 — implementation and release review

Date: 19 October 2026. Status: development only; production release and season activation require separate approval.

## Verified starting point

- GitHub main: `c7952ce0e92225ede30831d09e7b1dfc1779bdf1` (18 October).
- Production `index.html` was downloaded and matched main byte-for-byte: SHA-256 `5d31e799e6b47e4a4341ec05392d6811a462654352ff80ef73e25ae52e42af89`.
- Supabase project: `lwymnhmwrinzuvmoqqif`. All access during development was read-only. No production season was created, activated or closed; no release SQL was applied.
- Migration `20261019090956 / cbo_allow_prepared_season_status` already exists. Actual `seasons_status_check` includes PÅGÅENDE, AVSLUTAD, FÖRBEREDD. It is not recreated.
- 2025 AVSLUTAD, 2026 PÅGÅENDE, no 2027. Historical champions 2011–2025 already exist.
- Attached MASTER and PROJECT RULES 4.6.5.3 were read; current main was used instead of replacing it with that earlier baseline.

## Production architecture and dependencies

`seasons(id, year UNIQUE, status, official_champion_player_id, official_champion_points, champion_metric, champion_value, champion_note)`.
`season_players(season_id, player_id, start_hcp)` has composite PK and FKs to seasons/players.
`rounds.season_id` references seasons; `UNIQUE(season_id, round_no)` already supports round 1 every year.
`round_results` has PK `(round_id,player_id)` and cascading FKs to rounds/players.
RLS is enabled on all four tables. Existing SELECT policies use `is_cbo_member()`; existing admin ALL policies use `is_cbo_admin()`. No non-internal triggers on these four tables. Existing policies are unchanged.

Actual signatures were read from pg_proc, with pg_get_functiondef:

| Function | Inspected behavior | Change |
| --- | --- | --- |
| `cbo_current_player()` | Credentials → active player, returns player_id/name/is_admin | None; reused for new admin authorization |
| `is_cbo_member()` | Active member via player_credentials | None; reused for read access |
| `is_cbo_admin()` | Legacy helper refers to players.auth_user_id | None; new RPCs deliberately follow the verified current-player path |
| `cbo_publish_round(integer,date,text,integer,text,jsonb)` | Auth/admin check, year hardcoded to 2026, server scoring | Active season lookup and shared lifecycle lock; reject wrong-year dates; server-side date duplicate protection; future TEST-player exclusion |
| `cbo_round_duplicate_check(integer,date)` | Active season; round number OR same date | None; same frontend precheck retained |
| `cbo_live_leaderboard_data(integer DEFAULT 2026)` | Explicit year supported; safe player/round/result projection | None; new wrapper always passes a year |
| `cbo_season_stats(integer)` | Explicit year; official rounds | None |
| `cbo_round_reactions(integer)` / `cbo_toggle_round_reaction(integer,text)` | Already resolve active season | None |

`send-cbo-push` version 4 was read; no hardcoded 2026/season lookup was found. No Edge Function change. GameBook image parsing and review are unchanged. The existing review → duplicate check → publish → refresh flow remains in place.

## Year dependencies

Executable 2026 assumptions were present in initialization, three selectors plus statistics, Home, live-round reads, categories, player lists, admin round proposal/roster, registered-player matching, WhatsApp text, and latest Home activity. These now use server metadata and year-keyed caches. No preceding-year results or local reports can fill an empty new season.

The historical DATA literal and original 2021–2025 champion literal are byte-identical. Historical notes about 2022, 2023 and missing pre-2026 gross data remain. `2026` still appears as the boundary between embedded historical data and server-backed seasons, and to scope old local recap storage to its original year; it does not select the active season. Existing archived SQL (including `07_live_round_write_rpc.sql`) is retained for provenance and MUST NOT be rerun after this release. Apply the new release SQL only.

## New database API and exact changes

`22_season_management_v1.sql` is a complete transactional, review-only release script in the repository's existing numbered-SQL format. No Supabase CLI is installed here; it is not represented as an already-applied migration.

- Unique partial index `cbo_one_active_season` on status WHERE status=PÅGÅENDE: at most one active season, including direct DML.
- New `cbo_season_snapshots(season_id PK/FK, payload jsonb, captured_at timestamptz)`. RLS enabled; PUBLIC, anon and authenticated have no direct table privileges. No client writes.
- `cbo_seasons_status()` → safe years/status/active year, public champion metadata, can_activate.
- `cbo_season_create(integer)` → exact next unused year, FÖRBEREDD, active non-TEST roster and start handicap. Existing seasons/results untouched.
- `cbo_season_data(integer)` → snapshot for closed future seasons, empty prepared-season data, otherwise existing read RPC with explicit year; future rosters exclude TEST players. New members can appear without annual code changes.
- `cbo_season_activate(integer,integer)` → target year and expected active year. Locks lifecycle; requires prepared immediate successor and no target rounds. Freezes outgoing live payload, preserves existing official champion fields, otherwise derives champion using Totalen points/current HCP. Closes old and starts new atomically; refreshes new roster for members added since preparation. A repeated/stale activation fails.
- Replaces only the inspected `cbo_publish_round` signature. Server scoring loop and existing guest rejection are preserved. Shared advisory transaction lock `(20261019,1)` prevents activation racing ordinary publication. Date year must match the active year. Existing round-number uniqueness remains; date precheck is also enforced inside this lock.

New SECURITY DEFINER RPCs use empty search_path with qualified objects, check auth.uid plus active membership/admin inside the body, revoke PUBLIC/anon EXECUTE, and grant only authenticated. No credentials or private keys are introduced. Existing publication function retains its inspected trusted search_path and ACL. No existing auth, RLS policy, community, push or On Tour definitions are replaced.

Frozen payloads preserve ranking inputs (including handicap) when later years change. An existing official champion is never overwritten. Name is only a deterministic final fallback when both points and handicap match; before release review the treatment of a genuinely unresolved top tie against the club's official decision.

## Frontend

Admin → Säsongshantering: active year, prepared years, closed years, proposed next year, create confirmation, activation consequence explanation, and typed `AKTIVERA YYYY` confirmation. Buttons disable during mutation. Result is reread from the server before showing verified success. No create/activate calls on page load. Creation does not change selected season or active year.

Active year defaults after login; prepared years are excluded from competition selectors. Historical selectors remain available. New empty season shows an explicit empty state for every category, with no old round, recap or personal statistics. Round proposal starts at 1. Home always reads active year even while a historical competition view is selected. Modern historical seasons read their frozen payload and champion metadata.

## Files

- Modified: `index.html`, `live-leaderboard.js`.
- New runtime: `season-management.js`.
- New database scripts: `22_season_management_v1.sql`, `23_season_management_rollback.sql`.
- New verification: `.gitignore`, `package.json`, `package-lock.json`, `tests/baseline.test.mjs`, `tests/season-database.test.mjs`, `tests/season-browser.mjs`, `tests/fixtures/schema.sql`, `tests/fixtures/production-functions.sql`, `tests/fixtures/baseline-hashes.json`.
- This review: `docs/SEASON_MANAGEMENT_V1.md`.

The test fixture contains inspected public function definitions, synthetic identities and schema only; no credentials. Test dependencies are pinned and used only in development. Existing auth-client, service worker, all On Tour files and the inline On Tour admin script are unchanged and covered by baseline hashes.

## Verification and limits

Verified locally: 7/7 automated tests passed, plus the mobile browser integration scenario; no uncaught browser errors. `git diff --check` passed.

`npm ci && npm test` (Node 24+): isolated PostgreSQL via PGlite, not a simulated JavaScript database. Tests execute release/rollback SQL and inspected production RPC definitions. Cover invalid years, 2027 preparation, 2026 remaining active, duplicate create, unknown/anonymous/member/inactive-admin denial, snapshot table denial, stale activation, atomic failure, no second active season, future date rejection, duplicate number/date rejection, preserved result rows and existing champion, frozen historical payload after HCP change, TEST exclusion, round 1 in 2027 and 2028, and safe rollback.

`npm run test:browser`: Playwright, 390×844 touch viewport, real isolated SQL backend, unchanged auth-client with local test session adapter. External network is blocked in this test. Covers create/activation confirmation, no automatic activation, prepared year hidden, empty categories/Home, 2025 embedded history identical, closed 2026 champion, admin round 1, actual duplicate-check/publish flow, next-year 2028, mobile fit and normal-member admin gating. Local screenshot visually reviewed. Use `npx playwright install chromium` first, or set `CHROMIUM_EXECUTABLE_PATH` to a supported local Chromium.

Baseline tests compare hashes of embedded historical results/champions, auth, service worker, On Tour pages and inline On Tour admin code with inspected main. All inline/external changed JS is parsed. `git diff --check` is required.

Not claimed: real-user login/OS push/Realtime delivery/actual OpenAI image parsing in production; remote Supabase staging deployment; simultaneous separate Postgres connections. PGlite runs a single isolated database connection, so advisory-lock behavior under real multi-session contention still needs staging validation. The untouched community/navigation routes receive only a local browser smoke check, not a full multi-user regression certification. New SECURITY DEFINER routines require the Supabase security advisor after a separately approved staging deployment. No claim that passing static hashes proves end-to-end service behavior.

Production read-only baseline: 2025 has 38 rounds / 244 results (result MD5 `e547408a33c565bda3c1b4380bb8a8db`); 2026 has 34 / 232 (`25983a47d0b99edee23893fdabc904a7`). No production data writes were made.

## Production plan — approval required

1. Review PR and exact SQL; recheck main drift, actual function signatures/ACL and active year. Back up schema, seasons/champions, round/result hashes and live payload. Confirm no conflicting active rows.
2. Before merge, run the scripts in approved Supabase staging with representative 2025/2026 data and real separate admin/member sessions; exercise concurrent create/activate/publish; run security advisors. Verify exact historical leaderboard/statistics parity and GameBook, Realtime, push/PWA with real users. Resolve blockers; do not call this production acceptance yet.
3. Obtain explicit approval for production database installation AND frontend merge/deployment. Apply `22_season_management_v1.sql` as a named Supabase migration (record it once); do not rerun the prior status migration or archived setup files. Script performs no season lifecycle transition.
4. Verify signatures, ACL, unique index, RLS, 2026 still active and unchanged historical hashes. Merge approved frontend changes and check Pages serves the new files together; verify mobile login/menus, categories, history, stats, Clubhouse and admin. Existing service worker remains unchanged; verify fresh and installed-PWA reload paths.
5. Creating 2027 is a deliberate admin action after the approved release. Confirm FÖRBEREDD and 2026 still active. This development task did not create it in production.
6. Activating 2027 is a later, separately approved club operation at season start. Reconcile champion/final standings beforehand and use the explicit admin confirmation. Do not bundle it with release installation.

## Rollback

Before feature use: restore the previous frontend files from the exact pre-release commit, then run the guarded `23_season_management_rollback.sql` after separate approval. It restores the inspected prior publisher, removes only new RPCs/table/index, and does not alter historical seasons/results or the earlier status constraint. Its safety guard refuses rollback if any new season or snapshot exists.

After any season has been prepared or activated: never delete seasons/snapshots to make rollback pass. Preserve the new data and use a reviewed forward fix. After activation do not restore the old hardcoded-2026 frontend/publisher; it could present or target the wrong season. Stop ordinary publication until the reviewed fix is verified. Reversing an actual season transition is outside this release rollback and requires its own data-aware approval.
