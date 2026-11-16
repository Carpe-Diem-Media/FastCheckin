# FastCheck Support Workspace Implementation Plan

| Field | Value |
| --- | --- |
| Status | `PROPOSED PLAN — REVIEW REQUIRED` |
| Architecture | Option B, adopted for support-workspace direction only |
| Implementation authorization | `NONE` |
| Runtime/production-send authorization | `NONE` |
| Scope | Gated implementation of a minimal FastCheck-owned WhatsApp support workflow |
| Issue | [FastCheckin #557](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557) |

This plan turns the adopted architecture into reviewable implementation slices. It does not authorize code, migrations, infrastructure, deployment, or production WhatsApp sends. Each future PR requires a separate implementation authorization and the applicable policy decisions below. The October implementation plan remains authorized for `GATE 0 ONLY`; it is not expanded by this document.

## 1. Authority and verified revisions

| Source | Verified revision | Authority used by this plan |
| --- | --- | --- |
| [October 15 approved support design](../specs/2026-10-15-whatsapp-customer-service-resend-design.md) | Git blob `8a0e7ea8040cb1292fcb0993ae1ec9d881afd79b`; approved design | Continues to govern customer navigation and support journeys, customer `0`, waiting-to-cancelled administrative close, STOP/privacy, ticket resend, ownership, payment, inventory, and commercial safeguards. |
| [November 14 replacement design](../specs/2026-11-14-fastcheck-support-workspace-replacement-design.md) | SHA-256 `71da64d7ab024c885328017b37841a4e4c63d051364de8e179967e237731ceda` | Supplies the replacement support architecture and technical invariants adopted only for this scope. Its embedded `PROPOSED — NOT ADOPTED` label is historical; the adoption record below is the current authority for the scoped direction. |
| [November 15 adoption decision](../decisions/2026-11-15-fastcheck-support-workspace-adoption.md) | SHA-256 `220e575d95b1eb80cba2a0e41c0d739d7c6705e24a41d74c2c211e7be074f759` | Records Option B adoption, retained October rules, unresolved owner policies, and the implementation boundary. |
| Owner adoption record | [Issue #557 comment 6909586126](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6909586126), authored by `JCSchoeman96` | Authenticated owner decision `OPTION_B_SUPPORT_WORKSPACE_ADOPTED`; the GitHub organization membership check reported the account role as `admin`. Scope is architecture only. |
| [October 15 implementation plan](2026-10-15-whatsapp-customer-service-resend.md) | Git blob `2f6146f6e3e1dcb29466778a3c618eb6c460d597`; `APPROVED FOR GATED EXECUTION`, `GATE 0 ONLY` | Remains the only approved implementation plan until a new or revised plan and separate implementation authorization are recorded. |
| Repository snapshot | `main` at `3893d2afeee0cdbb05dc8c331e18996f4cfa3e98` | Used to map current files and dependency versions. |

The adopted canonical domain is `FastCheck.Support`: `SupportCase`, `SupportMessage`, `ExternalCreateOperation`, `ConversationClosure`, and `SupportCaseEvent`. Assignment remains on `SupportCase`; do not add `SupportHandoff`, `SupportConversation`, `BridgeMessage`, or a competing aggregate. Existing `FastCheck.Sales.Conversation` remains the parent WhatsApp checkpoint.

The unchanged Chatwoot Gate A record is `A01–A03=PASS (AI-only)`, `A04=PARTIAL`, `A05=PASS (receiver safeguards only)`, `A06=FAIL`, `A07=BLOCKED`, `A08–A14=NOT RUN`, `FULL_GATE_A=NOT_ACCEPTED`. Option B adoption is not retrospective Chatwoot test success.

## 2. Planning assumptions and hard boundaries

- FastCheck/PostgreSQL owns the canonical support transcript, operator acceptance, message/dispatch states, case lifecycle, and closure decision.
- The existing WhatsApp webhook verification and `FastCheck.Messaging.WhatsApp.Client` remain provider boundaries. UI code never calls Meta directly.
- `SupportCase` states stay `waiting`, `claimed`, `resolved`, and `cancelled`. `resolved` and `cancelled` are terminal. A supported reopen creates a new case generation; it does not reverse a terminal case.
- `ConversationClosure` states stay `requested`, `fenced`, `reconciling`, `resolved`, `recovery_required`, and `aborted`; resolved and aborted closure attempts are immutable. `ExternalCreateOperation` states stay `queued`, `dispatching`, `provider_accepted`, `failed_retryable`, `failed_permanent`, `suppressed_before_dispatch`, `retry_suppressed`, `outcome_unknown`, `reconciling`, and `needs_review`. Customer delivery is a separate fact, not an operation state.
- Preserve the adopted transitions, including `claimed -> waiting` assignee release and the October `waiting -> cancelled` administrative close, using only existing approved actor authority. Do not invent a new role or infer that any authenticated dashboard user may close a case.
- Customer `0` remains an exit from support. It suppresses queued work that has not crossed the durable dispatch-authorization point; work already dispatching remains auditable and may still arrive. No implementation may promise recall or non-delivery.
- Existing STOP/privacy behavior has precedence. If the authoritative STOP/consent decision cannot be read, support sends remain disabled.
- The shared lock order is mandatory: (1) WhatsApp per-`wa_id` advisory transaction lock, (2) `Sales.Conversation`, (3) `SupportCase`, (4) `ConversationClosure`, (5) messages, operations, audit rows, and durable jobs. No path may acquire these in reverse order. Never perform external HTTP inside a database transaction.
- Customer/provider receipt identifiers and operator submission identifiers are required, non-null identity fields. PostgreSQL nullable composite unique indexes do not satisfy the adopted invariant.
- Jobs contain internal row IDs only. Message bodies, provider credentials, PII, and plaintext-derived replay fingerprints do not enter Oban arguments, PubSub payloads, logs, or caches.
- Message bodies remain encrypted using the existing `FastCheck.Crypto` boundary. The current encryption implementation does not settle key rotation, retention, deletion, or backup policy.
- Redis, ETS, GenServer, and PubSub may accelerate reads or notify clients after commit. They never decide acceptance, retry, closure, STOP, tenant scope, or provider outcome.
- The MVP has no Chatwoot runtime dependency or mirror. Chatwoot CE v4.19.1 files listed below are interaction references only. Do not port Vue/Vuex, ProseMirror, Rails, Chatwoot APIs, or Chatwoot-owned state. Any later source reuse needs a file-level license/dependency review and retained MIT notices.
- Pinned interaction references are `app/javascript/dashboard/components/ChatList.vue`, `app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue`, `app/javascript/dashboard/components/widgets/conversation/MessagesView.vue`, `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`, and `app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue`. Borrow queue, timeline, composer, header, and action patterns only; implement them with the repository's Phoenix LiveView, HEEx, components, and styling conventions. Do not copy source without a separate file-level license/dependency check.
- No real provider send is authorized by this plan. Provider-facing work must use injected fakes in tests until separately authorized operational release.

### Current dependency and code-path baseline

Installed and locked versions verified in the repository: Ash `3.33.11`, AshPostgres `2.13.1`, Oban `2.20.3`, and Phoenix LiveView `1.1.33`. Do not upgrade or add dependencies as part of these phases without separate review.

Current paths informing the slices:

- `lib/fastcheck/sales/conversation.ex`, `lib/fastcheck/sales.ex`
- `lib/fastcheck/messaging/whatsapp/inbound_checkpoint.ex`, `lib/fastcheck/messaging/whatsapp/webhook_scope.ex`, `lib/fastcheck_web/controllers/webhooks/whatsapp_controller.ex`
- `lib/fastcheck/workers/whatsapp_inbound_worker.ex`
- `lib/fastcheck/messaging/whatsapp/client.ex`, `config.ex`, `provider_status.ex`, `delivery_status_reconciler.ex`, and `outbound_delivery_policy.ex`
- `lib/fastcheck/operations/global_access.ex`, `lib/fastcheck_web/plugs/global_ops_auth.ex`, and the `[:browser, :dashboard_auth, :global_ops_auth]` router pipeline
- `lib/fastcheck_web/live/operations/workers_dashboard_live.ex` and `test/fastcheck_web/live/operations/workers_dashboard_live_test.exs` as LiveView conventions
- `FastCheck.Crypto.encrypt/1` and `decrypt/1` as the existing body-encryption boundary

No `FastCheck.Support` Ash domain or support resources exist at the verified repository revision.

## 3. Gated phase and PR sequence

Each numbered phase is one proposed PR boundary. Keep changes within the listed outcome; split a phase only if review shows a clear independent correctness boundary. No PR should start until its predecessor is accepted and its phase-specific owner gates are resolved. Phase 7 tests are cross-cutting and supplement, rather than replace, focused tests in earlier PRs.

| Phase / proposed PR | Outcome | Depends on | Earliest owner gate | STOP |
| --- | --- | --- | --- | --- |
| 1. Support domain and integrity | Ash resources, policies, lifecycle actions, and durable constraints establish the support aggregate without external effects. This is the minimum first slice. | Separate implementation authorization; approved October/ADR authority | Exact existing actor authority gates only the administrative-close action; stable actor identity for production operator actions; encryption/retention policy before real transcript data | `STOP=PHASE1_AUTHORIZATION_BYPASS` if a guarded action is callable without its required authority; unresolved administrative-close authority disables that action only |
| 2. Durable inbound receipt and routing | Verified inbound support messages become durable, deduplicated receipts with required downstream work committed before webhook acknowledgement. | Phase 1 | Verified single-account/provider-account scope before route activation; STOP/consent source before any automated response or agent send; reopen policy before reopening a terminal case | `STOP=INBOUND_IDENTITY_OR_CONSENT_UNVERIFIED` |
| 3. Idempotent reply acceptance | An authorized operator submission commits transcript, operation, audit, version/sequence, and durable dispatch intent/job atomically; no provider send is active. | Phases 1–2 | Named, non-shared operator identity policy before multi-agent production use; dispatch queue remains disabled | `STOP=REPLY_ACCEPTANCE_NOT_DURABLE` |
| 4. Safe Meta dispatch and outcome tracking | A separately gated worker consumes Phase 3's durable intent and maps provider outcomes without blind retries. | Phase 3 | Separate dispatch authorization, owner disposition for ambiguous Meta outcomes, and consent source; processing stays disabled until all gates pass | `STOP=DISPATCH_NOT_AUTHORIZED` before activation; `STOP=UNKNOWN_SEND_POLICY_UNRESOLVED` for unsafe or unresolvable outcomes |
| 5. Closure fence and customer exit | Case close and customer `0` are serialized with accepted messages and queued work, without trapping the customer on unknown sends. | Phases 2–4 | Owner decision on accepted-vs-delivered close requirement and customer notice for in-flight sends; exact October actor policy for administrative close | `STOP=CLOSE_OR_EXIT_POLICY_UNRESOLVED` |
| 6. Minimal LiveView workspace | Authenticated agents can see, claim/release, read, reply, resolve, and reopen only through guarded Ash actions. | Phases 1–5 | Named operator identity and reopen policy for production multi-agent use; test-only UI can proceed with synthetic actors | `STOP=UI_AUTHORIZATION_OR_POLICY_BYPASS` |
| 7. Integration, concurrency, and security qualification | Cross-boundary failure, replay, lock-order, authorization, and recovery tests exercise the complete synthetic workflow. | Phases 1–6 | Any still-open policy that affects a test oracle must be resolved for that oracle; unrelated tests remain runnable | `STOP=INVARIANT_TEST_FAILED` |
| 8. Performance and release qualification | Measured bounded query paths, recovery behavior, capacity targets, and release evidence are reviewed before deployment planning. | Phases 1–7 | Approved workload, SLO, recovery, retention, and deployment/security policies | `STOP=RELEASE_TARGETS_UNAPPROVED_OR_UNMET` |

## 4. Phase implementation cards

Paths below are proposed implementation paths, not files created by this planning task. Migration timestamps must be assigned as the next unique repository timestamp when implementation is separately authorized.

### Phase 1 — Support domain, policies, and integrity

#### 1.1 Create the canonical Ash domain and durable resource skeletons

- **Outcome:** `FastCheck.Support` owns the five adopted resources and their cross-domain references without duplicating `Sales.Conversation`.
- **Files:** create `lib/fastcheck/support.ex`; create `lib/fastcheck/support/support_case.ex`, `lib/fastcheck/support/support_message.ex`, `lib/fastcheck/support/external_create_operation.ex`, `lib/fastcheck/support/conversation_closure.ex`, and `lib/fastcheck/support/support_case_event.ex`; create `priv/repo/migrations/<next_timestamp>_create_support_workspace_resources.exs`; create `test/fastcheck/support/support_domain_test.exs` and `test/fastcheck/support/support_case_test.exs`.
- **Dependencies:** Current Ash `3.33.11` and AshPostgres `2.13.1`; existing `FastCheck.Sales.Conversation`; implementation authorization.
- **Minimum approach/actions and guards:** Register only the adopted resources in `FastCheck.Support`. `SupportCase` belongs to a Sales conversation and holds assignment. Keep transcript content out of `Sales.Conversation.state_data`. Establish resource attributes and relationships first; implement lifecycle actions in 1.3 and message/operation behavior in Phases 2–4. Use existing global-ops policy boundaries; do not add a role. Administrative `waiting -> cancelled` is available only if the exact October actor policy is confirmed. Use the existing encryption helper for synthetic message fixtures only until retention/key policy is approved.
- **Database constraints/indexes:** `support_cases`: unique `(conversation_id, generation)`; partial unique active case `(conversation_id) WHERE state IN ('waiting','claimed')`; `lock_version` and monotonic `next_message_sequence`; queue index `(state, requested_at, id)` and assignment index `(assigned_operator_id, state, updated_at, id)`. `support_messages`: unique `(support_case_id, sequence)` and keyset index `(support_case_id, sequence DESC)`. `external_create_operations`: unique UUIDv7 operation ID and one operation per logical support message/provider/kind. `conversation_closures`: unique `(support_case_id, closure_epoch)`; one active closure across `requested`, `fenced`, `reconciling`, and `recovery_required`. `support_case_events`: unique `(support_case_id, sequence)`. Foreign keys use restrictive deletion; no cascading deletion of audit history.
- **Caching/TTL/invalidation:** None for lifecycle correctness. Initial queue reads use bounded indexed Postgres queries. Publish no events until after commit.
- **Required tests:** Domain registration, resource relationships, FK/check constraints, restrictive deletion, and cross-domain ownership boundaries. Lifecycle and actor-policy tests are in 1.3.
- **STOP:** `STOP=DOMAIN_AUTHORITY_UNRESOLVED` if an action needs an unapproved actor, tenant boundary, or lifecycle interpretation. Keep independent schema/policy tests runnable where the unresolved decision is not needed.

#### 1.2 Enforce non-null identities and durable unique keys

- **Outcome:** The database rejects identity-less rows for all adopted receipt and reply paths, including cases where a nullable composite unique index would silently permit duplicates.
- **Files:** modify `priv/repo/migrations/<next_timestamp>_create_support_workspace_resources.exs`, `lib/fastcheck/support/support_message.ex`, and `lib/fastcheck/support/support_case_event.ex`; create `test/fastcheck/support/support_identity_constraints_test.exs` and `test/fastcheck/support/support_lifecycle_concurrency_test.exs`.
- **Dependencies:** 1.1; owner-adopted identity rules.
- **Minimum approach/actions and guards:** Operator-reply rows require non-null `provider_account_key` and `client_submission_id`; inbound message rows require non-null `provider_account_key` and `provider_message_id`; body-free customer `0` receipt events require non-null `provider_account_key` and `provider_message_id`. Provider account scope comes only from verified channel configuration, never request fields. Use direction/event check constraints if a table supports multiple row kinds. Phase 3 adds authorized exact-payload replay behavior; Phase 2 performs cross-table receipt reconciliation under the shared WhatsApp advisory lock. Do not persist plaintext-derived hashes.
- **Database constraints/indexes:** Enforce required-field `NOT NULL` constraints; unique operator identity `(provider_account_key, client_submission_id)`; unique inbound identity `(provider_account_key, provider_message_id)` on inbound message rows; unique customer-exit receipt identity on the event row; and the case-generation/message-sequence constraints from 1.1. PostgreSQL nullable composite uniqueness is not accepted as a substitute for required identities.
- **Caching/TTL/invalidation:** No replay or identity cache is authoritative. Redis may not discard a webhook before the PostgreSQL receipt transaction commits. Any future cache is a read accelerator with explicit post-commit invalidation only.
- **Required tests:** Missing identifiers rejected at the DB boundary; same-account duplicate identities rejected under concurrent insert; no inbound or exit identity can be represented with null columns; database and Ash resource validations agree.
- **STOP:** `STOP=SUBMISSION_IDENTITY_UNSAFE` if a required identity is nullable or a duplicate identity can commit.

#### 1.3 Add adopted case lifecycle actions and authorization guards

- **Outcome:** Implement the Phase 1 case actions whose guards are fully enforceable, while keeping `claimed -> resolved` unavailable until Phase 5 installs the complete close fence.
- **Files:** modify `lib/fastcheck/support/support_case.ex` and `lib/fastcheck/support/support_case_event.ex`; create `test/fastcheck/support/support_case_lifecycle_test.exs` and `test/fastcheck/support/support_case_authorization_test.exs`.
- **Dependencies:** 1.1–1.2; existing actor identity and policy boundaries. Exact October administrative-close actor authority is required only to enable that action.
- **Minimum approach/actions and guards:** Add Ash actions for creating a waiting case after valid intake, claiming it, releasing `claimed -> waiting`, and customer cancellation from waiting/claimed. Preserve October `waiting -> cancelled` administrative close as an explicit capability, but fail closed until its exact existing actor policy is verified; do not invent a role. Do not add a public closure request/finalize action or generic update that can set `resolved`; the `claimed -> resolved` transition becomes callable only in Phase 5 after the transactional fence exists. `resolved` and `cancelled` remain terminal. Reopen/new generation stays disabled pending owner policy. Reauthorize actor, case, and account on every action.
- **Database constraints/indexes:** Enforce the state enum/check, one active case per conversation, generation uniqueness, assignment references, closure epoch uniqueness, and monotonic case/event versions. Use the queue/assignment indexes from 1.1. Schema may represent closure and terminal states, but Phase 1 exposes no action that finalizes resolution.
- **Caching/TTL/invalidation:** No lifecycle cache. Emit no PubSub before commit; Phase 6 may subscribe to post-commit versioned events.
- **Required tests:** Every Phase 1-supported transition and prohibited transition; terminal-state enforcement; assignment release; customer cancellation; administrative close denied while actor authority is unverified and allowed only for the already-approved actor; no callable action or generic update can resolve a claimed case; two concurrent claim/release actions.
- **STOP:** `STOP=PHASE1_AUTHORIZATION_BYPASS` if any resolution path is callable before Phase 5 or administrative close is allowed without verified existing actor authority. Missing admin actor mapping disables only administrative close and does not block unrelated domain/constraint work.

### Phase 2 — Durable inbound receipt and bot routing

#### 2.1 Make support intake atomic with the existing WhatsApp checkpoint

- **Outcome:** Every accepted support-routed WhatsApp message has an account-scoped, WAMID-unique PostgreSQL ingress receipt. Receipt, Sales checkpoint, applicable support writes, and required ID-only Oban job commit together before webhook acknowledgement. HELP selection records intake state only and creates no case or support message.
- **Files:** modify `lib/fastcheck/messaging/whatsapp/inbound_checkpoint.ex`, `lib/fastcheck/messaging/whatsapp/webhook_scope.ex`, and `lib/fastcheck_web/controllers/webhooks/whatsapp_controller.ex`; create `lib/fastcheck/messaging/whatsapp/inbound_receipt.ex`, `priv/repo/migrations/<next_timestamp>_create_whatsapp_inbound_receipts.exs`, `lib/fastcheck/messaging/whatsapp/support_intake.ex`, and `lib/fastcheck/workers/support_inbound_worker.ex`; create `test/fastcheck/messaging/whatsapp/inbound_receipt_test.exs`, `test/fastcheck/messaging/whatsapp/support_intake_test.exs`, `test/fastcheck/workers/support_inbound_worker_test.exs`, and `test/fastcheck_web/controllers/webhooks/whatsapp_support_intake_test.exs`.
- **Dependencies:** Phase 1; existing webhook verification, `Sales.Conversation`, Repo, and Oban.
- **Minimum approach/actions and guards:** Reuse check: no current record is suitable. `Sales.Conversation.last_inbound_message_id` is one mutable checkpoint value with no account+WAMID unique constraint. `Sales.PaymentEvent` is payment-webhook storage with provider-event identity and an unencrypted raw-payload field; delivery-attempt/status rows record outbound sends and callbacks. Add one transport-owned `FastCheck.Messaging.WhatsApp.InboundReceipt` record/table, not another support aggregate. It stores an internal receipt ID, verified `provider_account_key`, `provider_message_id` (WAMID), `sales_conversation_id`, a per-conversation `ingress_sequence`, `received_at`, and an opaque command payload encrypted through `FastCheck.Crypto` or a durable reference to encrypted content. Do not store raw webhook JSON or plaintext message content. A body-free `0` control receipt stores only its control type. Enforce `NOT NULL` on account, WAMID, conversation, sequence, and required encrypted content/reference; add unique `(provider_account_key, provider_message_id)` and `(sales_conversation_id, ingress_sequence)` constraints. Keep the adopted account+WAMID uniqueness and non-null rules on resulting `SupportMessage` and active-case `SupportCaseEvent` rows as well. Derive account scope from verified channel configuration, never request fields.

  In one `Repo.transaction`, acquire the adopted lock order: per-`wa_id` advisory transaction lock, `Sales.Conversation`, `SupportCase`, `ConversationClosure`, then receipt/message/event/audit/job rows. Look up the receipt by account+WAMID before mutating state. An existing receipt returns its prior result without allocating another sequence or repeating effects. For a new WAMID, derive the next `ingress_sequence` from that conversation's receipts while its row lock is held, then insert the receipt with the account+WAMID unique constraint as the final duplicate guard. Apply checkpoint and support changes and insert the required Oban job only if this transaction inserted the receipt. A uniqueness conflict loads the existing receipt and causes no state, sequence, or job change. The receipt's immutable sequence commits with the related state. The first nonblank description must have its waiting case and encrypted message committed before the webhook receives success. Oban args contain only the internal receipt ID; the worker loads the durable record and decrypts its payload when needed. It does not create the initial case/message after acknowledgement. Commit before returning success. Redis/session state is updated after commit and cannot bypass the PostgreSQL receipt lookup or suppress creation of a missing receipt. The persisted ingress sequence defines order; provider timestamps and worker completion order do not.
- **Database constraints/indexes:** Add unique `(provider_account_key, provider_message_id)` and `(sales_conversation_id, ingress_sequence)` constraints to `whatsapp_inbound_receipts`; index the receipt ID lookup and any bounded pending-job recovery query. Preserve Phase 1 non-null account/WAMID constraints and uniqueness on `SupportMessage` and the body-free active-case `0` event. Keep bounded active-case lookup by `(conversation_id, state)`; add no PII index.
- **Caching/TTL/invalidation:** PostgreSQL is the receipt authority. Redis may cache a duplicate result only after the matching PostgreSQL receipt is confirmed. A Redis claim with no row must continue through the PostgreSQL transaction; a cache hit must never acknowledge an unreceipted WAMID. Update or invalidate session/cache state after commit. Post-commit PubSub may carry internal receipt/case IDs and version only.
- **Required tests:** HELP-selection receipt commits checkpoint and required job without a case or support message; the first description receipt commits with exactly one waiting case and encrypted first message before acknowledgement; receipt/job/case/message/checkpoint rollback together on any insertion failure; Oban args contain only the receipt ID and the worker reads payload from the receipt; duplicate account+WAMID after Redis loss or a lost webhook response returns the original result without another sequence, case/message, or job; Redis outage does not block the PostgreSQL receipt path; the same WAMID under a different verified account remains separately scoped; Redis claiming a WAMID when PostgreSQL has no receipt does not hide processing; same-`wa_id` requests serialize; unique sequence and lock order hold; no plaintext body or credential enters jobs, logs, or PubSub; existing Sales checkpoint tests continue to pass.
- **STOP:** `STOP=INGRESS_RECEIPT_NOT_DURABLE` if no account+WAMID-unique PostgreSQL receipt with encrypted content/reference can be written atomically with the checkpoint, applicable support writes, and required ID-only job before acknowledgement, or Redis can discard an event without that receipt. `STOP=INBOUND_IDENTITY_OR_CONSENT_UNVERIFIED` if verified provider scope is absent or STOP/privacy is bypassed.

#### 2.2 Collect the support description before creating a case

- **Outcome:** HELP sets a durable `collecting_support_description` checkpoint without creating a `SupportCase`; the first nonblank description creates the waiting case and encrypted first message atomically. Once a case exists, later messages remain in support, and `0` from the pre-case checkpoint safely returns to the main menu.
- **Files:** modify `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex`, `lib/fastcheck/messaging/whatsapp/copy.ex`, `lib/fastcheck/messaging/whatsapp/menu_renderer.ex`, `lib/fastcheck/messaging/whatsapp/inbound_receipt.ex`, and `lib/fastcheck/workers/support_inbound_worker.ex`; create `test/fastcheck/messaging/whatsapp/support_routing_test.exs`; extend `test/fastcheck/messaging/whatsapp/conversation_state_machine_test.exs` and `test/fastcheck/messaging/whatsapp/support_intake_test.exs`.
- **Dependencies:** 2.1 receipt uniqueness, encrypted payload storage, shared transaction/lock, and ID-only job; October customer journey authority; confirmed STOP precedence.
- **Minimum approach/actions and guards:** On HELP selection, insert the WAMID-unique `InboundReceipt`, persist `collecting_support_description` in the existing `Sales.Conversation` state, and enqueue the receipt-ID-only job in one transaction; create no `SupportCase` or `SupportMessage`. On the first nonblank description while collecting, synchronously handle the receipt under the shared lock, create `SupportCase(state=waiting)` and its encrypted first `SupportMessage`, update the support-routing state (`needs_human` and support-specific reason), and insert the required receipt-ID-only job in the same transaction. Acknowledge the webhook only after that transaction commits. A duplicate WAMID, including replay after a lost webhook response, returns the existing receipt without repeating state changes, assigning another sequence, creating another job, or creating another case/message. Additional distinct messages serialize on the per-`wa_id` advisory lock and receive the next `ingress_sequence`; the persisted sequence defines order. If HELP is ordered first, the next nonblank text enters description collection. If text is ordered first, process it under the existing main-menu rules; it cannot become a support description retroactively, and the later HELP selection begins collection. Once collecting, the first accepted nonblank description opens the case and later messages append to that active case. Do not reorder by provider timestamp or worker completion. If `0` wins the lock while collecting, record its body-free receipt, clear the pre-case checkpoint, and follow the approved main-menu path; a later description must not create a case from the cleared state. If the description wins first, commit the case/message before its acknowledgement, then process `0` as the next sequence, cancel the case under the approved transition, and write the body-free `SupportCaseEvent` with the same account+WAMID identity. In either order, each acknowledgement follows its own committed transaction and a replay has no duplicate effects. Existing STOP/privacy actions take precedence; when their authoritative state is unavailable, record inbound receipt as allowed but disable sends. Reopen/new generation remains disabled until the owner policy is approved.
- **Database constraints/indexes:** Enforce receipt uniqueness by account+WAMID and conversation+ingress sequence, plus the adopted unique inbound identity on `SupportMessage` and body-free active-case `SupportCaseEvent`. Keep one active case per conversation and one generation identity; use bounded lookup by active conversation state. Keep transcript ordering in `SupportMessage.sequence`.
- **Caching/TTL/invalidation:** No routing decision from cache. Invalidate any existing conversation summary after transaction commit; do not cache message content.
- **Required tests:** HELP -> unique receipt and `collecting_support_description`, with no case/message; blank description creates no case; first nonblank description creates exactly one waiting case and encrypted first message before acknowledgement; a lost-response replay returns the existing receipt and creates no duplicate case/message/job; concurrent HELP selection and text follow their allocated sequence, so only text ordered after HELP starts description collection; two distinct descriptions racing during intake receive consecutive sequences, create one case, and append messages according to that sequence; `0` racing with the first description is tested in both orders, where `0` first clears intake and prevents case creation, while description first creates the case/message and the subsequent `0` cancels it; duplicate `0` is idempotent; Redis cannot suppress a PostgreSQL-missing receipt; worker args contain only receipt ID; `0` from waiting/claimed uses the adopted body-free exit event; support-mode bot suppression; STOP precedence; no Sales order/ticket side effects; no terminal-case resurrection.
- **STOP:** `STOP=INGRESS_RECEIPT_NOT_DURABLE` if duplicate replay, ordering, content recovery, or the required job depends on Redis or an uncommitted/missing PostgreSQL receipt. `STOP=HELP_INTAKE_SEQUENCE_INVALID` if HELP selection creates a case or a first nonblank description is acknowledged before its case/message commit, or a cleared pre-case `0` flow creates a phantom case. `STOP=INBOUND_IDENTITY_OR_CONSENT_UNVERIFIED` if routing bypasses STOP/privacy or reopens a terminal case without owner policy. Missing send consent blocks outbound behavior, not independent receipt/read tests.

### Phase 3 — Idempotent reply acceptance

#### 3.1 Persist the authorized reply and dispatch intent atomically

- **Outcome:** An accepted operator reply and its recoverable dispatch intent are committed atomically to the encrypted transcript, operation ledger, audit sequence, and ID-only Oban job. Dispatch remains disabled until Phase 4 and separate authorization.
- **Files:** create `lib/fastcheck/support/reply_acceptance.ex` and `lib/fastcheck/workers/support_message_dispatch_worker.ex`; modify `lib/fastcheck/support/support_message.ex`, `lib/fastcheck/support/external_create_operation.ex`, `lib/fastcheck/support/support_case.ex`, and `config/config.exs`; create `test/fastcheck/support/reply_acceptance_test.exs`, `test/fastcheck/support/reply_acceptance_concurrency_test.exs`, and `test/fastcheck/workers/support_message_dispatch_worker_test.exs`.
- **Dependencies:** Phases 1–2; `FastCheck.Crypto`; existing `GlobalAccess` actor context. The support dispatch queue stays disabled/not started in this phase.
- **Minimum approach/actions and guards:** Accept only an authenticated, currently authorized actor scoped to an active claimed case. Require a non-null client submission ID, verified provider-account scope, allowed text-only payload, current consent/STOP clearance, and no closure fence. In one database transaction under the shared lock order, authorize and compare any existing replay before lookup disclosure; for a new accepted submission, allocate the next transcript sequence and UUIDv7 operation ID, encrypt/persist the message, append the audit event/version, persist the operation as the durable outbox intent, and insert an Oban job with the internal operation ID only. Commit all of these together before reporting acceptance. Exact authorized replay returns status only; conflict or denial creates no new message, operation, or job. The Phase 3 worker/queue is default-deny and cannot call the provider client; the dedicated queue is not activated. Phase 4 may enable processing only behind its separate authorization and consent gates. No Meta request is issued in the LiveView or acceptance action.
- **Database constraints/indexes:** Unique `(provider_account_key, client_submission_id)`; unique `(support_case_id, sequence)`; unique `operation_id`; unique logical operation for message/provider/kind; unique/validated outbox-job linkage to the operation; required actor/account/case references. Use `lock_version` and row-level serialization for concurrent replies.
- **Caching/TTL/invalidation:** No cache for authorization, replay, or accepted state. After commit, publish case ID, message ID, and version only. Avoid message body in PubSub and caches.
- **Required tests:** New acceptance leaves one encrypted message, operation/outbox intent, audit event, sequence/version update, and ID-only Oban job in the same commit; failure inserting any required row/job rolls back all of them; accepted acknowledgement follows commit; same-key exact replay returns status only with no second job; conflicting replay, revoked actor, unclaimed/fenced case, or STOP clearance failure creates nothing; two concurrent replies serialize; queue remains inactive and the provider client is never invoked in Phase 3.
- **STOP:** `STOP=REPLY_ACCEPTANCE_NOT_DURABLE` if the message, operation, audit, sequence/version, or job can commit separately, or acceptance can be acknowledged without committed dispatch intent. `STOP=SUBMISSION_IDENTITY_UNSAFE` if exact authorized replay cannot be proven. Dispatch remains disabled regardless of these test results.

### Phase 4 — Safe Meta dispatch and outcome tracking

#### 4.1 Gate and dispatch durable operations through the existing provider client

- **Outcome:** The Phase 3 worker processes a committed operation only after a separate dispatch authorization and all owner policy gates pass; it records dispatch authorization before HTTP, calls the existing WhatsApp client outside the transaction, and persists an explicit outcome. Until then, its queue remains disabled and the worker is default-deny, with no provider invocation.
- **Files:** modify `lib/fastcheck/workers/support_message_dispatch_worker.ex` created in Phase 3; create `lib/fastcheck/messaging/whatsapp/support_dispatch.ex`; modify `lib/fastcheck/messaging/whatsapp/client.ex` only to reuse/test an existing injectable boundary if required; add operation actions in `lib/fastcheck/support/external_create_operation.ex`; create `test/fastcheck/workers/support_message_dispatch_worker_test.exs` and `test/fastcheck/messaging/whatsapp/support_dispatch_test.exs`.
- **Dependencies:** Phase 3; existing `Client`, `OutboundDeliveryPolicy`, provider status modules, confirmed consent source, and separate owner authorization before enabling the queue or provider transport.
- **Minimum approach/actions and guards:** Oban args contain only internal operation ID. Until Phase 4 authorization is recorded, keep the queue disabled and the worker default-deny; verify that processing a job cannot invoke the provider. Once separately authorized, the worker reloads and locks durable state, rechecks case, consent/STOP, account, and operation status, then commits a one-way dispatch authorization marker. It performs no HTTP while a DB transaction is open. A successful provider response records provider message ID and `provider_accepted`; a later delivery receipt updates the separate message/event delivery fact. A definitive pre-acceptance rejection may become `failed_retryable` or `failed_permanent` only when the existing provider contract proves the classification. Any timeout, connection loss after request dispatch, malformed response, or crash after authorization becomes `outcome_unknown`/`needs_review`; never retry automatically without authoritative reconciliation evidence. Duplicate Oban execution observes durable state and does not send twice.
- **Database constraints/indexes:** Unique operation ID and one dispatch operation per logical accepted reply; state/version compare-and-swap; partial index for due operations in `queued` or `failed_retryable`; provider WAMID unique within verified account scope. `outcome_unknown`, `reconciling`, and `needs_review` are never eligible for automatic retry.
- **Caching/TTL/invalidation:** No cache authorizes a send. Redis outages do not change durable dispatch decisions. Post-commit PubSub emits IDs/version/status only.
- **Required tests:** Before separate authorization, the queue is disabled and executing a job is denied without provider invocation. After authorization in a separately approved slice, test fake-provider success, definitive rejection, timeout before/after dispatch boundary, worker crash at each state boundary, duplicate Oban execution, STOP changed before worker execution, customer exit suppressing queued work, and that no HTTP happens inside the DB transaction.
- **STOP:** `STOP=DISPATCH_NOT_AUTHORIZED` if queue processing or provider invocation is possible before separate authorization. `STOP=UNKNOWN_SEND_POLICY_UNRESOLVED` if, after authorization, unknown operations can be retried, hidden, mislabeled as undelivered, or allowed to bypass the consent source. Tests use injected fakes; no real send is authorized.

#### 4.2 Add only evidence-backed provider reconciliation

- **Outcome:** The system can reconcile an unknown operation only through a verified provider query/correlation mechanism; otherwise it remains quarantined and blocks final resolution where required.
- **Files:** if the provider contract supports it, create `lib/fastcheck/messaging/whatsapp/support_operation_reconciler.ex` and `lib/fastcheck/workers/support_operation_reconciliation_worker.ex`; modify `lib/fastcheck/messaging/whatsapp/provider_status.ex` or `lib/fastcheck/messaging/whatsapp/delivery_status_reconciler.ex` only for verified events; create `test/fastcheck/messaging/whatsapp/support_operation_reconciler_test.exs`. If no such provider API exists, no new module is created and the operation remains `needs_review`.
- **Dependencies:** 4.1; exact official Meta contract and owner disposition for unknown sends.
- **Minimum approach/actions and guards:** Reconciliation is read-only unless a verified response proves a prior send's identity/outcome. Do not match by message text, timestamp proximity, local UUID, or delivery receipt alone. Record evidence source and time without secrets or body duplication. Manual review may annotate evidence but cannot relabel an unknown as absent without an authoritative basis.
- **Database constraints/indexes:** Store provider correlation IDs as unique scoped identities when supplied; index `(state, updated_at, id)` for bounded review queues. Preserve append-only operation/audit evidence.
- **Caching/TTL/invalidation:** No cache changes operation state. Provider query results are persisted before any UI notification.
- **Required tests:** Exact provider correlation maps to one operation; absent/ambiguous result remains unknown; duplicate/out-of-order status events are idempotent; no content/timestamp heuristic resolves uncertainty.
- **STOP:** `STOP=UNKNOWN_SEND_POLICY_UNRESOLVED` if no authoritative provider reconciliation exists. The safe implementation result is indefinite review and no blind retry; do not claim eventual recovery.

### Phase 5 — Transactional closure and customer exit

#### 5.1 Implement the durable close fence

- **Outcome:** A case cannot become resolved while pre-fence accepted messages or dispatches lack the owner-approved disposition; later replies cannot cross the fence silently.
- **Files:** add guarded actions in `lib/fastcheck/support/support_case.ex` and `lib/fastcheck/support/conversation_closure.ex`; create `lib/fastcheck/support/closure.ex`; modify `lib/fastcheck/support/reply_acceptance.ex` and `lib/fastcheck/messaging/whatsapp/support_intake.ex` only where needed to share the lock/sequence fence; create `test/fastcheck/support/closure_fence_test.exs` and `test/fastcheck/support/closure_fence_concurrency_test.exs`.
- **Dependencies:** Phases 2–4; owner policy for provider accepted versus delivered; exact admin-close actor authority.
- **Minimum approach/actions and guards:** Under the shared lock order, record the closure request and current case version, then commit the next closure epoch as `fenced` with its sequence boundary; that commit is the close barrier and the displayed closing state is derived from the durable closure row. Advance through `reconciling` while every pre-fence message and operation is accounted for. Finalize to `resolved` only after the current assignee confirms against the current case version and the owner-approved disposition guard holds. A late inbound receipt before finalization aborts that closure attempt and keeps the case open; delayed PubSub never decides completion. Unknown provider outcomes move closure to `recovery_required`; after authoritative evidence, reconciliation may resume. A customer `0` exit aborts the active closure and cancels the case while preserving unknown operations. `resolved` and `aborted` closure attempts are immutable; `resolved` and `cancelled` cases remain terminal. Any future reopen creates a new case generation and requires owner policy.
- **Database constraints/indexes:** Unique `(support_case_id, closure_epoch)`; one active closure per case; monotonic message/event sequence and `lock_version`; index pending operations by `(support_case_id, state)` and closure review by `(state, updated_at, id)`.
- **Caching/TTL/invalidation:** No snapshot cache can prove closure. After commit, invalidate queue/case summaries and publish case ID/version only.
- **Required tests:** Reply racing close in both commit orders; duplicate close request; accepted-before-fence message blocks until disposition; inbound-before-finalize forces recheck; delayed/reordered PubSub ignored for authority; process restart resumes from durable closure state; terminal cases cannot be mutated.
- **STOP:** `STOP=CLOSE_OR_EXIT_POLICY_UNRESOLVED` if the closure oracle assumes undocumented provider delivery or a role not authorized by the October policy.

#### 5.2 Preserve customer `0`, STOP, and in-flight-send truth

- **Outcome:** A customer can leave support regardless of an unknown send, while already-authorized sends remain accurately represented and privacy controls remain dominant.
- **Files:** modify `lib/fastcheck/support/support_case.ex`, `lib/fastcheck/support/support_case_event.ex`, `lib/fastcheck/support/support_message.ex`, `lib/fastcheck/support/external_create_operation.ex`, `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex`, and `lib/fastcheck/messaging/whatsapp/copy.ex`; create `test/fastcheck/support/customer_exit_test.exs` and `test/fastcheck/support/privacy_precedence_test.exs`.
- **Dependencies:** 2.2 and 4.1; adopted October exit/privacy requirements; owner decision on in-flight customer notice.
- **Minimum approach/actions and guards:** In the `0` transaction, record a body-free provider receipt with non-null account/WAMID, cancel the case under the approved transition, suppress queued operations that have not crossed dispatch authorization, and mark safe retry work suppressed. Do not relabel dispatching/unknown operations as cancelled, undelivered, or recalled. STOP/privacy suppression always takes precedence and prevents new sends. The initial customer notice must not promise that an already-dispatching message was recalled; any additional notice copy requires owner approval.
- **Database constraints/indexes:** Unique provider receipt key for the `0` event; operation state transition constraints that distinguish queued/suppressed from dispatching/unknown; index by `(support_case_id, state)` for suppression.
- **Caching/TTL/invalidation:** No cached consent/exit decision. Invalidate any support queue summary after commit. No message body in cache.
- **Required tests:** `0` while waiting, claimed, queued, dispatching, and unknown; duplicate `0`; STOP plus queued work; no send after exit for pre-dispatch work; dispatching outcome remains unknown; no order/ticket side effects; no unauthorized customer promise.
- **STOP:** `STOP=CLOSE_OR_EXIT_POLICY_UNRESOLVED` if exit is blocked by unknown Meta state or the UI/copy claims cancellation of a send that may still arrive.

### Phase 6 — Minimal Phoenix LiveView workspace

#### 6.1 Add an authenticated queue and canonical case timeline

- **Outcome:** Approved operators can see waiting/claimed cases and bounded encrypted transcript pages through FastCheck's existing browser authentication.
- **Files:** modify `lib/fastcheck_web/router.ex`; create `lib/fastcheck_web/live/support/support_queue_live.ex` and `lib/fastcheck_web/live/support/support_case_live.ex`; add HEEx templates only if repository convention separates them; create `test/fastcheck_web/live/support/support_queue_live_test.exs` and `test/fastcheck_web/live/support/support_case_live_test.exs`; use existing `lib/fastcheck_web/components/` and `assets/css/app.css` conventions.
- **Dependencies:** Phases 1–5; existing router pipeline `[:browser, :dashboard_auth, :global_ops_auth]`; LiveView `1.1.33`; stable operator identity policy for production multi-agent use.
- **Minimum approach/actions and guards:** Routes `/dashboard/support` and `/dashboard/support/:support_case_id` use the existing auth pipeline. Queue queries are bounded and indexed. Timeline uses keyset pagination by `(support_case_id, sequence)` with a page cap of 50; decrypt only authorized visible messages for rendering. Claim/release and resolve buttons call Ash actions, never direct Repo writes. Recheck policies on every event; a mounted LiveView is not a long-lived authorization grant. Show send status, unknown/recovery warnings, and terminal state plainly.
- **Database constraints/indexes:** Read paths use Phase 1 queue, assignment, and transcript indexes. No UI writes bypass action constraints.
- **Caching/TTL/invalidation:** Start with direct bounded Postgres reads. PubSub after commit carries internal case/message IDs and version only. If measurement later justifies cache, allow non-sensitive queue summaries only, Redis TTL 30 seconds–5 minutes or ETS seconds-to-minutes, explicit invalidation on assignment/state/message/operation/closure changes; never cache bodies or authorization decisions.
- **Required tests:** Unauthenticated and non-allowlisted access denied; cross-case/account access denied; queue/timeline pagination is stable; body decryption only after authorization; controls reflect server state; stale LiveView event cannot bypass updated policy; no polling loop required; keyboard/focus and responsive checks follow existing design conventions.
- **STOP:** `STOP=UI_AUTHORIZATION_OR_POLICY_BYPASS` on any route/auth gap, direct DB write, stale authorization acceptance, or tenant/case leak.

#### 6.2 Add text-only reply composition and recovery controls

- **Outcome:** The workspace submits a durable reply using the idempotent acceptance action and displays its actual operation outcome without sending from the UI.
- **Files:** extend `lib/fastcheck_web/live/support/support_case_live.ex`; reuse existing form/button/alert components; create `test/fastcheck_web/live/support/support_reply_live_test.exs`.
- **Dependencies:** Phases 3–5; Phase 6.1; named operator identity policy before live multi-agent operation.
- **Minimum approach/actions and guards:** Text-only composer sends a generated non-null client submission identity with the action. The LiveView displays accepted, queued, dispatching, provider-accepted, delivered, failed, unknown, and needs-review as distinct states. Retry controls are available only for a durable operation classified definitively safe-to-retry. Resolution is disabled while required pre-fence operations remain unresolved. UI never writes to Meta or changes durable state outside Ash actions.
- **Database constraints/indexes:** No additional constraints; reuse submission/operation and closure constraints. Any optimistic UI state is discarded on server rejection and reloaded from Postgres.
- **Caching/TTL/invalidation:** PubSub status events are hints; reload durable state. No body or credentials in events/cache.
- **Required tests:** Submission replay/conflict through LiveView; stale claim; unknown send cannot show retry; delivery receipt does not imply business resolution; rejection and recovery indicators match durable state.
- **STOP:** `STOP=UI_AUTHORIZATION_OR_POLICY_BYPASS` if a UI retry or close control can override the server's durable decision.

### Phase 7 — Integration, concurrency, and security tests

#### 7.1 Verify end-to-end invariants with synthetic provider boundaries

- **Outcome:** A bounded test suite proves cross-phase identity, transaction, authorization, exit, dispatch, and close behavior without contacting Meta or production systems.
- **Files:** create `test/fastcheck/support/support_end_to_end_test.exs`, `test/fastcheck/support/support_failure_recovery_test.exs`, `test/fastcheck/workers/support_worker_recovery_test.exs`, and `test/fastcheck_web/live/support/support_security_test.exs`; extend `test/fastcheck_web/controllers/webhooks/whatsapp_support_intake_test.exs`; add a focused helper in `test/support/` only if existing fixtures cannot express synthetic account scope.
- **Dependencies:** Phases 1–6; existing Req request injection/fakes; TEST database only.
- **Minimum approach/actions and guards:** Exercise real Ash actions and Postgres constraints with a fake provider transport. Use two DB connections/processes for races; do not replace durable checks with mocks. Cover worker restarts and duplicate job execution. Ensure the test account/fixtures are synthetic, and no test can use production Meta configuration.
- **Database constraints/indexes:** Assert actual DB constraints, not only changeset validation. Verify query plans for required bounded index paths as part of qualification, not correctness authority.
- **Caching/TTL/invalidation:** Test cache/Redis unavailable, stale summaries, and PubSub reordering; all outcomes must reload from Postgres. No cache can make a send or close decision.
- **Required tests:** Inbound duplicate receipt; cross-account identity rejection; exact/conflicting submission replay; worker crash before/after dispatch authorization; unknown Meta outcome never retries; customer `0` during unknown outcome; STOP precedence; concurrent replies and close; terminal case behavior; two-node-equivalent job duplication; no PII/secrets in logs, job args, or PubSub.
- **STOP:** `STOP=INVARIANT_TEST_FAILED` on any lost accepted reply, duplicate logical operation, blind unknown retry, early acknowledgement, privacy regression, or closure bypass.

### Phase 8 — Performance and release qualification

#### 8.1 Measure bounded paths and approve operational targets

- **Outcome:** An evidence-backed release decision documents actual supported workload, recovery expectations, retention/security controls, and failure behavior; it makes no unsupported 100k-user claim.
- **Files:** create `test/fastcheck/support/support_performance_test.exs`; add sanitized operational documentation only after owner policy approval. No schema or cache changes without measurements and a separate review.
- **Dependencies:** Phases 1–7; approved workload, latency, failover, recovery, encryption/retention, backup, and deployment policies.
- **Minimum approach/actions and guards:** Measure queue pagination, transcript keyset reads, message acceptance transaction, webhook receipt, close fence, Oban dispatch/recovery, and Postgres failover behavior under an explicitly approved synthetic workload. Report concurrency and dataset limits, hardware/database configuration, p95/p99, error rates, queue lag, and recovery. Start without Redis/ETS caches; add only a measured non-sensitive read cache with explicit TTL/invalidation. PgBouncer pool behavior and connection budget must be measured before rollout. Keep Postgres authoritative during Redis outages and database failover.
- **Database constraints/indexes:** Verify the Phase 1–5 indexes against query plans and realistic distributions. Add no speculative indexes. Confirm transaction/lock duration and bounded keyset pagination.
- **Caching/TTL/invalidation:** Default no support-content cache. Candidate summary cache TTL is 30 seconds–5 minutes in Redis or seconds-to-minutes in ETS only if benchmarked; invalidate after committed case, assignment, message, operation, and closure changes. Prevent stampedes with coalesced reads or short negative caching only for non-sensitive summaries; caches remain rebuildable and non-authoritative.
- **Required tests:** Load/soak tests at approved targets; worker/node crash recovery; duplicate jobs; Redis outage; Postgres failover; network partition; large transcript pagination; tenant/account isolation at scale; key rotation/retention/deletion qualification. Record 100k concurrent-user target as unverified until a measured result supports it.
- **STOP:** `STOP=RELEASE_TARGETS_UNAPPROVED_OR_UNMET` until owner-approved targets and security/retention decisions are evidenced and met. No release or production send is authorized by passing this phase.

## 5. Minimum first PR and later PR boundaries

### PR 1 — Support domain and integrity foundation

This is the smallest independently reviewable first slice. It includes Phase 1 only:

- Register `FastCheck.Support` and the five canonical resources.
- Add the initial migration with strict required identities, relationships, unique constraints, case/message sequencing, closure epoch, audit sequencing, and bounded queue/transcript indexes.
- Implement Ash actions and policies for the adopted Phase 1 lifecycle, assignment-on-case, terminal states, and the authorized `claimed -> waiting` release. Do not add any callable resolution request/finalization action, a `claimed -> resolved` action, or generic status update that can resolve a case; Phase 5 adds resolution only with the complete transactional close fence.
- Establish all strict identity columns and database uniqueness in the first slice; implement the exact matching-replay behavior in Phase 3.
- Preserve `waiting -> cancelled` administrative close only under the exact pre-existing October actor policy. If that policy cannot be identified, stop that action and request an owner decision; do not introduce a role.
- Add focused unit and PostgreSQL concurrency/constraint tests for lifecycle, authorization, non-null identities, uniqueness, and sequence/version guards. Assert no callable path can resolve a case in Phase 1, and administrative close is denied unless its exact existing actor authority is verified. Unrelated Phase 1 work remains available when that authority is unresolved.

It excludes inbound webhook routing, Oban workers, outbound HTTP, Meta calls, LiveView, Redis caching, Chatwoot, and production transcript data. No real customer messages are used. This PR is not authorized until a separate implementation-plan approval is recorded.

### Subsequent proposed PRs

| PR | Scope | Must not include |
| --- | --- | --- |
| 2 | Phase 2 atomic inbound receipt, support routing, and customer exit receipt | External sends, Chatwoot, reopen until approved |
| 3 | Phase 3 authorized idempotent reply acceptance, transcript/operation/audit/version transaction, and durable ID-only outbox job; dispatch disabled | Provider HTTP, LiveView, queue activation |
| 4 | Phase 4 default-deny worker and separately gated fake-tested dispatch state machine/reconciliation boundary; enabling processing requires separate authorization | Any blind retry or provider invocation before separate authorization |
| 5 | Phase 5 complete close fence and first callable resolution path, STOP/exit coordination, terminal-state enforcement | Resolution action before full fence; assumed delivery policy or unapproved customer copy |
| 6 | Phase 6 authenticated minimal workspace | Direct Repo writes, Chatwoot, CRM features |
| 7 | Phase 7 cross-phase race/security qualification | Production data or external messaging |
| 8 | Phase 8 workload and release qualification | Deployment or release approval |

Each later PR requires exact-head CI, independent review, current authority/policy check, and post-merge verification under the then-approved project workflow. This plan itself does not request or authorize a PR.

## 6. Owner policy gates and safe defaults

These policies stay open; no row below is approved by the architecture adoption. Resolve each only before the first action that depends on it. Other work and tests can proceed with synthetic data and provider fakes.

| Owner decision | Earliest affected phase | Safe default while undecided |
| --- | --- | --- |
| Exact existing actor authority for administrative `waiting -> cancelled` close | 1 | Do not expose or implement an inferred admin role; other lifecycle actions can be tested. |
| Stable named operator identity and whether current global usernames are shared | 1 for recording actor identity; 6 for production multi-agent workspace | Use synthetic test actors; block production operator replies until identity is attributable to one person. |
| Encryption key lifecycle, transcript retention, deletion, and backup policy | 1 before real support-body persistence; 8 before release | Use encrypted synthetic fixtures only; no production/customer transcript storage. |
| Single WhatsApp account boundary and verified provider-account identity source | 2 before inbound activation | Support only the verified configured account; reject unscoped/multi-account requests. |
| Durable STOP/consent authority and failure behavior | 2 for inbound precedence; 4 before any send | Preserve existing STOP/privacy path; if current consent cannot be established, disable sends. |
| Reopen/new-case generation rules after `resolved` or `cancelled` | 2 before repeated customer entry; 5 before reopen control | Keep terminal cases terminal; do not reopen or create a new generation through an inferred rule. |
| Meta ambiguous-send disposition and authoritative reconciliation/correlation | 4 | Unknown remains `needs_review`; no automatic retry or non-delivery claim. If no authoritative reconciliation exists, eventual resolution is not guaranteed. |
| Whether provider acceptance or customer delivery is required before business resolution | 5 | Require known provider-operation disposition; keep delivery state separate and do not claim delivery. |
| Customer notice for a send already dispatching when `0` or STOP arrives | 5 | Preserve existing approved customer copy; never promise recall or non-delivery. |
| Workload, latency, failover, recovery, retention, and deployment targets | 8 | No capacity claim or production release. |

## 7. Cross-phase correctness and operational requirements

### Message and operation states

Keep these facts separate: accepted by FastCheck, durably persisted, dispatch queued, dispatch authorized/in progress, provider accepted, provider delivery confirmed, outcome unknown, and failed/needs review. Acceptance commits encrypted transcript, unique submission identity, sequence, operation row, and audit event before dispatch can begin. A local UUID or unique row does not provide exactly-once Meta delivery. Unknown external outcomes are never blindly retried.

### Close and transaction boundary

Inbound receipt and required job insertion commit atomically before webhook acknowledgement. The fixed advisory-lock/row-lock order applies across inbound, reply, exit, and close. Closure records a sequence/epoch fence and evaluates durable pre-fence operations. No external HTTP is inside the transaction; PubSub is emitted only after commit. Reopening, if approved, creates a new case generation and preserves prior audit.

### Performance and scaling

Postgres is the cold authority for all correctness. Oban is durable background execution with ID-only arguments and state rechecks. Phoenix PubSub and LiveView provide after-commit updates without polling. Redis/ETS are optional, rebuildable accelerators. Use indexed bounded queue queries and keyset transcript pagination. Do not place PII or message bodies in logs, job arguments, PubSub, or caches. The architecture has not been benchmarked at 100k concurrent users; all performance targets remain unverified until Phase 8 evidence exists.

### Required acceptance tests across the plan

- Customer/provider identity columns cannot be null on their adopted message/exit paths; same identities cannot create duplicate receipts.
- Support case state transitions, actor guards, terminal states, assignment, and new-generation policy are enforced by Ash and Postgres.
- Existing per-`wa_id` advisory lock and `Sales.Conversation` checkpoint remain compatible; support inbound receipt and job are atomic and acknowledged only after commit.
- Exact authorized operator submission replay is status-only; conflicting or unauthorized replay creates nothing and leaks no prior operation identity.
- Duplicate Oban jobs, worker crashes, and process restarts cannot produce an automatic duplicate send after an unknown outcome.
- Customer `0` exits independently of unknown sends; queued work is suppressed; dispatching work remains accurately unknown; STOP/privacy always wins.
- Close-fence races cannot lose accepted replies; unresolved required operations block resolution; PubSub order and cache snapshots cannot finalize closure.
- LiveView permissions, case/account scoping, and all writes through Ash are verified.
- Redis/cache outages, database failover, and multi-process concurrency preserve PostgreSQL decisions.

## 8. Implementation entry criteria and final release gate

Before the first implementation PR, require a separately recorded owner decision adopting this plan for execution and authorizing the named Phase 1 scope. Before any phase that depends on an open policy, record that policy decision; do not interpret this plan as blanket approval. Before any provider-facing send, obtain separate operational authorization and validate the approved no-send/testing boundary.

Before release consideration, all prior phase acceptance criteria must pass on the exact candidate; independent review and current authority checks must be recorded; security, encryption/retention, consent, ambiguous-outcome, account/operator identity, workload, recovery, and deployment policies must be resolved; and no Gate A result may be rewritten by this plan. Release approval remains a separate owner decision.

**Current decision:** planning artifact only. `IMPLEMENTATION_AUTHORIZATION=NONE`; `PRODUCTION_SEND_AUTHORIZATION=NONE`; `CHATWOOT_GATE_A=UNCHANGED`.
