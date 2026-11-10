# WhatsApp Customer Service, Email-First Resend, and E2E Certification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL at execution time: use `superpowers:using-git-worktrees`, then `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Implement one gated phase at a time. Do not stack implementation phases on an unreviewed branch.

**Status:** APPROVED FOR GATED EXECUTION
**Execution method:** SUBAGENT-DRIVEN
**Current authorization:** GATE 0 ONLY

**Goal:** Replace the confusing/dead-end WhatsApp navigation with a deterministic customer flow, redesign ticket resend around email OTP plus one-ticket selection, add same-conversation human support takeover, and certify the entire path with a controlled WhatsApp/Paystack test event.

**Architecture:** Keep `FastCheck.Sales.Conversation` as the durable WhatsApp conversation checkpoint and existing Sales/Order/payment/ticket state machines authoritative. Add a dedicated `FastCheck.Support` domain for human-support lifecycle, refactor resend into email-first identity verification followed by bounded ticket discovery/selection, and keep all hot queue/rate-limit state as ETS/GenServer + Redis mirrors of durable Postgres state. Ship as five independently reviewable implementation PRs after a signed authority-doc normalization PR.

**Tech Stack:** Elixir, Phoenix, Phoenix LiveView, Ash/AshPostgres, PostgreSQL, Redis, ETS/GenServer, Phoenix PubSub, Oban, existing Meta WhatsApp Cloud API client, existing Paystack test integration.

**Approved Spec:** `docs/superpowers/specs/2026-10-15-whatsapp-customer-service-resend-design.md`

**Approved spec content source:** branch `docs/whatsapp-customer-service-resend-design`, draft commit `81ed83a2e09d613c96af2c78e35f4730f19acc17`, blob `6768759afe15d9c73842dcdc971e2f6365476945`.

**Authority base at spec approval:** `d8e885a08d91f9290e1ff2519003fbdfc014831d`.

---

## Global Constraints

1. **No implementation before plan approval.**
2. **Signed history only.** The current draft spec commit is unsigned and MUST NOT be merged. Reconstruct the approved spec bytes on an isolated signed branch before any implementation PR is authorized.
3. **No direct production data edits.** No `INSERT`, `UPDATE`, `DELETE`, manual conversation reset, historical order mutation, or Redis flush to make tests pass.
4. **Preserve commercial Order authority.** Navigation/support/resend work must not weaken active Order guards, payment/fulfillment recovery, inventory reservations, or ticket issuance.
5. **No customer dead ends.** Every non-terminal customer response either asks for a concrete input or offers at least one actionable choice.
6. **Navigation contract:** main menu shows only Buy / Help / Resend. `0` is advertised only in subflows and means Main menu / leave current subflow. `#` remains accepted only as a hidden backward-compatibility alias.
7. **Resend security:** email OTP is the proof of control. WhatsApp `phone_e164` / `wa_id` may rank/correlate but must never authorize resend.
8. **No fuzzy identity matching.** Normal resend does not depend on customer-entered name.
9. **Ticket metadata only after OTP verification.**
10. **One ticket per resend action.** Exactly one candidate binds automatically; 2–9 require explicit selection; >9 escalates to support.
11. **Support routing:** while a support case is `waiting` or `claimed`, ordinary inbound content is support content, not Sales menu input. Only the defined global escape can leave support.
12. **One active support case per conversation.**
13. **Operator recipient cannot be caller-selected.** WhatsApp destination is derived from the bound Conversation only.
14. **V1 support authorization:** mount the support inbox behind existing `:dashboard_auth` + `:global_ops_auth`. Do not invent a second auth system or trust caller-supplied actor maps. Event-scoped support roles can be a future expansion.
15. **PII:** no raw email, phone, WhatsApp ID, OTP, ticket URL/token, payment URL, support message plaintext, or provider payload in logs, Oban args, Redis keys, PubSub topics/payloads, metrics, or analytics.
16. **Durable source:** Postgres remains durable authority. Redis/ETS/GenServer are rebuildable mirrors, never ownership locks.
17. **Concurrency:** use Ash `optimistic_lock(:lock_version)` or an equally strong existing project pattern on one-time resend binding and support claim/resolve.
18. **Realtime:** Phoenix PubSub + LiveView push. No polling.
19. **Heavy/retryable side effects:** Oban.
20. **Performance:** bounded queries, required indexes, no peak-time table scans, no unbounded support-history loads.
21. **Redis structures:** resend rate limits = ZSET; support waiting queue = ZSET; claimed-by-operator = SET/ZSET; summaries = HASH; activity feed = bounded LIST. TTLs must be explicit and invalidation documented.
22. **Existing sandbox fixture first:** use/extend `FastCheck.Sales.SandboxFixtures`; do not invent ad-hoc SQL test data if supported app paths exist.
23. **Paystack test only** for certification event.
24. **No codebase-wide refactors.** Modify only the boundaries required by the approved spec.
25. **TDD:** every task starts with a failing focused test, proves RED, implements the minimum change, proves GREEN, then runs the relevant regression set.
26. **Phase gate:** every phase ends with a PR, exact-head CI, independent review, merge, and post-merge CI before the next phase starts.

---

## Review Focus

These are the five failure classes most likely to survive an otherwise reasonable implementation. Each is pinned to a task below.

1. **Legacy resend continuity:** durable conversations already in `collecting_resend_name`, `collecting_resend_email`, or `collecting_resend_otp` must not be stranded or accidentally disclose tickets.
2. **Candidate-set drift after OTP:** tickets/orders may be revoked, scanned, archived, or otherwise become ineligible between challenge issue and candidate selection. Recompute eligibility after verification and again before one-time binding.
3. **Support/bot routing collision:** numbers such as `1`, `2`, `3`, `0`, `#` sent during active support must never accidentally trigger Sales transitions except the one explicit leave-support escape.
4. **Commercial-order preservation:** `0`, hidden `#`, Help entry, no-events recovery, and resend entry must never cancel or detach an active Order merely to simplify navigation.
5. **Concurrency/duplicate delivery:** duplicate inbound webhook, duplicate Oban execution, two support operators claiming simultaneously, and repeated resend selection must remain idempotent/fail closed.

---

# Project Structure and Boundaries

## Existing files expected to change

```text
lib/fastcheck/messaging/whatsapp/
  copy.ex
  input_normalizer.ex
  menu_renderer.ex
  conversation_state_machine.ex
  resend_flow.ex
  whatsapp client modules already used by workers

lib/fastcheck/sales/
  conversation.ex
  ticket_resend_challenge.ex
  sandbox_fixtures.ex
  sales.ex

lib/fastcheck/tickets/resend/
  request.ex
  eligibility.ex
  otp.ex
  rate_limit.ex
  result.ex
  hash.ex

lib/fastcheck_web/
  router.ex
```

## New focused files

```text
lib/fastcheck/tickets/resend/
  candidate_lookup.ex
  challenge_binding.ex

lib/fastcheck/support.ex
lib/fastcheck/support/
  support_case.ex
  support_message.ex
  message_cipher.ex
  queue.ex
  queue/server.ex
  router.ex

lib/fastcheck/workers/
  support_outbound_worker.ex

lib/fastcheck_web/live/support/
  inbox_live.ex
  case_live.ex

docs/fastcheck_sales/runbooks/
  WHATSAPP_SUPPORT_OPERATIONS.md
  WHATSAPP_E2E_CERTIFICATION_EVENT.md
```

## New tests

```text
test/fastcheck/messaging/whatsapp/
  navigation_contract_test.exs
  resend_ticket_e2e_test.exs        # extend existing file, do not duplicate if present
  support_routing_test.exs

test/fastcheck/tickets/resend/
  candidate_lookup_test.exs
  challenge_binding_test.exs
  redis_rate_limit_test.exs

test/fastcheck/support/
  support_case_test.exs
  support_message_test.exs
  queue_test.exs

test/fastcheck/workers/
  support_outbound_worker_test.exs

test/fastcheck_web/live/support/
  inbox_live_test.exs
  case_live_test.exs

test/fastcheck/sales/
  sandbox_fixtures_test.exs         # extend existing file if already present
```

### Naming rules

- Domain records: `SupportCase`, `SupportMessage`.
- Business orchestration: `FastCheck.Support.Queue`, `FastCheck.Tickets.Resend.CandidateLookup`.
- Channel routing: `FastCheck.Support.Router` or `FastCheck.Messaging.WhatsApp` adapter only; do not bury support lifecycle inside LiveView.
- Side-effect workers name the effect: `SupportOutboundWorker`.
- No new “manager/service/helper” catch-all modules.
- Support UI contains presentation and event handling only; authorization/lifecycle decisions remain in domain actions.

---

# Delivery Strategy

There are **six gates**:

- **Gate 0:** signed authority documents
- **Gate A:** navigation contract
- **Gate B:** email-first resend
- **Gate C:** support domain + inbound routing
- **Gate D:** operator inbox + outbound replies
- **Gate E:** E2E certification event + production-like certification

Each gate is a separate branch/PR. No implementation PR may include work from the next gate.

---

# Gate 0 — Canonical Signed Authority Documents

## Outcome

The user-approved spec and this implementation plan exist in the repository on signed history, with no production code changes.

### Task 0.1 — Reconstruct the approved spec and plan on a signed docs branch

**Files**
- Create from approved bytes: `docs/superpowers/specs/2026-10-15-whatsapp-customer-service-resend-design.md`
- Create: `docs/superpowers/plans/2026-10-15-whatsapp-customer-service-resend.md`

**TDD/verification steps**
- [ ] Create an isolated worktree from the current accepted `origin/main`.
- [ ] Verify the accepted base. If it is no longer the expected programme base, stop and report the new SHA/tree before copying documents.
- [ ] Copy the spec byte-for-byte from `docs/whatsapp-customer-service-resend-design`.
- [ ] Install this approved implementation plan at the exact plan path above.
- [ ] Prove the source spec and reconstructed spec are byte-identical (`cmp` or SHA-256 equality).
- [ ] Run `git diff --check`.
- [ ] Commit with the repository's signed-commit mechanism.
- [ ] Verify the commit signature.
- [ ] Open a docs-only PR. Do not merge automatically.

**Success**
- Two docs only.
- Signed commit.
- Spec byte identity proved.
- No code/migration/data changes.

**STOP**
`STOP=MAIN_MOVED_UNREVIEWED`, `STOP=SPEC_BYTES_DIFFER`, `STOP=UNSIGNED_COMMIT`, `STOP=NON_DOC_FILE_CHANGED`.

---

# Gate A — Navigation Contract and No-Dead-End Responses

## Outcome

The main menu has no meaningless Back option; subflows advertise one global escape (`0. Hoofkieslys` / `0. Main menu`); hidden `#` remains accepted; no-events/error/status responses are actionable without weakening Order recovery.

### Task A1 — Lock the renderer/copy navigation contract

**Files**
- Modify: `lib/fastcheck/messaging/whatsapp/copy.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/menu_renderer.ex`
- Test: `test/fastcheck/messaging/whatsapp/menu_renderer_test.exs`
- Test: `test/fastcheck/messaging/whatsapp/copy_test.exs`
- Create: `test/fastcheck/messaging/whatsapp/navigation_contract_test.exs`

**Interfaces**
- Keep `MenuRenderer.main_menu/1` and `/3`.
- Replace advertised generic Back/Restart pairing with a single subflow Main-menu line.
- Keep monospace delimiter neutralization unchanged.
- No InputNormalizer behavior change in this task.

**TDD steps**
- [ ] RED: main menu contains Buy/Help/Resend and contains neither `0.` nor `#.`.
- [ ] RED: every normal subflow prompt contains exactly one advertised Main-menu escape (`0.`) and no advertised `#.`.
- [ ] RED: cancellation/confirmation screens use explicit correction choices plus `0. Main menu`; no ambiguous generic `Back`.
- [ ] RED: customer-facing no-events / sales-disabled / invalid-input responses remain actionable.
- [ ] Implement only copy/renderer changes.
- [ ] GREEN: focused renderer/copy/navigation tests.
- [ ] Run WhatsApp focused regression suite.
- [ ] Commit signed.

**Performance & scaling**
No new DB/Redis calls. Pure rendering only.

**STOP**
`STOP=INPUT_NORMALIZER_CHANGED`, `STOP=ACTIVE_ORDER_COPY_SEMANTICS_WEAKENED`, `STOP=MONOSPACE_REGRESSION`.

### Task A2 — Make `0` contextual Main-menu recovery without changing hidden `#`

**Files**
- Modify: `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex`
- Modify only if necessary: `lib/fastcheck/sales/conversation.ex`
- Test: `test/fastcheck/messaging/whatsapp/conversation_state_machine_test.exs`
- Test: `test/fastcheck/messaging/whatsapp/active_commercial_order_test.exs`

**Interfaces**
- `InputNormalizer.normalize("0") -> {:ok, :back}` remains.
- `InputNormalizer.normalize("#") -> {:ok, :restart}` remains.
- State machine maps `:back` from customer subflows to safe main-menu recovery when there is no meaningful local correction action.
- Main-menu `0` is not advertised; if received anyway it must be harmless and deterministic.

**TDD steps**
- [ ] RED: `0` from each advertised subflow returns safely to main menu.
- [ ] RED: hidden `#` still returns safely to main menu.
- [ ] RED: `0`/`#` with active commercial Order preserves Order identity and status.
- [ ] RED: stale-recovery behavior fixed by PR #535 remains intact.
- [ ] RED: invalid text such as `?` repeats an actionable current menu rather than producing a dead end.
- [ ] Implement minimum state-machine mapping.
- [ ] GREEN focused tests.
- [ ] Run full WhatsApp regression + `mix precommit`.
- [ ] Open Gate A PR and stop for review.

**STOP**
`STOP=ORDER_CANCELLED_BY_NAVIGATION`, `STOP=COMMERCIAL_GUARD_BYPASS`, `STOP=FOCUSED_TEST_FAILURE`, `STOP=PRECOMMIT_FAILURE`.

---

# Gate B — Email-First Resend and One-Ticket Selection

## Outcome

Resend becomes email → OTP → candidate discovery → one-ticket selection if necessary. Customer-entered name is removed from the normal path. WhatsApp phone only ranks. Candidate binding is one-time and concurrency-safe.

### Task B1 — Add migration-compatible resend conversation states

**Files**
- Modify: `lib/fastcheck/sales/conversation.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex`
- Create migration: `priv/repo/migrations/<timestamp>_email_first_ticket_resend_states.exs`
- Test: `test/fastcheck/sales/conversation_state_actions_test.exs`
- Test: `test/fastcheck/messaging/whatsapp/conversation_state_machine_test.exs`

**Required state model**
```text
main_menu
  -> collecting_resend_email
collecting_resend_email
  -> collecting_resend_otp
collecting_resend_otp
  -> selecting_resend_ticket | awaiting_verified_resend_delivery
selecting_resend_ticket
  -> awaiting_verified_resend_delivery
awaiting_verified_resend_delivery
  -> verified_resend_delivery_queued
```

**Compatibility**
- Existing `collecting_resend_name` durable rows must be safely recoverable to email-first flow.
- Existing already-issued legacy resend challenges in `collecting_resend_otp` remain verifiable under the old candidate-bound challenge contract until terminal/expired.
- Do not rewrite historical challenge evidence.

**TDD steps**
- [ ] RED transition-table tests for new states.
- [ ] RED legacy durable state tests.
- [ ] Add only required DB check/state changes.
- [ ] Implement transitions and compatibility routing.
- [ ] GREEN focused state tests.
- [ ] Run migration up/down verification in test DB.

**STOP**
`STOP=LEGACY_RESEND_CONVERSATION_STRANDED`, `STOP=LEGACY_CHALLENGE_INVALIDATED_BY_SCHEMA`, `STOP=MIGRATION_NOT_REVERSIBLE`.

### Task B2 — Make resend request email-first and name-optional

**Files**
- Modify: `lib/fastcheck/tickets/resend/request.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/resend_flow.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/copy.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/menu_renderer.ex`
- Test: `test/fastcheck/tickets/resend/request_test.exs`
- Test: `test/fastcheck/messaging/whatsapp/resend_flow_test.exs`
- Test: `test/fastcheck/messaging/whatsapp/menu_renderer_test.exs`

**Interfaces**
- Preserve `normalize_email/1` behavior: trim + lowercase + shape validation.
- Keep `normalize_name/1` for legacy tooling/tests, but normal resend `Request.normalize/1` must support `name=nil`.
- `ResendFlow` stores only normalized email plus source identity for the new path.

**TDD**
- [ ] RED: mixed-case email normalizes identically.
- [ ] RED: new resend request succeeds without a name.
- [ ] RED: phone/WA ID remain source metadata and do not become proof.
- [ ] RED: invalid email response asks again and offers `0. Main menu`.
- [ ] Implement minimum request/orchestration/copy changes.
- [ ] GREEN focused tests.

**STOP**
`STOP=NAME_STILL_REQUIRED_NEW_PATH`, `STOP=PHONE_USED_AS_AUTH`, `STOP=PII_LOGGED`.

### Task B3 — Issue identity-level OTP challenges without a pre-bound ticket

**Files**
- Modify: `lib/fastcheck/sales/ticket_resend_challenge.ex`
- Modify: `lib/fastcheck/tickets/resend/otp.ex`
- Modify: `lib/fastcheck/tickets/resend/email_otp.ex`
- Create migration: `priv/repo/migrations/<timestamp>_add_ticket_resend_challenge_lock_version.exs`
- Test: `test/fastcheck/tickets/resend/otp_test.exs`
- Test: `test/fastcheck/tickets/resend/email_otp_test.exs`
- Test: `test/fastcheck/sales/ticket_resend_challenge_test.exs` if present, otherwise create it.

**Interfaces**
- Extend OTP issue contract to allow `sales_order_id=nil`, `ticket_issue_id=nil`, `candidate_hash=nil` for email-identity challenges.
- Add `lock_version` using the existing Ash optimistic-lock convention.
- Existing candidate-bound legacy challenge issuance remains valid.

**TDD**
- [ ] RED: identity challenge stores email/source hashes, OTP hash, no candidate.
- [ ] RED: plaintext OTP never persists.
- [ ] RED: legacy candidate-bound challenge still verifies.
- [ ] RED: expired/blocked/already-verified behavior unchanged.
- [ ] Implement minimal challenge/OTP changes.
- [ ] GREEN focused tests.

**STOP**
`STOP=PLAINTEXT_OTP_PERSISTED`, `STOP=LEGACY_OTP_BREAK`, `STOP=LOCK_VERSION_NOT_ENFORCED`.

### Task B4 — Add bounded post-verification candidate lookup

**Files**
- Create: `lib/fastcheck/tickets/resend/candidate_lookup.ex`
- Modify: `lib/fastcheck/tickets/resend/eligibility.ex` to delegate discovery, not duplicate query logic
- Create migration: `priv/repo/migrations/<timestamp>_index_issued_orders_by_normalized_buyer_email.exs`
- Test: `test/fastcheck/tickets/resend/candidate_lookup_test.exs`

**Interface**
- `CandidateLookup.list_verified_candidates(normalized_email, phone_e164, limit \\ 10)`
- Return deterministic candidates containing only internal IDs and safe label source fields required after verification.
- Hard bound is 10 rows to detect “>9”; never unbounded.
- Exact phone match ranks first but nonmatching phone candidates remain eligible.

**Required predicates**
Preserve current issued/valid/not-revoked/not-archived/payment-complete eligibility rules.

**TDD**
- [ ] RED one candidate.
- [ ] RED 2–9 deterministic candidates.
- [ ] RED 10th row returns/marks overflow so UI escalates rather than lists >9.
- [ ] RED matching phone sorts first.
- [ ] RED nonmatching phone is not rejected.
- [ ] RED revoked/scanned-invalid/archived/incomplete-payment candidates excluded.
- [ ] RED mixed-case email uses normalized indexed path.
- [ ] Implement functional/partial index and query.
- [ ] Capture `EXPLAIN` in test/dev evidence; no large sequential scan on the critical normalized-email predicate.

**Performance**
Cold Postgres lookup only after OTP verification; bounded to 10. Required functional/partial normalized-email index. No full-history load.

**STOP**
`STOP=UNBOUNDED_QUERY`, `STOP=PHONE_FILTERS_OUT_VALID_TICKET`, `STOP=PREVERIFY_METADATA_DISCLOSURE`, `STOP=SEQ_SCAN_CRITICAL_PATH`.

### Task B5 — Bind exactly one verified ticket and render selection

**Files**
- Create: `lib/fastcheck/tickets/resend/challenge_binding.ex`
- Modify: `lib/fastcheck/sales/ticket_resend_challenge.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/resend_flow.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/menu_renderer.ex`
- Test: `test/fastcheck/tickets/resend/challenge_binding_test.exs`
- Extend: `test/fastcheck/messaging/whatsapp/resend_ticket_e2e_test.exs`

**Interface**
- `ChallengeBinding.bind_verified_candidate(challenge_public_id, candidate, now)`
- Guard: challenge `verified`, unconsumed, candidate fields empty or identical legacy binding, candidate still eligible, optimistic lock succeeds.
- Never allow rebinding to another ticket.

**TDD**
- [ ] RED exactly one candidate auto-binds.
- [ ] RED 2–9 render safe numbered choices only after OTP.
- [ ] RED selected candidate is revalidated before bind.
- [ ] RED candidate-set drift (revocation/status change after OTP) fails safely/recomputes.
- [ ] RED repeated same selection is idempotent or returns already-bound without duplicate delivery.
- [ ] RED selecting a different ticket after binding fails closed.
- [ ] RED overflow routes to Help/support-capable response.
- [ ] Implement minimum binding/orchestration.
- [ ] GREEN resend E2E tests.

**STOP**
`STOP=REBOUND_VERIFIED_CHALLENGE`, `STOP=STALE_CANDIDATE_DELIVERED`, `STOP=TICKET_METADATA_BEFORE_OTP`.

### Task B6 — Move resend high-velocity rate limits to Redis ZSET with durable audit

**Files**
- Modify: `lib/fastcheck/tickets/resend/rate_limit.ex`
- Add/extend existing Redis adapter under the project's established Redis boundary; do not add a second Redis client.
- Test: `test/fastcheck/tickets/resend/redis_rate_limit_test.exs`
- Preserve durable challenge/audit tests.

**Rules**
- ZSET score = timestamp.
- Key material = HMAC/hash only.
- 15-minute-class TTL/window aligned with current resend policy.
- Atomic trim/count/add/expire operation (Lua or existing atomic Redis helper).
- Redis outage follows the existing approved safety posture; do not silently disable abuse controls.
- Durable rejected-attempt evidence remains Postgres.

**TDD**
- [ ] RED email/source/candidate window limits.
- [ ] RED expiry/window trimming.
- [ ] RED raw email/phone absent from keys.
- [ ] RED concurrency cannot exceed the configured bound through races.
- [ ] RED Redis failure behavior is explicit and safe.
- [ ] Implement smallest atomic Redis operation.
- [ ] GREEN focused tests + resend regression.
- [ ] `mix precommit`, Gate B PR, exact-head CI, stop.

**STOP**
`STOP=RAW_PII_REDIS_KEY`, `STOP=NON_ATOMIC_RATE_LIMIT`, `STOP=REDIS_BECOMES_DURABLE_AUTHORITY`, `STOP=PRECOMMIT_FAILURE`.

---

# Gate C — Human Support Domain and Inbound Routing

## Outcome

Help asks for one free-text description, creates one durable encrypted support case/message, and suppresses bot Sales transitions until the case is cancelled/resolved.

### Task C1 — Create `FastCheck.Support` domain and durable resources

**Files**
- Create: `lib/fastcheck/support.ex`
- Create: `lib/fastcheck/support/support_case.ex`
- Create: `lib/fastcheck/support/support_message.ex`
- Create migration: `priv/repo/migrations/<timestamp>_create_support_cases_and_messages.exs`
- Test: `test/fastcheck/support/support_case_test.exs`
- Test: `test/fastcheck/support/support_message_test.exs`

**SupportCase states**
`waiting`, `claimed`, `resolved`, `cancelled`.

**Transitions**
- create/request -> `waiting`
- claim -> `claimed`
- resolve -> `resolved` terminal
- cancel from waiting/claimed -> `cancelled` terminal

**Guards**
- one active (`waiting|claimed`) case per Conversation via partial unique index.
- `lock_version` optimistic lock.
- claim only from waiting.
- resolve only by owning global support operator in V1.
- destination identity never stored as caller-editable recipient.

**Indexes**
- unique active `conversation_id`.
- `(state, requested_at)`.
- `(assigned_operator_id, state, updated_at)`.
- SupportMessage `(support_case_id, inserted_at)`.
- unique provider message ID where present.

**STOP**
`STOP=MISSING_ACTIVE_CASE_UNIQUE_INDEX`, `STOP=NO_OPTIMISTIC_LOCK`, `STOP=SECOND_AUTH_SYSTEM`.

### Task C2 — Encrypt support message bodies at the domain boundary

**Files**
- Create: `lib/fastcheck/support/message_cipher.ex`
- Modify: `lib/fastcheck/support/support_message.ex`
- Test: `test/fastcheck/support/support_message_test.exs`

**Interface**
- `MessageCipher.encrypt(plaintext)` and `decrypt(ciphertext)` wrap the existing approved project crypto primitive.
- Resource stores ciphertext only.

**TDD**
- [ ] RED database row does not contain plaintext.
- [ ] RED Inspect/log representation redacts ciphertext/sensitive fields.
- [ ] RED encryption/decryption roundtrip.
- [ ] RED invalid ciphertext fails safely without exposing raw bytes.
- [ ] Implement wrapper and resource hooks.

**STOP**
`STOP=NEW_CRYPTO_PRIMITIVE`, `STOP=PLAINTEXT_DB`, `STOP=PLAINTEXT_LOG`.

### Task C3 — Implement support request and bot-suppression routing

**Files**
- Create: `lib/fastcheck/support/router.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/copy.ex`
- Modify: `lib/fastcheck/messaging/whatsapp/menu_renderer.ex`
- Modify only as necessary: `lib/fastcheck/sales/conversation.ex`
- Test: `test/fastcheck/messaging/whatsapp/support_routing_test.exs`
- Extend: `test/fastcheck/messaging/whatsapp/conversation_state_machine_test.exs`

**Conversation/support flow**
```text
main_menu
  --Help--> support_description

support_description
  --nonblank text--> SupportCase(waiting) + encrypted customer SupportMessage
  --0--> main_menu

active support case waiting/claimed:
  ordinary inbound -> encrypted SupportMessage, no Sales transition
  0 -> cancel SupportCase -> safe main_menu
  # -> hidden compatibility main-menu escape if retained by global semantics
```

**TDD**
- [ ] RED Help does not immediately create an empty case; it asks for a description.
- [ ] RED description creates exactly one active case + one encrypted message.
- [ ] RED duplicate inbound provider message does not duplicate SupportMessage.
- [ ] RED `1`, `2`, `3`, arbitrary text during active support do not trigger Sales state.
- [ ] RED `0` cancels support and safely returns to main menu.
- [ ] RED active commercial Order remains untouched.
- [ ] RED existing non-support `needs_human` reasons are not cleared by support cancellation.
- [ ] Implement minimum routing.
- [ ] GREEN tests.

**STOP**
`STOP=BOT_TRANSITION_DURING_SUPPORT`, `STOP=DUPLICATE_ACTIVE_CASE`, `STOP=UNRELATED_HANDOFF_REASON_CLEARED`.

### Task C4 — Add hot/warm support queue mirrors and PubSub

**Files**
- Create: `lib/fastcheck/support/queue.ex`
- Create: `lib/fastcheck/support/queue/server.ex`
- Add supervision under the existing application supervisor
- Tests: `test/fastcheck/support/queue_test.exs`

**Data placement**
- ETS/GenServer: hot queue counters/snapshot; seconds-to-minutes rebuildable.
- Redis waiting queue: ZSET scored by requested timestamp.
- Claimed-by-operator: SET/ZSET.
- Queue summaries: HASH, TTL 30s–5m.
- Activity feed: bounded LIST with short TTL.
- PubSub topic uses internal IDs only.

**Write-through**
Domain action succeeds durably, then mirrors/invalidation/PubSub update. GenServer coordinates hot state but never replaces DB optimistic lock.

**TDD**
- [ ] RED waiting case appears in mirror.
- [ ] RED claim removes waiting / adds claimed.
- [ ] RED resolve/cancel invalidates mirrors.
- [ ] RED node/Redis reset rebuilds from Postgres.
- [ ] RED PubSub payload contains no PII/plaintext.
- [ ] Implement.
- [ ] `mix precommit`, Gate C PR, exact-head CI, stop.

**STOP**
`STOP=REDIS_OWNERSHIP_LOCK`, `STOP=PII_PUBSUB`, `STOP=POLLING_REQUIRED`, `STOP=PRECOMMIT_FAILURE`.

---

# Gate D — Operator Inbox and Same-Conversation Replies

## Outcome

Authorized global support operators can view waiting cases, claim exactly one, see decrypted bounded history, reply through WhatsApp, observe delivery state, and resolve the case.

### Task D1 — Mount support inbox behind existing server-owned global authorization

**Files**
- Modify: `lib/fastcheck_web/router.ex`
- Create: `lib/fastcheck_web/live/support/inbox_live.ex`
- Test: `test/fastcheck_web/live/support/inbox_live_test.exs`
- Extend auth tests if needed.

**Routes**
- `/dashboard/support`
- `/dashboard/support/:id`

Both must use `[:browser, :dashboard_auth, :global_ops_auth]`.

**TDD**
- [ ] RED unauthenticated denied/redirected by existing auth.
- [ ] RED dashboard-authenticated but non-global-ops user gets forbidden.
- [ ] RED spoofed assigns/actor maps do not bypass `GlobalOpsAuth`.
- [ ] GREEN authorized global ops user mounts.

**STOP**
`STOP=AUTH_FROM_SOCKET_ASSIGN_ONLY`, `STOP=CALLER_SUPPLIED_ALLOWED_EVENT_IDS`, `STOP=NEW_LOGIN_SYSTEM`.

### Task D2 — Build realtime paginated inbox and optimistic claim

**Files**
- Modify: `lib/fastcheck_web/live/support/inbox_live.ex`
- Create/modify Support actions as required
- Test: `test/fastcheck_web/live/support/inbox_live_test.exs`

**Rules**
- Initial page bounded (e.g. 50 cases); subsequent pagination explicit.
- PubSub push updates; no periodic polling.
- Claim uses SupportCase optimistic lock.
- Exactly one of two simultaneous claims succeeds.

**TDD**
- [ ] RED waiting queue renders without plaintext message bodies.
- [ ] RED new case arrives by PubSub.
- [ ] RED two-operator claim race.
- [ ] RED stale claim reports already claimed.
- [ ] RED page size bounded.
- [ ] Implement.

**Performance**
Read queue summary from ETS/Redis; durable page fetch only for IDs/details needed. No full-case scans.

### Task D3 — Build case view with bounded decrypted history

**Files**
- Create: `lib/fastcheck_web/live/support/case_live.ex`
- Test: `test/fastcheck_web/live/support/case_live_test.exs`

**Rules**
- Decrypt only after global-ops authorization.
- Load messages in bounded pages.
- Do not put plaintext into client persistence.
- Show Order/event context only from system-owned relationships.

**TDD**
- [ ] RED unauthorized cannot decrypt/view.
- [ ] RED history page bound.
- [ ] RED ciphertext never appears as raw debugging field.
- [ ] RED operator cannot edit/choose recipient phone.
- [ ] Implement.

### Task D4 — Queue operator replies through Oban

**Files**
- Create: `lib/fastcheck/workers/support_outbound_worker.ex`
- Modify: `lib/fastcheck/support/support_message.ex`
- Modify: `lib/fastcheck_web/live/support/case_live.ex`
- Test: `test/fastcheck/workers/support_outbound_worker_test.exs`
- Test: `test/fastcheck_web/live/support/case_live_test.exs`

**Delivery lifecycle**
`pending -> sent` or retryable `pending` / terminal `failed`.

**Rules**
- Job args: SupportMessage ID only (plus non-sensitive correlation if existing convention requires); no plaintext, phone, WA ID, access token.
- Worker reloads case/message/conversation, verifies case still claimed by sender, decrypts body in memory, derives destination from Conversation, uses existing WhatsApp client.
- Oban uniqueness/idempotency by SupportMessage ID.
- Respect Meta 24h service-window rule; outside window fail to a distinct operator-visible “template required” state unless an approved template path exists.

**TDD**
- [ ] RED job args contain no PII/plaintext.
- [ ] RED duplicate job execution does not duplicate accepted send.
- [ ] RED wrong/unclaimed operator cannot send.
- [ ] RED recipient cannot be overridden.
- [ ] RED retryable Meta error remains retryable.
- [ ] RED permanent auth/validation failure becomes terminal visible failure.
- [ ] RED outside-window freeform send is blocked/template-required.
- [ ] Implement.
- [ ] Capture logs and assert no secrets/PII.

**STOP**
`STOP=PLAINTEXT_OBAN_ARGS`, `STOP=RECIPIENT_OVERRIDE`, `STOP=DUPLICATE_PROVIDER_SEND`, `STOP=OUTSIDE_WINDOW_FREEFORM`.

### Task D5 — Resolve/cancel lifecycle and operations runbook

**Files**
- Modify SupportCase actions
- Modify `case_live.ex`
- Create: `docs/fastcheck_sales/runbooks/WHATSAPP_SUPPORT_OPERATIONS.md`
- Tests in support + LiveView suites.

**TDD**
- [ ] RED resolve only claimed case by owning operator.
- [ ] RED resolve clears only support-specific `needs_human` / `handoff_reason` when safe.
- [ ] RED unrelated safety/manual-review reason remains.
- [ ] RED queue mirrors invalidated + PubSub.
- [ ] Document claim/reply/resolve, failure recovery, Meta auth error, outside-window behavior, retention/PII rules.
- [ ] `mix precommit`, Gate D PR, exact-head CI, stop.

**STOP**
`STOP=UNRELATED_MANUAL_REVIEW_CLEARED`, `STOP=RUNBOOK_MISSING_FAILURE_RECOVERY`, `STOP=PRECOMMIT_FAILURE`.

---

# Gate E — Controlled WhatsApp / Paystack E2E Certification Event

## Outcome

A repeatable, operator-safe sandbox event certifies navigation, purchase, payment, issue, resend, and human support without ad-hoc production SQL.

### Task E1 — Harden/extend the existing supported sandbox fixture

**Files**
- Modify only as required: `lib/fastcheck/sales/sandbox_fixtures.ex`
- Extend/create: `test/fastcheck/sales/sandbox_fixtures_test.exs`

**Existing authority**
`FastCheck.Sales.SandboxFixtures` already owns clearly-prefixed WhatsApp sandbox events/offers, can ensure/reset them, and protects reuse against active durable Orders/checkouts/Redis holds/uncertain inventory.

**Rules**
- Reuse this boundary.
- Do not create a second fixture subsystem.
- Keep sandbox ownership by event name + shortname prefixes.
- Event initially exists with WhatsApp gate safely controlled.
- Paystack environment must be test before enabling the certification window.
- Never reset fixture if active/uncertain commercial state makes reset unsafe.

**TDD**
- [ ] RED fixture ownership cannot match ordinary production event.
- [ ] RED unsafe reset blocked when active/uncertain state exists.
- [ ] RED offer/inventory is sufficient for quantity 1–3.
- [ ] RED enable/disable path uses supported application actions.
- [ ] Implement only missing capability.

**STOP**
`STOP=AD_HOC_SQL_FIXTURE`, `STOP=PRODUCTION_EVENT_MATCH`, `STOP=ACTIVE_STATE_RESET`.

### Task E2 — Create certification runbook and evidence matrix

**Files**
- Create: `docs/fastcheck_sales/runbooks/WHATSAPP_E2E_CERTIFICATION_EVENT.md`

**Matrix**
1. main menu/no Back;
2. no-events actionable behavior;
3. purchase quantity 1;
4. purchase quantity 2/3;
5. Paystack test success;
6. payment confirmation;
7. ticket issue/delivery;
8. resend mixed-case email;
9. exact phone match candidate;
10. nonmatching phone candidate still eligible;
11. one ticket auto-select;
12. multiple tickets select one;
13. invalid OTP;
14. expired OTP;
15. locked/rate-limited OTP;
16. Help before purchase;
17. Help with active Order;
18. human claim/reply;
19. customer `0` leaves support;
20. duplicate/concurrency checks;
21. Meta auth failure operational response;
22. final disable/cleanup.

**Required evidence**
- deployment SHA/tree;
- Railway deployment ID;
- Meta test sender/recipient only;
- Paystack test mode proof without exposing keys;
- selected database state using read-only safe queries;
- exact CI IDs;
- screenshots/text transcript with PII minimized;
- fixture disabled at end.

**STOP**
`STOP=PAYSTACK_NOT_TEST`, `STOP=WHATSAPP_GATE_NOT_CONTROLLED`, `STOP=REAL_CUSTOMER_DATA`, `STOP=SECRETS_IN_EVIDENCE`.

### Task E3 — Run certification only after Gate E code/docs PR is merged

No implementation change in this task.

**Sequence**
- [ ] Verify exact merged main + post-merge CI.
- [ ] Verify production deployment source is exact approved main.
- [ ] Verify fresh/non-expired Meta credential.
- [ ] Ensure/reset sandbox through `SandboxFixtures`.
- [ ] Enable test event only for the certification window.
- [ ] Execute the matrix.
- [ ] Disable WhatsApp sales for test event immediately after.
- [ ] Confirm no active sandbox holds/orders require reconciliation before any reset/archive.
- [ ] Produce final certification report.

**STOP**
`STOP=MAIN_MOVED`, `STOP=DEPLOY_SHA_UNKNOWN`, `STOP=META_AUTH_ERROR_190`, `STOP=PAYSTACK_LIVE`, `STOP=CERTIFICATION_STEP_FAILS`, `STOP=FIXTURE_CANNOT_DISABLE`.

---

# Integration / PR Sequence

```text
PR-0 docs authority (signed)
  ↓ merge + post-merge CI
PR-A navigation contract
  ↓ merge + post-merge CI + live smoke
PR-B email-first resend
  ↓ merge + post-merge CI + focused live smoke
PR-C support domain/routing
  ↓ merge + post-merge CI
PR-D operator inbox/replies
  ↓ merge + post-merge CI
PR-E sandbox/runbook hardening
  ↓ merge + post-merge CI
E2E certification run
```

Do not combine PR-B/C/D. Their failure domains and security review are materially different.

---

# Performance & Scaling Review by Gate

| Gate | Hot | Warm Redis | Cold/Postgres | Index/Bound | Invalidation / PubSub |
|---|---|---|---|---|---|
| A Navigation | none | none | existing Conversation/Order only | no new query | none |
| B Resend | tiny orchestration state | ZSET rate limits, 15m-class TTL | Challenge + bounded candidates | normalized email index; max 10 candidates | challenge terminal/bind invalidates rate/candidate cache if any |
| C Support | ETS/GenServer queue summary | waiting ZSET; claimed SET/ZSET; summary HASH 30s–5m; bounded LIST | SupportCase/Message | active-case unique; state/requested; operator/state; messages case/time | create/claim/cancel/resolve broadcasts internal IDs |
| D Inbox | LiveView assigns, ETS summary | same support mirrors | bounded paginated details | page <= 50; message pages bounded | PubSub only, no polling |
| E Test | existing runtime | existing inventory/holds | sandbox-owned durable records | existing offer/inventory indexes | standard sales invalidation |

100k-user gate questions for every PR:
- Does this add an avoidable DB call per inbound message?
- Is the query bounded and indexed?
- Is high-velocity state represented in Redis appropriately?
- Can data be streamed/paginated instead of loaded?
- Does any cache become authority accidentally?
- Can cache misses stampede?
- Is any large analytics/table scan introduced?
- Is customer PII present in hot/warm keys or payloads?

Any unsafe answer is a STOP before review.

---

# Scaffolding TOON Prompt

| Field | Content |
|---|---|
| **Task** | Implement the approved WhatsApp customer-service/resend programme strictly gate-by-gate: Gate 0 signed docs, A navigation, B email-first resend, C support domain/routing, D support UI/outbound, E sandbox certification. |
| **Objective** | Deliver a customer WhatsApp experience with no dead ends, one clear navigation escape, email-OTP-secured one-ticket resend, direct same-thread human takeover, and a repeatable Paystack-test certification path without weakening existing commercial/order/inventory guarantees. |
| **Output** | Separate signed PRs for each gate; exact files/tests/migrations defined in `docs/superpowers/plans/2026-10-15-whatsapp-customer-service-resend.md`; post-merge CI between gates; final E2E certification report. |
| **Note** | Start from verified `origin/main` in an isolated worktree. TDD every task. Keep Postgres durable authority; ETS/GenServer hot, Redis warm. Resend ZSET rate limits with hashed keys and explicit TTL. Support queue ZSET, claimed SET/ZSET, summaries HASH 30s–5m, bounded LIST; PubSub push only. Required indexes: normalized issued-order email; active SupportCase unique by conversation; queue/operator/message indexes. Never raw PII in Redis/Oban/logs/PubSub. Preserve active Order guards. No direct production SQL/data resets. Signed commits only. STOP on main drift, unsigned history, scope expansion, test/CI failure, unbounded query, auth weakening, Redis authority drift, or PII leakage. |

---

# Granular TOON Micro-Prompts

## Config / Authority

### TOON 0.1 — Canonicalize approved docs

| Field | Content |
|---|---|
| **Task** | Reconstruct the approved spec and implementation plan on a signed docs-only branch. |
| **Objective** | Turn the approved but unsigned draft spec into canonical mergeable authority before code begins. |
| **Output** | Exact approved spec at `docs/superpowers/specs/2026-10-15-whatsapp-customer-service-resend-design.md`; this plan at `docs/superpowers/plans/2026-10-15-whatsapp-customer-service-resend.md`; signed docs-only PR. |
| **Note** | Use isolated worktree. Prove spec byte identity to branch `docs/whatsapp-customer-service-resend-design`. `git diff --check`; signed commit verification. No code/migration changes. STOP=MAIN_MOVED_UNREVIEWED, SPEC_BYTES_DIFFER, UNSIGNED_COMMIT, NON_DOC_FILE_CHANGED. |

## Navigation

### TOON A1 — Renderer contract

| Field | Content |
|---|---|
| **Task** | Update WhatsApp copy/rendering so main menu has no Back and subflows advertise only `0. Main menu`. |
| **Objective** | Remove confusing navigation vocabulary and customer dead ends without changing input normalization. |
| **Output** | `copy.ex`, `menu_renderer.ex`, focused renderer/copy/navigation tests. |
| **Note** | Main menu only Buy/Help/Resend. Never advertise `#`; preserve hidden support later. Preserve monospace delimiter hardening. No DB/Redis changes. STOP if InputNormalizer changes or active-order copy semantics weaken. |

### TOON A2 — State-machine navigation

| Field | Content |
|---|---|
| **Task** | Map `0` to safe contextual main-menu recovery and preserve hidden `#` recovery. |
| **Objective** | Make advertised navigation deterministic while preserving commercial Order and PR #535 recovery safety. |
| **Output** | `conversation_state_machine.ex` (+ `conversation.ex` only if transition declarations require it), focused state/active-order tests. |
| **Note** | `0`/`#` must never cancel/detach active Order. Invalid input repeats actionable menu. No new Redis/DB calls. STOP on commercial guard weakening or precommit failure. |

## Resend

### TOON B1 — Resend states/migration

| Field | Content |
|---|---|
| **Task** | Add email-first resend states and legacy state compatibility. |
| **Objective** | Move new conversations to email-first without stranding durable old resend conversations/challenges. |
| **Output** | `conversation.ex`, state machine, one migration, transition/compatibility tests. |
| **Note** | New states include `collecting_resend_email`, `collecting_resend_otp`, `selecting_resend_ticket`; legacy `collecting_resend_name` recoverable. Migration reversible. No challenge evidence rewrite. STOP on legacy breakage. |

### TOON B2 — Email-first request

| Field | Content |
|---|---|
| **Task** | Make new resend request accept normalized email without customer-entered name. |
| **Objective** | Remove typo-prone identity input while keeping email OTP as proof. |
| **Output** | `request.ex`, `resend_flow.ex`, copy/renderer, focused tests. |
| **Note** | Email lower+trim. Keep legacy name normalizer but do not require it. Phone/WA ID source metadata only. No PII logs. STOP if phone becomes authentication. |

### TOON B3 — Identity OTP

| Field | Content |
|---|---|
| **Task** | Allow resend OTP challenges to be issued before a ticket candidate is bound. |
| **Objective** | Verify email ownership before exposing/selecting ticket metadata. |
| **Output** | `ticket_resend_challenge.ex`, `otp.ex`, `email_otp.ex`, lock-version migration, OTP tests. |
| **Note** | Candidate IDs/hash nullable for new identity challenge; legacy candidate-bound challenge remains valid. Add optimistic lock. OTP plaintext memory-only. STOP on plaintext persistence or legacy break. |

### TOON B4 — Candidate lookup

| Field | Content |
|---|---|
| **Task** | Implement bounded, indexed post-OTP candidate discovery by normalized email with phone ranking. |
| **Objective** | Find eligible tickets safely and quickly without treating phone as proof. |
| **Output** | New `candidate_lookup.ex`, normalized-email index migration, candidate tests; `eligibility.ex` delegates query. |
| **Note** | Preserve strict issued/valid/not-revoked/not-archived/payment-complete predicates. Limit 10 to detect >9. Exact buyer-phone sorts first but nonmatches remain. Required functional/partial email index; prove query plan. STOP on unbounded query/seq scan/preverify disclosure. |

### TOON B5 — One-ticket binding

| Field | Content |
|---|---|
| **Task** | Bind exactly one still-eligible ticket to a verified challenge and support 2–9 ticket selection. |
| **Objective** | Make multi-ticket resend deterministic and concurrency-safe. |
| **Output** | New `challenge_binding.ex`, resource/state/render/orchestration changes, E2E resend tests. |
| **Note** | Recompute eligibility after OTP and before bind. Optimistic lock. Same selection idempotent; different rebind rejected. >9 goes to support. Invalidate/expire on leave. STOP on rebind or stale candidate delivery. |

### TOON B6 — Redis resend rate limits

| Field | Content |
|---|---|
| **Task** | Move high-velocity resend lookup/candidate rate limits to atomic Redis ZSET windows while retaining durable audit. |
| **Objective** | Scale resend abuse protection without peak DB writes/scans. |
| **Output** | `rate_limit.ex` using existing Redis boundary, atomic tests, durable audit unchanged. |
| **Note** | Hashed keys only; 15m-class TTL/window; atomic trim/count/add/expire; explicit Redis outage behavior. Redis is not durable authority. STOP on raw PII key, non-atomic race, or disabled rate limiting on outage. |

## Support Domain

### TOON C1 — Support resources

| Field | Content |
|---|---|
| **Task** | Add `FastCheck.Support`, `SupportCase`, and `SupportMessage` with lifecycle/indexes/policies. |
| **Objective** | Give human takeover a durable domain rather than hiding it in conversation JSON. |
| **Output** | Support domain/resources, migration, lifecycle/policy/index tests. |
| **Note** | States waiting/claimed/resolved/cancelled; terminal resolved/cancelled; partial unique active-case index; optimistic lock; global-ops V1 operator authority; message case/time + provider dedupe indexes. STOP on duplicate active cases/no lock/new auth system. |

### TOON C2 — Message encryption

| Field | Content |
|---|---|
| **Task** | Encrypt/decrypt support bodies through a focused wrapper around existing project crypto. |
| **Objective** | Prevent plaintext support content from entering durable storage or diagnostics. |
| **Output** | `message_cipher.ex`, resource integration, encryption/redaction tests. |
| **Note** | No new crypto primitive/dependency. Plaintext must not appear in DB/logs/Inspect. Ciphertext sensitive. STOP on plaintext persistence/logging. |

### TOON C3 — Help routing

| Field | Content |
|---|---|
| **Task** | Route Help → description → waiting case and suppress Sales bot transitions while support is active. |
| **Objective** | Provide direct same-thread human takeover with deterministic exit. |
| **Output** | `support/router.ex`, WhatsApp state/copy/render changes, support routing tests. |
| **Note** | Do not create empty case until nonblank description. Duplicate inbound deduped. During active support all normal content is support content; only `0` leaves (hidden `#` compatibility if retained). Preserve active Orders and unrelated handoff reasons. STOP on bot transition during support. |

### TOON C4 — Queue mirrors

| Field | Content |
|---|---|
| **Task** | Add ETS/GenServer + Redis + PubSub mirrors for active support queue. |
| **Objective** | Keep realtime operator queue fast and horizontally scalable without polling/Postgres hot scans. |
| **Output** | `queue.ex`, `queue/server.ex`, supervision, queue tests. |
| **Note** | Waiting ZSET; claimed SET/ZSET; summary HASH 30s–5m; bounded activity LIST; internal IDs only; rebuild from Postgres; PubSub no PII. DB lock remains authority. STOP on Redis ownership lock or PII PubSub. |

## Operator UI / Delivery

### TOON D1 — Authorized support routes

| Field | Content |
|---|---|
| **Task** | Add `/dashboard/support` and case route behind existing dashboard + global-ops pipelines. |
| **Objective** | Reuse server-owned authorization and prevent spoofed operator authority. |
| **Output** | `router.ex`, `inbox_live.ex`, auth/mount tests. |
| **Note** | Use `GlobalOpsAuth`; no caller-supplied allowed_event_ids/current_user trust. No second login. STOP on auth bypass. |

### TOON D2 — Inbox/claim

| Field | Content |
|---|---|
| **Task** | Build bounded realtime waiting inbox with optimistic claim. |
| **Objective** | Let one operator safely take ownership under concurrency. |
| **Output** | Inbox LiveView + domain actions/tests. |
| **Note** | No polling. Page <=50. PubSub updates. Two-operator claim race: exactly one wins. ETS/Redis hot reads, durable detail fetch bounded. STOP on unbounded load or claim race. |

### TOON D3 — Case history

| Field | Content |
|---|---|
| **Task** | Build authorized case view with bounded decrypted support history. |
| **Objective** | Give operator context without leaking/decrypting more data than required. |
| **Output** | `case_live.ex`, pagination/decryption/auth tests. |
| **Note** | Decrypt only after global-ops auth. No browser persistent storage of plaintext. Recipient not editable. Message pages bounded. STOP on unauthorized decrypt or PII persistence. |

### TOON D4 — Operator reply worker

| Field | Content |
|---|---|
| **Task** | Queue claimed-case operator replies through Oban and existing WhatsApp client. |
| **Objective** | Deliver same-thread human replies safely, idempotently, and with retry/failure visibility. |
| **Output** | `support_outbound_worker.ex`, message delivery actions, case UI submit path, worker tests. |
| **Note** | Job args contain IDs only. Reload/decrypt in worker. Destination from Conversation. Oban uniqueness by message ID. Enforce Meta service-window/template rule. No duplicate provider send. STOP on plaintext job args, recipient override, outside-window freeform, or duplicate send. |

### TOON D5 — Resolve/runbook

| Field | Content |
|---|---|
| **Task** | Complete resolve/cancel behavior and write support operations runbook. |
| **Objective** | Close cases safely and give operators a deterministic recovery procedure. |
| **Output** | Resolve UI/actions/tests; `WHATSAPP_SUPPORT_OPERATIONS.md`. |
| **Note** | Clear only support-specific handoff flags when safe. Invalidate mirrors + PubSub. Preserve unrelated manual review. Document Meta auth/token failure, retries, outside-window, privacy/retention. STOP on unrelated handoff clearing. |

## E2E Certification

### TOON E1 — Sandbox fixture hardening

| Field | Content |
|---|---|
| **Task** | Extend existing `FastCheck.Sales.SandboxFixtures` only where required for certification. |
| **Objective** | Reuse the supported sandbox-owned event/offer path instead of production SQL hacks. |
| **Output** | Minimal `sandbox_fixtures.ex` changes + fixture tests. |
| **Note** | Ownership by existing prefixes; unsafe reset blocked with active/uncertain state; quantity supports 1–3; Paystack test; controlled WhatsApp gate. Existing indexes/cache invalidation/inventory authority unchanged. STOP on ad-hoc SQL or production-event match. |

### TOON E2 — Certification runbook

| Field | Content |
|---|---|
| **Task** | Write the complete WhatsApp/Paystack certification runbook and evidence matrix. |
| **Objective** | Make full-system certification repeatable and auditable. |
| **Output** | `docs/fastcheck_sales/runbooks/WHATSAPP_E2E_CERTIFICATION_EVENT.md`. |
| **Note** | Include purchase/payment/issue/resend/support, mixed-case email, phone mismatch, multi-ticket, OTP failures, concurrency, Meta auth failure, exact deployment/CI evidence, and mandatory post-test gate disable. Never expose secrets/PII. |

### TOON E3 — Execute certification

| Field | Content |
|---|---|
| **Task** | Run the approved certification matrix against the exact verified production deployment using only the sandbox event and test payment/provider credentials. |
| **Objective** | Prove the complete customer journey works on real integrations before treating the programme as complete. |
| **Output** | Certification report with SHA/tree, deployment ID, CI, pass/fail matrix, minimized transcript/screenshots, and proof sandbox sales are disabled afterward. |
| **Note** | No code changes. Use Meta test sender/allowlisted recipients and Paystack test. Read-only DB evidence only. STOP on SHA mismatch, token error 190, live Paystack, test failure, secrets, or inability to disable fixture. |

---

# What Success Looks Like

## Plan success

- Every approved spec requirement maps to a named task.
- Every lifecycle has explicit states, guards, side effects, and terminal states.
- Each phase can be rejected independently without partially shipping the next subsystem.
- No agent must invent identity/auth/security/navigation semantics.
- Performance/index/cache/TTL/PubSub rules are stated before code.
- Existing commercial Order and ticket issuance authority remains untouched.

## Implementation success

```text
MAIN MENU
1. Buy tickets
2. Help
3. Re-send ticket
```

No meaningless Back.

```text
SUBFLOW
...
0. Main menu
```

No advertised `#`, but old `#` still safely recovers.

Resend:
```text
email -> OTP -> exactly one ticket OR select one of 2–9 -> resend
```

Support:
```text
Help -> short description -> waiting -> claimed -> same-thread human replies -> resolved
```

Certification:
```text
WhatsApp -> purchase -> Paystack test -> ticket issue -> resend -> support
```

all on exact verified code, with the sandbox gate disabled at the end.

---

# Execution Recommendation

Use **subagent-driven development** for this programme. Gate B (resend identity/security) and Gates C/D (human support authorization, PII, concurrency, provider delivery) are high-cost failure domains where an independent fresh reviewer after every task is worth the extra context. Do not let one agent implement all gates before review.

Gate 0 is authorized. Gates A-E remain unauthorized until the preceding gate is reviewed, merged, and post-merge CI is accepted.


# Proposed Chatwoot amendment for Gate 0 review

- **Status:** PROPOSED; owner decisions required
- **Authority effect:** None until the owner approves and signs a revised plan
- **Implementation authorization:** NO
- **Architecture reference:** `docs/superpowers/specs/2026-11-10-whatsapp-flows-chatwoot-integration-design.md`, v0.2.3, Proposed

This appendix prepares a replacement plan for the human-support workspace. It does not edit or revoke the approved October 15 specification or the task definitions above. Until the owner signs this amendment, the October 15 tasks remain controlling and the only current authorization remains Gate 0. No support implementation gate below is authorized by adding this appendix.

## Owner approval decisions

The owner must complete these decisions before Gate 0 can close. Record the owner, date, decision, and exact spec/plan revisions. A blank or conditional response leaves Gate 0 open.

### Decision H1: support workspace and task replacement

**Proposed decision:** Approve Option A. FastCheck remains the only Meta webhook owner and WhatsApp sender and remains authoritative for routing, customer binding, orders, checkout, Paystack verification, inventory, tickets, and resend. Chatwoot API Inbox becomes the human-support workspace and transcript only after Support Gate A verifies the selected self-hosted Community Edition contract. Approve exactly the task dispositions in §15 of the v0.2.3 design. Keep the October navigation and email-first resend tasks unchanged.

Select one:

- [ ] Approve the proposed Option A task matrix.
- [ ] Reject it; the October 15 custom-support tasks remain unchanged.
- [ ] Return it for revision and list the required changes.

Approval does not authorize application implementation, Chatwoot installation, Meta changes, or deployment. Each later gate requires a separate authorization.

### Decision H2: global STOP and opt-out semantics

**Proposed decision:** STOP is classified before support or Sales routing and is never stored or forwarded as support content. The implementation must call the exact owner-approved global privacy/consent authority. The current source has state-specific `:stop` handling but no separate persisted opt-out record; this plan does not invent consent persistence or re-subscription behavior.

The owner must identify the controlling policy and source path, then record:

- whether STOP ends only the current support conversation or also records a persistent consent/marketing opt-out;
- the authoritative persistence field/resource and the actor allowed to clear or change it;
- which outbound messages are suppressed, including support replies, retries, and system notices;
- whether a confirmation is permitted, its approved content/channel constraints, and whether it can be sent outside the customer-service window;
- the re-subscription or re-consent action, if applicable; and
- how existing held content is retained or erased under the approved privacy rule.

Choose one:

- [ ] Approve the identified existing authority and record its exact path and behavior above.
- [ ] No applicable authority exists; commission a separate owner-approved privacy decision before any STOP-related application work.
- [ ] Reject the proposed routing rule and provide the replacement authority.

Until resolved, do not implement STOP, opt-out, confirmation, or re-subscription changes. Keep Sales suppressed for a nonterminal handoff and do not let a missing handler route STOP into Sales.

### Decision H3: held customer messages on support exit

**Proposed decision:** No held customer message is silently dropped or delivered to a different support episode without owner approval, and no message is used to reopen Sales. The owner must choose the disposition independently for customer exit (`0`/`#`) and STOP, subject to the STOP policy in H2.

For each trigger, select one approved disposition:

- [ ] Deliver the held messages to the currently bound Chatwoot episode before terminalization.
- [ ] Carry the same BridgeMessage records into a successor episode under an approved reopen rule.
- [ ] Cancel the held messages under an approved privacy/retention rule. Specify deletion timing and any permitted customer notice; STOP suppression controls whether a notice can be sent.
- [ ] Other owner-specified disposition: ____________________________________

| Trigger | Selected disposition | Notice/retention conditions |
|---|---|---|
| Customer exit (`0`/`#`) | Pending owner decision | Pending owner decision |
| STOP after H2 handler | Pending owner decision | Pending owner decision |

Until both rows are approved, keep the messages encrypted and the handoff nonterminal. The owner may select an authorized deletion outcome if the controlling privacy rule requires it; the implementation must record that outcome before terminalization.

## Proposed support gate sequence

These gates are named `Support Gate` to distinguish them from the October plan's Gate A navigation work and Gate B resend work. All statuses below are **PROPOSED / NOT AUTHORIZED**. A signed plan revision and separate owner authorization are required before work in any gate begins.

### Support Gate 0: authority and plan adoption

**Outcome:** The owner has completed H1-H3, approved the precise task matrix in §15 of the design, and signed a revised plan that preserves the October authority as history. No code, migrations, infrastructure, Meta settings, or production state changes occur in this gate.

**Files:**

- Review: `docs/superpowers/specs/2026-11-10-whatsapp-flows-chatwoot-integration-design.md`
- Review: `docs/superpowers/plans/2026-10-15-whatsapp-customer-service-resend.md`
- Any approved authority record: owner-selected documentation path, named before approval

**Acceptance:** H1, H2, and both H3 rows are recorded; every affected October task ID has an approved disposition; current Gate 0-only authorization is explicitly replaced or reaffirmed by the owner. The approval record names the next separately authorized gate.

**STOP:** `STOP=OWNER_POLICY_DECISION_REQUIRED`, `STOP=AUTHORITY_CONFLICT_UNRESOLVED`, `STOP=MAIN_MOVED`, `STOP=NON_DOC_SCOPE`.

### Support Gate A: pinned Chatwoot contract feasibility

**Dependency:** Support Gate 0 approval and separate authorization to use an isolated disposable environment. This gate makes no FastCheck application change and no Meta configuration change.

**Files/evidence:**

- Create: `docs/fastcheck_sales/runbooks/WHATSAPP_CHATWOOT_FEASIBILITY.md`
- Store sanitized request/response fixtures, if approved: `test/fixtures/chatwoot_api_inbox/`
- Do not store tokens, secrets, customer identifiers, or unsanitized transcripts in fixtures.

**Acceptance outcomes:** Pin the self-hosted Community Edition release and record the exact license/feature basis. Prove the API Inbox contact/conversation/message flow, callback authentication, sender/public/private classification, duplicate and retry behavior, timeout reconciliation, source-message read-back/order completeness through close, resolution/assignment behavior, token rights, retention, backup/restore, and operational API limits. Record a fixture and an observed pass/fail for each question in design §11. Do not infer callback behavior from account-webhook documentation.

**Performance/scaling:** Record observed request limits and latency for the pinned release. Do not invent vendor quotas. Select bounded request concurrency and timeout/retry policy from observed behavior, with retry only after verified non-acceptance. Keep evidence small and sanitized.

**STOP:** `STOP=VENDOR_API_UNVERIFIED`, `STOP=LICENSE_OR_ACCESS_UNRESOLVED`, `STOP=AMBIGUOUS_CREATE_UNRECONCILABLE`, `STOP=CLOSE_READBACK_INCOMPLETE`, `STOP=CALLBACK_AUTH_UNVERIFIED`, `STOP=CAPACITY_UNPROVEN`.

### Global WhatsApp Consent Gate CG-1: durable recipient consent and shared outbound authorization

**Status:** Proposed only; not authorized. This is a distinct, independently reviewed implementation gate for the H2 policy. It does not change the October task history or authorize any sender behavior before H2 is approved.

**Ownership:** Accountable workstream: FastCheck WhatsApp/backend. The signed task authorization must name the implementer and a separate independent reviewer before work starts. The business policy owner must complete and approve every pending H2 decision; the implementer must not choose those values.

**Dependency:** Gate 0 is formally signed and H2 has approved the implementation rules for STOP identity matching and state effects, bounded customer-initiated service replies, category-specific `opted_in` eligibility, and fail-closed administrative recovery. CG-1 itself requires separate owner authorization and one reviewable PR. Support Gate A may run independently only with separate authorization and no customer send. Historical customer migration is a pre-release condition, not a development prerequisite: before enabling live WhatsApp messages, inventory the verified launch environment and classify recipient records using documented provenance. If the verified inventory establishes that no genuine pre-existing customer recipients exist, historical evidence migration is N/A. If any genuine recipient exists, or provenance cannot establish whether a record is a test contact or a genuine recipient, stop release until the owner approves the historical evidence/migration rule and any required migration is completed and independently reviewed. A nonzero raw row count alone does not prove a genuine customer; sandbox/test records may be excluded only with documented provenance. The new Postgres consent schema migration remains required in all cases. CG-1 implements the shared authorization for existing send paths; no other gate may add or alter a WhatsApp send path until CG-1 passes.

**Purpose and scope:** Persist consent by the FastCheck business WhatsApp number and verified recipient identity, across events and support episodes. Postgres is the durable authority. A normal inbound message, purchase, new event conversation, Chatwoot state, or event-level Sales flag cannot grant consent or override an opt-out. STOP is processed before Sales/support routing. A repeated STOP is idempotent; STOP during `reconsent_pending` cancels the pending re-consent attempt and returns the recipient to the durable `opted_out` state. Re-consent, categories, customer confirmation, and retention follow only the signed H2 policy. No confirmation or category exception is inferred.

**Proposed files and call paths** (confirm the final consent resource and migration names in the reviewed implementation proposal before coding):

- Create `lib/fastcheck/consent.ex` and `lib/fastcheck/consent/whatsapp_consent.ex` for the durable consent authority, plus `priv/repo/migrations/<timestamp>_create_whatsapp_consents.exs`. The reviewed implementation proposal must confirm these paths and the protected recipient-identity representation before coding.
- Create `lib/fastcheck/messaging/whatsapp/outbound_authorization.ex` as the shared authorization boundary. It must authorize every Meta text and template attempt immediately before transport invocation and fail closed when current consent cannot be established.
- Modify or encapsulate `lib/fastcheck/messaging/whatsapp/client.ex` so application senders cannot bypass the shared authorization boundary. Keep this module as the Meta transport; it is not itself proof of consent.
- Integrate STOP persistence/routing and bot replies in `lib/fastcheck/workers/whatsapp_inbound_worker.ex`.
- Integrate payment-link sends in `lib/fastcheck/workers/send_whatsapp_payment_link_worker.ex`.
- Integrate ticket delivery and verified resend sends in `lib/fastcheck/workers/send_whatsapp_ticket_link_worker.ex`; verified resend queues this worker through `lib/fastcheck/messaging/whatsapp/resend_delivery_flow.ex`.
- Integrate support replies through `lib/fastcheck/workers/support_bridge_worker.ex` under Support Gate D. Gate D cannot pass before CG-1.
- Create focused consent/authorization tests under `test/fastcheck/consent/` and `test/fastcheck/messaging/whatsapp/`; extend the existing sender and resend tests listed below.

**Required lifecycle and enforcement:**

- Implement the signed H2 state transitions and durable audit evidence. A duplicate delivery of the same STOP inbound event must not duplicate state effects. A distinct STOP while already opted out remains opted out. STOP during `reconsent_pending` invalidates that pending attempt and cannot restore any category.
- Before live messaging, inventory the verified launch environment with read-only queries and documented provenance. Count genuine pre-existing customer recipients separately from sandbox/test contacts. Exclude a test contact only when its test/sandbox provenance is documented and reviewable; do not infer it from a nonzero count, phone number, or unverified label alone. If the verified genuine-recipient count is zero, record historical consent evidence migration as `N/A` for this greenfield launch. If any genuine recipient exists or provenance is ambiguous, stop release and obtain an owner-approved evidence/migration rule; do not send to those recipients until any required migration is implemented and independently reviewed. Missing, ambiguous, or unmapped evidence must never be bulk-classified as `opted_in`. Record sanitized counts and provenance outcomes without raw recipient identifiers.
- Implement the additive Postgres consent schema migration in every case, including a verified zero-recipient environment. Keep historical data backfill conditional on the pre-release inventory and approved rule. Define a rollout path that remains safe with existing Oban jobs and mixed application versions. Jobs queued before rollout must pass the same current-consent check when they execute; they cannot carry forward a prior grant. Document rollback behavior so a missing consent row or restored snapshot cannot silently re-enable WhatsApp sends.
- Route every text and template send from bot, payment, ticket, resend, and support through the same consent decision. A queued intent or previous worker authorization is not reusable permission. Each provider attempt, including a delayed job, restarted worker, retry, or re-enqueue, must obtain fresh consent authorization bound to that recipient, purpose/category, message intent, consent revision, and attempt.
- Serialize consent updates and final per-attempt authorization for the same business-number/recipient scope. Invalidate or revision-check any cache on consent changes; the cache is an optimization only. If the system cannot prove the cached revision is current, read the durable authority or deny the attempt. Never let a stale cache authorize a send.
- Preserve the documented non-atomic boundary: a STOP committed before final authorization blocks the attempt; a provider call already started cannot be recalled. Minimize the authorization-to-HTTP interval, reconcile accepted or ambiguous outcomes from provider evidence, and never retry an unknown or accepted attempt merely because STOP arrived.
- No WhatsApp message category, template, active order, or support handoff bypasses an unqualified STOP. Do not change checkout, Paystack verification, inventory, ticket issuance, ticket/resend authority, or the required Sales.DeliveryAttempt-to-Sales-Order relationship. Do not invent an alternative ticket-delivery channel while its authority remains pending.

**Focused test files and required outcomes:**

- Create `test/fastcheck/consent/whatsapp_consent_test.exs`: transitions, audit/idempotency, repeated STOP, STOP during `reconsent_pending`, and denied re-consent after STOP.
- Create `test/fastcheck/messaging/whatsapp/outbound_authorization_test.exs`: fresh per-attempt authorization, recipient/purpose/revision binding, expiry/restart/retry invalidation, cache invalidation/fail-closed behavior, and the authorization/HTTP race.
- Extend `test/fastcheck/workers/whatsapp_inbound_worker_test.exs`: STOP commits before support/Sales routing; duplicate STOP does not duplicate state effects; no bot reply is sent when H2 disallows it.
- Extend `test/fastcheck/workers/send_whatsapp_payment_link_worker_test.exs` and `test/fastcheck/workers/send_whatsapp_ticket_link_worker_test.exs`: opted-out and `unverified` recipients follow the approved policy for both text and template modes; queued and retried jobs revalidate; blocked sends do not mutate commercial state or claim provider acceptance.
- Extend `test/fastcheck/messaging/whatsapp/resend_ticket_e2e_test.exs`: verified resend retains OTP, one-ticket binding, and ticket authority while WhatsApp authorization is independently enforced; no consent result changes order/ticket state.
- Extend `test/fastcheck/messaging/whatsapp/client_test.exs` or the selected shared-boundary test: direct application send paths cannot bypass authorization, and only provider-started calls can produce provider outcome evidence.
- Under Support Gate D, add the planned `test/fastcheck/workers/support_bridge_worker_test.exs` coverage: agent replies use the same guard and a STOP during queued delay suppresses the Meta call.
- Race tests must pause a worker after a durable queue intent, commit STOP, resume it, and observe zero transport calls. A separate started-call test must show STOP cannot recall the call, blocks every later attempt, and leaves uncertain outcomes for reconciliation.
- Consent schema migration tests are required in all cases. If historical recipients require migration, tests must prove that missing/ambiguous evidence never silently promotes a recipient to `opted_in` and that the approved category mapping is applied without cross-recipient or cross-event leakage. The release record must show either a verified zero-genuine-recipient inventory making historical migration N/A, or the approved migration and its test results.
- Commercial regression outcomes must show orders, payments, inventory, tickets, resend challenges, and existing DeliveryAttempt invariants are unchanged when consent denies a send.

**Performance and scaling:** Use a unique, indexed lookup for the approved business-number/recipient identity scope and bounded audit/migration queries. Do not scan recipient or order tables on every send. Any cache must carry a consent revision and have bounded storage; no TTL or latency budget is assumed here. Record query count and send-authorization latency under the owner-approved workload before certification. Keep concurrency controls durable and recipient-scoped; do not rely on Redis, ETS, or an Oban uniqueness window as the consent lock. Do not log raw recipient identifiers, message bodies, consent evidence, tokens, or provider payloads.

**Acceptance:** The signed H2 policy is implemented as written; all enumerated send paths and retries use one fail-closed authorization boundary; repeated STOP and STOP during re-consent are idempotent and suppress sends; the additive consent schema migration passes in all cases; race and commercial regression tests pass; exact-head CI passes; and an independent reviewer verifies the complete call graph and schema migration before the gate is marked complete. Before any live messaging, the release record must also show either (a) a provenance-verified inventory of the launch environment with zero genuine pre-existing customer recipients, making historical evidence migration N/A, or (b) the separately owner-approved evidence/migration rule and its completed, reviewed migration. A nonzero raw database count of documented sandbox/test contacts does not alone block release. Any genuine recipient awaiting migration or any recipient whose provenance cannot be established blocks live release. Completion does not itself authorize deployment or production sends.

**STOP:** `STOP=H2_POLICY_VALUE_PENDING`, `STOP=GENUINE_RECIPIENTS_REQUIRE_APPROVED_MIGRATION`, `STOP=RECIPIENT_PROVENANCE_UNVERIFIED`, `STOP=SEND_PATH_BYPASSES_AUTHORIZATION`, `STOP=STALE_CONSENT_CAN_AUTHORIZE`, `STOP=STOP_RECONSENT_RACE_UNTESTED`, `STOP=IN_FLIGHT_OUTCOME_MISSTATED`, `STOP=CONSENT_MIGRATION_IMPLICITLY_OPTS_IN`, `STOP=SALES_INVARIANT_CHANGE`, `STOP=TEST_OR_CI_FAILURE`, `STOP=INDEPENDENT_REVIEW_MISSING`.

### Support Gate B: timestamp hardening and durable support records

**Dependency:** Support Gate A passes, H2/H3 are recorded, and this gate is separately authorized. This gate changes FastCheck source only after authorization; it does not alter Sales delivery invariants.

**Files:**

- Modify: `lib/fastcheck/messaging/whatsapp/inbound_normalizer.ex`
- Modify if needed to preserve timestamp provenance: `lib/fastcheck/messaging/whatsapp/message_command.ex`
- Extend: `test/fastcheck/messaging/whatsapp/inbound_normalizer_test.exs`
- Create: `lib/fastcheck/support.ex`
- Create: `lib/fastcheck/support/support_handoff.ex`
- Create: `lib/fastcheck/support/bridge_message.ex`
- Create migration: `priv/repo/migrations/<timestamp>_create_support_handoffs_and_bridge_messages.exs`
- Create/extend: `test/fastcheck/support/support_handoff_test.exs`
- Create/extend: `test/fastcheck/support/bridge_message_test.exs`

**Required timestamp regression:** The current normalizer calls `DateTime.from_unix!/1` for any syntactically valid parsed integer. An out-of-range integer can raise inside `received_at/1`; `normalize/2` then rescues the exception around the whole payload. Test supported boundary values, values outside both ends of the supported range, malformed/missing timestamps, and a mixed payload containing one invalid timestamp plus a valid sibling message. The hardened result must not let the exception escape per-message normalization or silently use a fallback timestamp as support-window evidence. Preserve explicit timestamp validity/provenance. Do not broaden `DeliveryWindow` or Sales send behavior.

**Other test outcomes:** Concurrent create attempts yield one nonterminal SupportHandoff; the partial unique index covers `requested`, `provisioning`, `open`, `closing`, and `recovery_required`; source-message and `(conversation_id, ingress_sequence)` uniqueness reject duplicates; lock-version races have one winner; BridgeMessage direction/status transitions match design §§5-6; encryption, redaction, and retention tests pass. Sales.DeliveryAttempt still requires its Sales Order.

**Performance/scaling:** Add only indexed lookups for conversation, source identity, state, and sequence. Keep ingress and state transitions in bounded transactions; never call Chatwoot while holding a database transaction. Use bounded pages for recovery scans. Enforce a durable unique constraint for each source event and one active handoff per conversation. Do not add Redis/ETS ownership locks or unbounded transcript storage.

**STOP:** `STOP=TIMESTAMP_RANGE_TEST_MISSING`, `STOP=TIMESTAMP_EXCEPTION_ESCAPES`, `STOP=INVALID_TIMESTAMP_TRUSTED`, `STOP=VALID_SIBLING_DROPPED`, `STOP=HANDOFF_UNIQUENESS_MISSING`, `STOP=SALES_INVARIANT_CHANGE`.

### Support Gate C: durable Help intake and customer-to-Chatwoot routing

**Dependency:** Support Gate B and CG-1 pass and this gate is separately authorized. This gate must use the approved durable STOP routing and shared outbound authorization; it may not add a direct Meta sender.

**Files:**

- Modify: `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex`
- Modify only as required: `lib/fastcheck/sales/conversation.ex`
- Modify: `lib/fastcheck/workers/whatsapp_inbound_worker.ex`
- Create: `lib/fastcheck/support/bridge_router.ex`
- Create: `lib/fastcheck/messaging/chatwoot/api_inbox_client.ex`
- Test: `test/fastcheck/messaging/whatsapp/support_routing_test.exs`
- Test: `test/fastcheck/support/bridge_router_test.exs`
- Test: `test/fastcheck/messaging/chatwoot/api_inbox_client_test.exs`

**Acceptance outcomes:** Help persists `collecting_support_description`; no SupportHandoff or Chatwoot case exists before a valid description. Invalid input, `0`, `#`, STOP, duplicates, process restart, and active-order recovery follow the approved policy. The first valid description atomically creates exactly one handoff and source BridgeMessage. Per-conversation sequence determines order. Every nonterminal state suppresses Sales. Customer messages during close/recovery are held with a durable disposition path. Chatwoot outages and ambiguous creates remain recoverable without duplicate external messages.

**Performance/scaling:** No N+1 lookup per inbound message. Per-conversation ordering uses the indexed durable sequence and lock only. Keep outbound Chatwoot work outside the routing transaction. Bound Oban concurrency and retries using Support Gate A observations; do not retry ambiguous creates. Track oldest pending age and queue depth without storing PII in telemetry.

**STOP:** `STOP=HELP_TEXT_REACHES_SALES`, `STOP=HANDOFF_CREATED_BEFORE_VALID_DESCRIPTION`, `STOP=ACTIVE_ORDER_CHANGED`, `STOP=SEQUENCE_ORDER_NOT_DURABLE`, `STOP=CHATWOOT_DUPLICATE_CREATE_POSSIBLE`, `STOP=SUPPORT_STATE_POLICY_MISSING`.

### Support Gate D: authenticated callbacks and FastCheck Meta replies

**Dependency:** Support Gate C and CG-1 pass; Gate A verified the exact callback contract; the approved H2/H3 policy is implemented in tests; this gate is separately authorized.

**Files:**

- Modify: `lib/fastcheck_web/router.ex`
- Create: `lib/fastcheck_web/controllers/webhooks/chatwoot_controller.ex`
- Create: `lib/fastcheck/messaging/whatsapp/support_delivery_status_reconciler.ex`
- Create: `lib/fastcheck/workers/support_bridge_worker.ex`
- Extend: `lib/fastcheck/support/bridge_message.ex`
- Create: `test/fastcheck_web/controllers/webhooks/chatwoot_controller_test.exs`
- Create: `test/fastcheck/messaging/whatsapp/support_delivery_status_reconciler_test.exs`
- Create: `test/fastcheck/workers/support_bridge_worker_test.exs`

**Delivery contract:** `FastCheck.Messaging.WhatsApp.Client` sends support replies to Meta. BridgeMessage is the sole support send and status ledger. The worker checks the latest valid signed inbound timestamp using the strict support-specific 24-hour rule immediately before each Meta call and retry. Reuse only compatible `OutboundDeliveryPolicy.classify/1` classification. Do not use `DeliveryPolicy`, commercial templates, or `Sales.DeliveryAttempt` for support replies. Chatwoot never sends directly to Meta.

**Acceptance outcomes:** Callback authentication and replay checks match the pinned release. Public human messages are admitted only while the handoff permits them. Private notes and system/customer echoes cannot become Meta sends. Callback retries deduplicate by Chatwoot message identity. Pre-fence replies follow the close-reason policy; post-fence replies are quarantined. Meta 429 is retryable only under the compatible classifier and a fresh window check. Permanent/ambiguous outcomes require the specified review/reconciliation. Exact WAMID mapping updates agent and system BridgeMessages; skipped status callbacks advance only to observed evidence. No delivery receipt is fabricated.

**Performance/scaling:** Callback handlers durably record before acknowledging and enqueue only internal IDs. Use indexed unique keys for callback identity and WAMID. Do not block HTTP handlers on Meta sends. Use bounded workers, per-handoff ordering, exponential backoff only for verified safe retry, and bounded status/restart reconciliation. Keep worker concurrency below the verified provider and deployment limits; record queue age and retry depth.

**STOP:** `STOP=CALLBACK_AUTH_OR_REPLAY_FAILURE`, `STOP=ECHO_CAN_SEND_TO_META`, `STOP=RECIPIENT_NOT_CONVERSATION_BOUND`, `STOP=OUTSIDE_WINDOW_SEND`, `STOP=SALES_DELIVERY_ATTEMPT_USED`, `STOP=UNKNOWN_OUTCOME_AUTO_RETRIED`, `STOP=STATUS_EVIDENCE_FABRICATED`.

### Support Gate E: staging certification and operations

**Dependency:** Support Gates A-D and CG-1 pass; this gate is separately authorized. Use test contacts and an isolated nonproduction FastCheck/Chatwoot environment. Keep Paystack in test mode. Do not use production customer data.

**Files:**

- Create: `docs/fastcheck_sales/runbooks/WHATSAPP_CHATWOOT_BRIDGE_OPERATIONS.md`
- Create: `docs/fastcheck_sales/runbooks/WHATSAPP_CHATWOOT_BRIDGE_CERTIFICATION.md`
- Create/extend: `test/fastcheck/support/chatwoot_bridge_integration_test.exs`
- Extend the existing sandbox fixture only if required: `lib/fastcheck/sales/sandbox_fixtures.ex`
- Extend: `test/fastcheck/sales/sandbox_fixtures_test.exs`

**Acceptance outcomes:** Pass the negative and race matrix in design §16, including Help restart, duplicate ingress, close fences, held-message disposition, STOP suppression, Chatwoot and Meta outages, out-of-range timestamps, strict window expiry, 429 retry, ambiguous send, skipped/out-of-order statuses, backup/restore, and cross-event rejection. Record exact source SHA/tree, test output, sanitized fixtures, callback and provider evidence, and rollback steps. Run focused tests through `scripts/with-test-db-env.sh mix test`; run `scripts/with-test-db-env.sh mix precommit` for the complete local gate. Require exact-head CI and independent review before requesting any later release decision.

**Performance/scaling:** Before testing, approve a workload profile and response/queue-age budgets; do not invent production capacity or vendor quotas. Under that profile, measure bounded ingress latency, queue depth/age, oldest handoff, callback latency, retry volume, DB query count, and restart-recovery duration. Verify all hot queries use the intended indexes and bounded pages. A load test must show no unbounded transcript scan, per-customer N+1 query, cache stampede, or PII in logs/metrics/jobs.

**STOP:** `STOP=STAGING_RACE_FAILURE`, `STOP=RESTORE_MISROUTES_HANDOFF`, `STOP=PERFORMANCE_BUDGET_UNSET`, `STOP=PII_IN_EVIDENCE`, `STOP=TEST_OR_CI_FAILURE`, `STOP=PAYSTACK_NOT_TEST`.

### Support Gate F: separately approved release and canary

**Status:** Proposed only; this plan appendix grants no production or deployment authorization.

**Files/evidence:** Approved release record, `docs/fastcheck_sales/runbooks/WHATSAPP_CHATWOOT_BRIDGE_OPERATIONS.md`, exact deployment manifest/configuration path confirmed by the deployment owner, and a post-release report. Do not add credentials to repository files.

**Dependency:** Support Gates A-E and CG-1 pass; a separate release authorization is required.

**Acceptance outcomes:** A separate owner decision names the exact SHA/tree, deployment target, time window, test recipients, operator coverage, rollback owner, support/Meta alerts, and success/abort thresholds. Start with the smallest approved canary. Verify the canary remains isolated from commercial state; verify rollback and queue recovery. Production Meta changes, secrets, Chatwoot installation, deployment, or live customer traffic require their own explicit authorization and are outside this plan's current authority.

**Performance/scaling:** Use only measured Gate E budgets and verified provider limits. Set configured concurrency, queue caps, alert thresholds, and rollback thresholds before rollout. Stop on sustained backlog growth, missed close-barrier targets, elevated ambiguity, or any event/tenant isolation failure.

**STOP:** `STOP=RELEASE_NOT_SEPARATELY_AUTHORIZED`, `STOP=DEPLOY_SHA_UNKNOWN`, `STOP=ROLLBACK_UNPROVEN`, `STOP=CAPACITY_OR_ALERTS_UNSET`, `STOP=PRODUCTION_MUTATION_NOT_AUTHORIZED`.

## Cross-gate performance and scaling rules

- Postgres owns SupportHandoff, BridgeMessage, per-message ingress order, close fences, delivery evidence, and durable WhatsApp consent. Redis, ETS, PubSub, and Oban are rebuildable scheduling or notification mechanisms only; none may grant or cache reusable send permission.
- Index the active handoff predicate, source event identities, `(sales_conversation_id, ingress_sequence)`, provider WAMID, and bounded status/reconciliation lookups. Verify representative query plans before staging.
- Use bounded batch sizes for restart scans, status reconciliation, and retention work. Keep transcript pages bounded; do not load a full conversation into LiveView assigns or worker arguments.
- Do not make network calls inside a database transaction. Persist a unique dispatch intent first, then call the provider outside the transaction and reconcile ambiguity without blind retries.
- Configure bounded worker concurrency, rate limits, retry budgets, and queue-age alerts from pinned-release observations and the approved workload profile. Do not invent API quotas or claim unverified capacity.
- Scope consent reads, serialization, and cache invalidation to the approved business-number/recipient key. Keep authorization lookups indexed and bounded; measure their query count and latency before certification. A cache that cannot prove the latest consent revision must fail closed.
- Keep plaintext, phone numbers, OTPs, ticket/payment links, secrets, and raw provider payloads out of logs, metrics, traces, Redis keys, PubSub payloads, fixtures, and Oban arguments.
- No performance target is accepted until the owner records workload, latency, queue-age, and recovery budgets. Missing budgets block Support Gate E.
- Any proposed change to Sales.DeliveryAttempt's required order relationship or to checkout, Paystack verification, inventory, ticket issue, or resend authority stops for a separate commercial decision: `STOP=COMMERCIAL_INVARIANT_CHANGE`.

## Current authority and stop state

This appendix is a proposal for owner review. The October 15 approved plan remains authoritative. Current authorization remains Gate 0 only. Proposed Support Gates A-F and Global WhatsApp Consent Gate CG-1 are not authorized. CG-1 implements the shared consent guard for current send paths. After CG-1 passes, no later implementation task may add or change a WhatsApp outbound path, including retained October tasks that reach a sender, without using that guard. No application code, migration, environment configuration, Meta/Chatwoot change, installation, deployment, or production data operation is part of this document change.

For this documentation task, any need to change application source is `STOP=APPLICATION_CHANGE_REQUIRED`. The timestamp parser hardening is recorded as a later Support Gate B task only.

- `STOP=OWNER_POLICY_DECISION_REQUIRED`
- `IMPLEMENTATION_AUTHORIZED=NO`
- `PRODUCTION_AUTHORIZED=NO`
