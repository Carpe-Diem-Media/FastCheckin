# FastCheck-controlled Support Workspace Replacement Design

| Field | Value |
| --- | --- |
| Document ID | `FASTCHECK-SUPPORT-WORKSPACE-REPLACEMENT-001` |
| Date | 2026-11-14 |
| Corrective revision | 2026-11-15, adoption-blocker corrections only |
| Status | `PROPOSED — NOT ADOPTED` |
| Repository | `Carpe-Diem-Media/FastCheckin` (GitHub repository ID `1096911087`) |
| Scope | Replace the proposed writable Chatwoot agent workflow with a FastCheck-controlled support workspace. |

**Implementation authorization:** None. This document does not authorize application, schema, infrastructure, or runtime changes.

## 1. Executive summary and recommended choice

Use Option B: FastCheck owns the support transcript, agent reply actions, delivery ledger, and resolution fence. Agents work in a small authenticated Phoenix LiveView workspace. Chatwoot CE v4.19.1 is not part of the MVP write path and has no agent role in the proposed MVP.

Keep the approved `FastCheck.Support.SupportCase` name and its `waiting`, `claimed`, `resolved`, and `cancelled` states. Do not add a competing `SupportHandoff`, `SupportConversation`, or `BridgeMessage`. Add separate durable records only for message content, external-send outcome, closure epochs, and append-only case audit, each of which has an integrity boundary the case row cannot safely represent by itself.

A Postgres transaction and unique constraints can make FastCheck's acceptance of an agent reply idempotent. They cannot make Meta's external send exactly once. The dispatch worker must not retry an outcome that could have reached Meta. A lost response before the provider ID is persisted has no verified reconciliation key in the current FastCheck integration; that operation remains `outcome_unknown`/`needs_review`, auditable and never automatically retried. It blocks business resolution, but it does not block a customer's October `0` exit or the existing global STOP/privacy behavior. Exit suppresses operations that have not crossed the durable dispatch-authorization point. A `dispatching` operation may still reach Meta and remains unresolved until authoritative evidence exists; neither exit nor STOP relabels it as cancelled or undelivered.

The local transcript and close fence are enforceable if every agent write goes through an authorized Ash action that shares a Postgres serialization point with closure. Provider acceptance, provider delivery to the customer, and business resolution remain separate facts. A closure may record business resolution after every pre-fence send has a known disposition, while clearly showing pending delivery receipts. Requiring a delivered receipt before resolution is an owner decision because receipts may be delayed or absent.

**Decision:** `CONDITIONAL GO` to owner adoption and a separately authorized implementation plan for Option B. `NO-GO` to claim the full external-outcome requirement is satisfied until Meta's ambiguous-send reconciliation contract is verified and tested. If no provider mechanism can establish an unknown outcome, the safe state is indefinite review and no retry; FastCheck alone cannot guarantee eventual resolution of that external uncertainty.

## 2. Authority and source revision table

| Source | Verified revision and status | Authority and use |
| --- | --- | --- |
| [Approved October 15 support design](2026-10-15-whatsapp-customer-service-resend-design.md) | Commit `71da609a08e0298089d9086faa8272358702d0ac`; blob `8a0e7ea8040cb1292fcb0993ae1ec9d881afd79b`; header says `APPROVED`, implementation authorization `GATE 0 ONLY`. | Controlling product/domain authority until an owner adopts a replacement. Defines `SupportCase`, `SupportMessage`, support states, routing, privacy, and the FastCheck operator inbox. This proposal preserves those names and states. |
| [November 10 Chatwoot integration design](2026-11-10-whatsapp-flows-chatwoot-integration-design.md) | Commit `854cd507d920c94d242b081259727c410d2d62d6`; blob `953d9d77eca1afbc6405cd032eac5619dbbf6e29`; version 0.2.3; `Proposed`. | Not adopted. It explicitly leaves the October design authoritative until owner approval. Its Chatwoot ownership and `SupportHandoff` / `BridgeMessage` terms are compared below, not silently carried forward. |
| [October 15 implementation plan](../plans/2026-10-15-whatsapp-customer-service-resend.md) | Last changed by commit `c032b8a12f8a0039ed90388a32dce8ba338e4f49`; blob `2f6146f6e3e1dcb29466778a3c618eb6c460d597`; document text says `APPROVED FOR GATED EXECUTION`, `GATE 0 ONLY`. | This records the plan's text; it does not authorize this replacement or any implementation. Prior Gate 0 closure is not re-audited here. |
| Gate A feasibility runbook | File at `.worktrees/chatwoot-gate-a-preflight/docs/fastcheck_sales/runbooks/WHATSAPP_CHATWOOT_FEASIBILITY.md`; worktree HEAD `b7b1c5532e212e56c0137d86cc9b8cff833a3f50`; current working-tree blob `39f99dbfcf152ea9d8c1a98c9814f8976fca1177`. The file is added in that worktree and is not present in its HEAD or canonical `main`. | Worktree-only feasibility evidence, not an adopted product specification. Its dated §10.13 records `A06=FAIL`, `A07=BLOCKED`, and `A08–A14=NOT RUN`; §10.13 says A01–A05 evidence is unchanged. The supplied Gate A baseline records `A01–A03=PASS (AI-only)`, `A04=PARTIAL`, and `A05=PASS (receiver safeguards only)`. The header still says “Draft preflight” and “Gate A has not been executed”; the newer dated appendix and supplied status baseline are read as later evidence without rewriting that historical header. |
| [Issue #557](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557), comment [6873972083](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6873972083) | Issue is open. Comment is by `JC-Agents`, dated 2026-11-14, and labels itself an AI-authored technical assessment. | Read-only architecture finding, not an owner decision. It recommends no-go for writable Chatwoot v4.19.1 under A06/A07 and conditional use of a FastCheck-controlled workflow. It cites exact pinned-source behavior and prior synthetic evidence. |
| [Issue #557 corrective review comment 6890062289](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6890062289) | Dated 2026-11-15; author `JCSchoeman96`, GitHub association `MEMBER`; the comment labels itself technical findings, not owner adoption or implementation authorization. | Source for the three corrections in this revision: customer exit/privacy versus unknown sends, the InboundCheckpoint/close-fence boundary, and exact authorized submission-key replay. It changes no controlling authority or Gate A result. |
| [Issue #556](https://github.com/Carpe-Diem-Media/FastCheckin/issues/556) | Open; authored by `JCSchoeman96`; no comments. Report covers pinned CE v4.19.1. | Records the API Channel HMAC discrepancy: valid `identifier_hash` returned 200, nonmatching hash returned 500 with no observed mutation; pinned source raises a generic error. This is not an observed auth bypass. It reinforces that Chatwoot API behavior must not be treated as a stable contract, but does not change Gate A results. |
| Chatwoot CE v4.19.1 source | Tag commit `caab07a8f00032d5205b5a5d7e2eb0ba2f3d2d82`. | Source references include [`messages_controller.rb`](https://github.com/chatwoot/chatwoot/blob/caab07a8f00032d5205b5a5d7e2eb0ba2f3d2d82/app/controllers/api/v1/accounts/conversations/messages_controller.rb), [`message_builder.rb`](https://github.com/chatwoot/chatwoot/blob/caab07a8f00032d5205b5a5d7e2eb0ba2f3d2d82/app/builders/messages/message_builder.rb), [`webhook_listener.rb`](https://github.com/chatwoot/chatwoot/blob/caab07a8f00032d5205b5a5d7e2eb0ba2f3d2d82/app/listeners/webhook_listener.rb), [`webhook_job.rb`](https://github.com/chatwoot/chatwoot/blob/caab07a8f00032d5205b5a5d7e2eb0ba2f3d2d82/app/jobs/webhook_job.rb), [`conversations_controller.rb`](https://github.com/chatwoot/chatwoot/blob/caab07a8f00032d5205b5a5d7e2eb0ba2f3d2d82/app/controllers/api/v1/accounts/conversations_controller.rb), and [`message_finder.rb`](https://github.com/chatwoot/chatwoot/blob/caab07a8f00032d5205b5a5d7e2eb0ba2f3d2d82/app/finders/message_finder.rb). A create saves before response; callback delivery is post-commit and asynchronous; `delivery_id` is per delivery, not a stable create key; status writes have no coordinated close fence; pagination exposes ID cursors without a snapshot token or high-water mark. The pinned create/search contract does not establish a request field or lookup that uses a FastCheck-generated operation ID, so body matching or a delivery UUID is not conclusive reconciliation. |
| Current FastCheck repository | `main` at `3893d2afeee0cdbb05dc8c331e18996f4cfa3e98`. | Current code has `FastCheck.Sales.Conversation`, `FastCheck.Sales`, `FastCheck.Messaging.WhatsApp`, `FastCheckWeb.Router`, `BrowserAuth`, and `GlobalOpsAuth`. No `FastCheck.Support` Ash domain or support resources exist in this revision. The proposed modules below are future paths only. |

### Authority conflict to resolve by adoption

The pinned create/search contract does not establish a request field or lookup that uses a FastCheck-generated operation ID. Body matching and the callback `delivery_id` are not conclusive reconciliation methods for a lost Chatwoot create response.

The October authority defines one FastCheck-owned `SupportCase` and encrypted `SupportMessage`. The November proposal instead makes Chatwoot the post-handoff transcript and workspace owner, with a FastCheck `SupportHandoff` routing lease and `BridgeMessage` delivery ledger. These are different ownership models and different resource names, not aliases. This proposal keeps October's `SupportCase` as the single support aggregate. It maps the proposed handoff behavior to the active `SupportCase` plus existing `Sales.Conversation.needs_human` / `handoff_reason`; it replaces `BridgeMessage` with `SupportMessage` plus `ExternalCreateOperation`. Only a separate owner adoption decision can supersede the October design or revise its implementation plan.

## 3. October versus November design comparison

| Concern | October approved design | November proposed design | Replacement proposal |
| --- | --- | --- | --- |
| Support authority | FastCheck `SupportCase` and `SupportMessage`. | Chatwoot owns assignment and transcript after handoff; FastCheck owns `SupportHandoff` and `BridgeMessage`. | FastCheck owns case, transcript, operation ledger, and closure. |
| Names | `waiting`, `claimed`, `resolved`, `cancelled`. | Handoff lifecycle adds routing and recovery phases. | Keep the approved case states. Put temporary close/recovery phases on `ConversationClosure`; do not make `resolved` reversible. |
| Agent replies | FastCheck LiveView, existing Meta client, Oban. | Chatwoot agent creates a message; callback informs FastCheck. | FastCheck LiveView submits a durable reply before a worker contacts Meta. |
| Close behavior | Optimistic concurrency on case resolution. | Chatwoot callback and proposed bridge reconciliation. | Postgres close fence serializes reply acceptance against resolution; Chatwoot does not participate. |
| Message history | Encrypted FastCheck support messages. | Chatwoot transcript with FastCheck delivery ledger. | One canonical encrypted FastCheck transcript; no mirrored transcript in MVP. |
| Retry/idempotency | Duplicate jobs guarded by message/provider state. | Bridge records attempt and provider status. | Unique client submission key, durable operation row, provider status mapping; unknown external outcome is never blindly retried. |
| Authorization | Existing dashboard authentication plus support permission. | Chatwoot account/inbox/agent access plus FastCheck callback scope. | Existing browser auth plus the server-owned global-ops allowlist, rechecked by Ash actions. |
| Vendor dependency | Meta transport and FastCheck support code. | Chatwoot UI, APIs, API Inbox callbacks, Sidekiq and release-specific semantics. | No Chatwoot dependency in MVP. |

The November proposal addressed risks in the original handoff concept, including reply/close races and held-message disposition. The Gate A source review shows that the pinned Chatwoot release still cannot provide the required pre-commit FastCheck guard, stable create identity, or transcript close barrier. Those requirements are retained; the Chatwoot-specific implementation is removed from this proposal.

### 3.1 Option A versus Option B

| Evaluation | Option A: Chatwoot remains the agent UI | Option B: FastCheck-controlled workspace |
| --- | --- | --- |
| A06 create safety | The observed exact repeats created duplicate conversations and messages. A FastCheck ledger cannot make a Chatwoot create idempotent when Chatwoot does not accept and enforce the same operation key. | Unique case/submission/provider keys prevent duplicate FastCheck records for the same logical operation. This does not create exactly-once Meta delivery; unknown provider outcomes stay quarantined. |
| A07 close barrier | Agents can create replies and change status in Chatwoot before asynchronous callbacks. The pinned API has no snapshot token/high-water mark or close fence. FastCheck cannot prevent a commit it does not control. | All agent writes enter Ash actions and share the Postgres conversation lock order and close fence. FastCheck can prove its durably received transcript rows are committed before closure. |
| Integration boundary | Depends on Chatwoot UI/API writes, API Inbox callbacks, Sidekiq delivery, API identities, and reconciliation between systems. | Uses existing `Sales.Conversation`, verified WhatsApp ingress, the Meta client, Postgres, Oban, and the new `FastCheck.Support` domain. |
| Vendor dependency | Safety depends on unverified callback recovery, account/inbox behavior, and release-specific write paths. A local proxy or receiver callback is not a pre-commit guard. | Chatwoot is absent. Meta send/status contracts remain provider dependencies and must be verified separately. |
| Failure modes | A lost callback can leave FastCheck unaware of a saved Chatwoot message; direct resolve can race that callback. | A committed local reply survives worker/node loss. A possibly accepted Meta send becomes unknown and blocks retry/closure until authoritative reconciliation. |
| Concurrency and multiple nodes | Chatwoot and FastCheck have separate databases/queues, with no shared transaction or fence. | Postgres uniqueness and row/version serialization coordinate nodes. Redis/GenServer/PubSub are not correctness locks. |
| Operational complexity | Less FastCheck UI work, but adds Chatwoot operations, callback security, identity mapping, dual transcript repair, and vendor-version maintenance. | Requires a small LiveView workspace, but keeps one transcript and one write authority. No CRM/automation suite is included. |
| Security and account isolation | Chatwoot roles do not prove that every UI/API write is disabled or intercepted. The Gate A release also has a documented HMAC response discrepancy in issue #556. | Existing browser/global-ops checks and Ash policies guard every support action. MVP remains limited to one configured WhatsApp account until durable multi-account identity is approved. |
| Minimum viable slice | Not viable under the pinned release without a source-level vendor change that adds pre-commit authorization, idempotency, and a transcript fence. | SupportCase intake, encrypted transcript, unique reply acceptance, strict send worker, close fence, and the minimal queue/case LiveViews. |

**Assessment:** Option A is `NO-GO` for the required invariants on CE v4.19.1. Option B is the only candidate that can enforce local acceptance and closure. Its external-outcome guarantee remains conditional on a verified Meta reconciliation mechanism; otherwise unknown sends remain blocked for manual review and the full requirement is not met.

## 4. Requirements retained, replaced, deferred, and removed

| Disposition | Requirement or component |
| --- | --- |
| **KEEP** | Existing WhatsApp webhook verification, inbound normalization, bot suppression while support is active, STOP/privacy precedence, Meta transport in FastCheck, approved email-first ticket resend, ticket/order/payment guards, and the October support customer journey. |
| **KEEP** | `FastCheck.Sales.Conversation` as the WhatsApp checkpoint, and `FastCheck.Support.SupportCase` as the human-support aggregate after owner adoption. Keep `waiting`, `claimed`, `resolved`, and `cancelled` semantics. |
| **REPLACE** | Chatwoot API Inbox as writable operator workspace with a FastCheck LiveView workspace. Replace Chatwoot transcript/callback reliance with encrypted `SupportMessage` rows, a durable operation ledger, and a close fence. |
| **REPLACE** | Proposed `SupportHandoff` with `SupportCase` plus the existing `needs_human` and support-specific `handoff_reason` routing flags. Proposed `BridgeMessage` becomes `SupportMessage` plus `ExternalCreateOperation`; these are not one-to-one aliases. |
| **DEFER** | Any Chatwoot mirror. If later reconsidered, it must be genuinely write-disabled for every agent path by a verified role/credential/network control. Calling a mirror “read-only” is not a control. |
| **DEFER** | WhatsApp Flows, attachments, AI support, routing automation, analytics dashboards, cross-event support roles, and multi-account operation. |
| **REMOVE from MVP** | Chatwoot container, API Inbox, Chatwoot agent accounts, callback receiver, Chatwoot identity mapping, API Channel HMAC client, and all required Chatwoot callbacks. No Chatwoot test environment is changed by this proposal. |
| **NOT changed** | Gate A verdicts and Gate A scope. `A01–A03=PASS (AI-only)`, `A04=PARTIAL`, `A05=PASS (receiver safeguards only)`, `A06=FAIL`, `A07=BLOCKED`, and `A08–A14=NOT RUN` remain as previously recorded. Full Gate A is not passed by this architecture proposal. |

## 5. Complete minimum domain resource map

`FastCheck.Sales.Conversation` remains the parent WhatsApp conversation. Its current fields include `phone_e164`, `wa_id`, `state`, sensitive `state_data`, `needs_human`, and `handoff_reason`; it is in `FastCheck.Sales` and has no tenant/account identifier or support transcript. Support content must not be put in `state_data`. Its existing `handoff_conversation` action may continue to set the existing manual-review/routing state as adopted; support messages and closure state remain in `FastCheck.Support`.

The current repository has no support Ash domain. The following `FastCheck.Support` resources are proposed, not present code.

### 5.1 `FastCheck.Support.SupportCase`

- **Owner/source of truth:** Ash resource in `FastCheck.Support`; canonical lifecycle for one support engagement. Parent is `FastCheck.Sales.Conversation`.
- **Relationships and fields:** internal primary key; opaque `public_id`; `conversation_id`; `generation` within the conversation; `state`; bounded `reason_code`; `assigned_operator_id`; `requested_at`, `claimed_at`, `resolved_at`, `cancelled_at`; `next_message_sequence`; `lock_version`; optional current closure pointer or pending-fence marker. Do not copy phone, email, message body, ticket URL, or provider credentials onto the case.
- **States:** `waiting`, `claimed`, `resolved`, `cancelled`. `resolved` and `cancelled` are terminal for that case. “Reopen” creates a new case generation; it never changes a resolved case back to claimed.
- **Actions:** `open_from_customer_message`, `claim`, `release`, `assign` (only if explicitly authorized), `cancel_by_customer_escape`, `request_resolution`, `finalize_resolution`, `open_new_generation`. All mutation actions are transactional Ash actions.
- **Guards/effects:** open is deduped by the durable inbound provider-message key; a partial unique index allows at most one `waiting` or `claimed` case per conversation. Claim is a compare-and-swap on `lock_version`; only one operator wins. Reply requires `claimed`, current assignee, no active close fence, and current send authorization. Customer `0` immediately cancels the case, uses the approved safe main-menu recovery action, and suppresses queued sends; it does not wait for an unknown provider outcome or alter order/payment state. A `dispatching` operation remains auditable and may complete. The global STOP/privacy handler runs before support routing and remains authoritative. Resolution runs the closure protocol in §8. Update `Sales.Conversation.needs_human` and `handoff_reason` only through approved conversation actions and clear them only when no other safety/handoff reason remains.
- **Authorization:** system actor for verified inbound and provider events; authenticated support operator for read/claim/reply/resolve; supervisor-only actions must be a separately approved policy. Default deny. Ash policy is authoritative even when LiveView hides a button.
- **Tenant/account boundary:** derive conversation scope from the verified inbound path and bound `conversation_id`; never accept account, recipient, or conversation ownership from a form. Current Sales resources have no tenant/org field. MVP must be limited to the configured WhatsApp account/number and the existing global-ops authorization boundary. Multi-account support requires an approved durable channel/account mapping before it is enabled.
- **Integrity/indexes/concurrency:** unique `(conversation_id, generation)`; allocate the next generation while locking the parent conversation row; partial unique `(conversation_id)` where state is `waiting` or `claimed`; queue index `(state, requested_at, id)`; assignment index `(assigned_operator_id, state, updated_at, id)`. `lock_version` CAS and the shared conversation lock order in §8 protect claim, reply sequencing, inbound append, exit, dispatch authorization, and closure fencing.
- **Failure/recovery:** unique conflicts return the existing active case when the same inbound event caused the request; unrelated conflicts return the current case, never create a second active case. Stale claims fail closed. Any failed cross-domain transaction rolls back both the case and its `Sales.Conversation` routing update.

### 5.2 `FastCheck.Support.SupportMessage`

- **Owner/source of truth:** encrypted canonical support transcript. One row per accepted customer/operator message; no Chatwoot transcript is authoritative.
- **Relationships and fields:** `support_case_id`; monotonically assigned `sequence`; direction `customer`, `operator`, or bounded `system`; `sender_operator_id` when applicable; `client_submission_id` for operator submissions; `provider_account_key` and `provider_message_id` for inbound WAMID or acknowledged outbound WAMID; ciphertext and encryption/key version; `accepted_at`; separate provider-acceptance and delivery projection fields; bounded failure class. Message plaintext, destination phone, access token, and raw webhook payload are excluded from job arguments and logs.
- **States:** inbound message is durably `received`; outbound acceptance and dispatch/delivery projection are described in §6. A stored message is append-only in body and sequence. Status changes are represented by operation/status events, not destructive edits to transcript content.
- **Actions:** `accept_customer_message`, `accept_operator_reply`, `record_provider_status`, and authorized `read_page`. A message is “accepted by FastCheck” only after the transaction containing its row and required outbox/Oban record commits.
- **Guards/effects:** verified WAMID dedupe for inbound is enforced in Postgres, not only by Redis. The ingress transaction records the encrypted inbound message, its per-case sequence, the Sales checkpoint, and its durable processing job before acknowledging acceptance. An operator action checks current authorization, case assignment, expected case version for a new submission, message type, active closure fence, delivery-window/template policy, and consent/privacy guards before acceptance. A repeated submission key is eligible for replay only after the caller is authorized and the stored actor, operation kind, case scope, and exact immutable payload match; see §7. The recipient is resolved from the parent conversation only. MVP is text-only unless the owner separately adopts attachment handling.
- **Authorization:** system actor creates verified inbound messages and applies signed/verified provider status; an assigned operator may submit a reply; authorized support readers may decrypt. Decryption is limited to case display or the delivery worker.
- **Tenant/account boundary:** every read and write scopes through `support_case_id -> conversation_id` and the configured channel scope. Provider ID uniqueness is account-scoped once account identity is durably represented. Do not permit a caller-supplied tenant to widen reads.
- **Integrity/indexes/concurrency:** unique `(support_case_id, sequence)`; unique `(provider_account_key, client_submission_id)` when non-null so key reuse across cases in the same configured account conflicts; unique `(provider_account_key, provider_message_id)` when non-null; keyset index `(support_case_id, sequence DESC)`. Sequence allocation and case version update occur in the same serialized transaction.
- **Failure/recovery:** failed database commit means no accepted reply and no dispatch. An exact authorized replay returns a status-only receipt for the existing operation. A same-key payload, actor, or operation conflict fails without creating another row, operation, or job. The stored encrypted body is compared in memory after authorization; no plaintext body hash is persisted. A distinct submission ID is a new logical reply even when its text matches.

### 5.3 `FastCheck.Support.ExternalCreateOperation`

- **Owner/source of truth:** durable lifecycle for one logical external WhatsApp send. It is not a Chatwoot create ledger and does not claim exactly-once provider behavior.
- **Relationships and fields:** `operation_id` UUIDv7; `support_case_id`; `support_message_id`; provider/account scope; operation kind; stable source key; state; attempt number; lease/fencing version; dispatch timestamps; provider message ID when known; bounded response/failure class; `next_attempt_at`; `lock_version`. Do not store credentials or plaintext payload here.
- **States:** `queued`, `dispatching`, `provider_accepted`, `failed_retryable`, `failed_permanent`, `suppressed_before_dispatch`, `retry_suppressed`, `outcome_unknown`, `reconciling`, `needs_review`. `provider_accepted` completes the send-acceptance lifecycle; delivery receipts remain a separate projection. `suppressed_before_dispatch` proves that no provider request was authorized or started. `retry_suppressed` records a conclusive prior non-acceptance whose next attempt was suppressed by exit or STOP. Both suppression states are terminal to automation; `needs_review` remains unresolved until an authorized disposition.
- **Actions:** `queue`, `claim_for_dispatch`, `suppress_before_dispatch`, `suppress_retry`, `record_provider_acceptance`, `record_definitive_rejection`, `mark_outcome_unknown`, `reconcile_by_provider_identity`, `mark_needs_review`, `release_known_safe_retry`. Each is guarded by stored operation state and fencing version.
- **Guards/effects:** only the durable worker may dispatch. Under the shared conversation lock, it rechecks case state, STOP/privacy suppression, consent, closure, and message policy before atomically moving `queued` to `dispatching`. That commit is the dispatch-authorization boundary: after it, the request may have started, so customer exit or STOP cannot promise recall. If exit/STOP commits first, queued operations are suppressed and the worker cannot dispatch them. A retry is allowed only when the exact provider response contract proves non-acceptance. Transport timeout, connection loss after dispatch authorization, process crash, malformed response, and database failure after provider success become `outcome_unknown`; they are not auto-retried.
- **Authorization:** system worker may transition queued operations; provider webhook reconciler may attach status only by verified account scope and provider message ID; support operator may view status; only an explicitly authorized recovery action may disposition `needs_review`.
- **Tenant/account boundary:** provider account/phone-number scope is copied from the verified parent conversation configuration, not user input. Until that identity is persisted, run only in the single configured account boundary.
- **Integrity/indexes/concurrency:** unique `operation_id`; unique `(support_message_id, provider, operation_kind)`; due-work index `(state, next_attempt_at, id)` for queued/retryable/reconciling rows; provider message ID unique within account scope. Worker claim uses a Postgres conditional update/lock plus monotonically increasing fencing version. Oban uniqueness is an optimization, not the integrity constraint.
- **Failure/recovery:** a crash before dispatch authorization is safely suppressible or requeued from durable state. Once `dispatching` commits, an expired lease becomes `outcome_unknown`, never another sender. An unknown operation does not prevent customer exit; it remains linked to the cancelled case and blocks business resolution or another support send until an authorized disposition. Manual review cannot invent a provider acknowledgement.

### 5.4 `FastCheck.Support.ConversationClosure`

- **Owner/source of truth:** one durable resolution/fence attempt for a support case generation. `SupportCase.state` remains in the October vocabulary; closure phases do not create new case states.
- **Relationships and fields:** `support_case_id`; `closure_epoch`; `state`; `fence_sequence`; actor and requested/resolved timestamps; bounded recovery reason; case version/fencing token; finalization timestamp. Prior epochs are immutable audit history.
- **States:** `requested`, `fenced`, `reconciling`, `resolved`, `recovery_required`, `aborted`. `resolved` and `aborted` attempts are immutable. A later attempt receives a new epoch.
- **Actions:** `request`, `establish_fence`, `reconcile_pre_fence_operations`, `finalize`, `mark_recovery_required`, `abort_after_safe_recovery`. These actions run in the SupportCase transaction boundary.
- **Guards/effects:** the closure transaction follows the shared lock order in §8, locks/CASes the case, records the highest durably accepted message sequence as `fence_sequence`, and prevents new agent replies. It waits for all pre-fence operations to have known send dispositions. `queued`, `dispatching`, `failed_retryable`, `outcome_unknown`, `reconciling`, `needs_review`, or unreviewed customer messages block business resolution. `suppressed_before_dispatch`, `retry_suppressed`, and a definitive permanent rejection are known non-acceptance states, subject to an operator-visible disposition where required. A customer `0` exit aborts any active resolution attempt and cancels the case without waiting for those operations; the operation audit remains. Provider delivery receipts are displayed separately; owner must decide whether actual `delivered` is required to resolve business work.
- **Authorization:** assigned operator may request resolution; finalization is system-controlled after guards pass. A supervisor recovery action requires explicit policy and audit.
- **Tenant/account boundary:** every closure is reached through its case and conversation scope; no global or caller-selected case IDs bypass Ash policy.
- **Integrity/indexes/concurrency:** unique `(support_case_id, closure_epoch)`; one active closure per case by partial unique index; index `(support_case_id, state)`; all reply, inbound-message, customer-exit, dispatch-authorization, and closure transactions use the same conversation advisory-lock, parent-row, case-row, then closure-row order. A closure cannot commit against a stale case version.
- **Failure/recovery:** if the transaction fails, no fence is visible and no case state changes. After fence commit, worker or node restart resumes from persisted states. A provider ambiguity keeps the closure in `recovery_required`; delayed PubSub cannot finalize or undo closure.

### 5.5 `FastCheck.Support.SupportCaseEvent`

- **Owner/source of truth:** append-only audit events for assignment, state, accepted-message reference, operation outcome, closure, recovery, and reopen decisions. This is justified because current assignment fields retain only the latest owner and the approved generic `FastCheck.Sales.StateTransition` belongs to another domain and has different policy scope.
- **Relationships and fields:** case ID; per-case event sequence; event type; actor type and stable actor ID; referenced message/operation/closure IDs; optional verified provider account/message identity for the `0` support-exit event; case version; timestamp; bounded non-sensitive metadata. No body, phone, credentials, webhook payload, or free-form customer text. Global STOP/privacy records remain owned by the existing global suppression authority.
- **States/actions:** immutable after create; only `record_event` is exposed. Application update/delete actions are absent. Retention/purge is a separate owner-approved policy, not an operator action.
- **Guards/authorization:** events are inserted in the same transaction as the state change they audit. Ash policies allow trusted system or authorized support actions to create only valid event types; reads require support authorization.
- **Tenant/account boundary:** case scope is mandatory and inherited from the parent conversation. Event reads cannot bypass case policy.
- **Integrity/indexes/concurrency:** unique `(support_case_id, sequence)`; unique `(provider_account_key, provider_message_id)` for a body-free `0` exit event; index `(support_case_id, inserted_at, sequence)` and references by operation/closure ID where needed. Sequence allocation uses the shared conversation lock order.
- **Failure/recovery:** event insertion failure aborts the associated state transition. Events are never reconstructed from PubSub or logs.

### 5.6 Assignment is a case field, not another resource

`assigned_operator_id`, `claimed_at`, and the case lock version represent the current owner. Claim/release/reassignment events in `SupportCaseEvent` preserve history. A separate `SupportAssignment` resource is unnecessary until assignments themselves need an independent lifecycle, team queue, or schedule. The current `GlobalOpsAuth` actor has a username identity, not an application user table. Before multi-agent production use, the owner must ensure each allowed operator has a distinct stable identity; a shared login cannot provide meaningful actor attribution.

## 6. State machines and transition guards

### 6.1 SupportCase and assignment

| Transition | Actor and guard | Transactional changes | Side effect/failure |
| --- | --- | --- | --- |
| No case → `waiting` | Verified customer message; no active case; inbound identity not already recorded. | Create case generation, customer message, event, and `Sales.Conversation` support-routing update atomically. | Return the existing case for the same provider message key. Roll back all writes on any failure. |
| `waiting` → `claimed` | Authenticated support operator; compare-and-swap current version; no current assignee. | Set assignee/time, increment version, append event. | Exactly one concurrent claim wins; stale claimant sees current state. |
| `claimed` → `waiting` | Current assignee releases; no active closure/recovery blocker. | Clear current assignee, preserve claim event history, increment version. | Waiting queue projection invalidated after commit. |
| `waiting`/`claimed` → `cancelled` | Customer sends the October `0` escape; the global STOP/privacy handler has already had precedence. | Under the shared lock, mark the case cancelled, append a body-free exit event, move queued operations to `suppressed_before_dispatch` and proven-non-acceptance retries to `retry_suppressed`. Clear this case's support routing only when no other handoff reason remains. | Exit does not wait for an unknown send. A committed `dispatching` operation may still reach Meta and remains unresolved, auditable, and unretried. Use the existing October safe main-menu recovery only when the global send guard permits it. |
| Global STOP/privacy event | Verified inbound control event; the existing global handler runs before support routing. | Apply the approved STOP/privacy behavior and prevent new support dispatch authorization from the current durable suppression authority. Its exact source and transactional availability must be verified before implementation. | If that authority cannot be read safely, fail closed and disable support sends. Do not reinterpret STOP as `0` or send a support reply. A previously `dispatching` request cannot be recalled; retain its outcome as pending/unknown. |
| `claimed` → closure pending | Assigned operator requests resolution against the current case version. | Create closure epoch, set fence sequence and pending marker under the case lock; append event. | New agent submissions fail with `case_closing`; pre-fence workers may finish their already accepted operation. A stale page cannot fence a newer message. |
| `claimed` → `resolved` | Closure guards in §8 pass. | Finalize closure and case in one transaction; append events; clear support routing conditionally. | No Sales order/payment/ticket state changes. If any pre-fence outcome is unknown, remain open and blocked. |
| Terminal case → new `waiting` generation | Customer re-enters support under the adopted reopen rule. | Preserve old case and closure rows; create next case generation under the conversation lock. | Reopen is a new case, not mutation of terminal `resolved` or `cancelled`. This behavior needs owner adoption because October does not define a reopen rule. |

All customer inbound messages while a case is active are support messages except the approved global STOP/privacy handling and the existing explicit support escape. The verified inbound message or control event is durably recorded before the webhook path acknowledges it. If a customer message arrives during an active closure fence, it is persisted with a sequence after the fence, aborts that closure attempt, and requires operator review. It is never discarded. An unknown operation does not prevent customer exit, but it blocks a later support send until authorized disposition.

### 6.2 SupportMessage and ExternalCreateOperation

```text
Agent submission
  -> accepted + durably persisted (one Postgres commit)
  -> dispatch queued (same commit)
     -> suppressed_before_dispatch (exit/STOP wins before first dispatch)
     -> dispatching (worker claim with durable fencing version)
        -> provider_accepted (provider ID persisted)
        -> failed_retryable (only proven non-acceptance; same logical operation)
           -> queued (bounded authorized retry)
           -> retry_suppressed (exit/STOP before the next attempt)
        -> failed_permanent (known rejection; operator-visible)
        -> outcome_unknown (request may have reached provider)
          -> reconciling (only through a verified provider lookup/correlation path)
             -> provider_accepted
             -> failed_retryable (only conclusive non-acceptance)
             -> needs_review (no authoritative result)
```

`accepted` and `durably persisted` are not separate externally visible states: FastCheck returns acceptance only after the transaction commits. `dispatch_queued` means both the operation row and durable Oban job/outbox reference exist. `provider_accepted` means Meta acknowledged the send and FastCheck persisted the provider message ID. `delivered` is a later provider status, not a synonym for acceptance. `needs_review` never triggers a retry.

The customer `0` escape and global STOP/privacy are not provider-operation states. If either wins the shared lock before the first `queued -> dispatching`, FastCheck suppresses the operation and creates no provider request. A proven-non-acceptance retry is separately recorded as `retry_suppressed` if exit/STOP wins before the next attempt. If `dispatching` committed first, a later exit cannot revoke the request; an unknown result stays unknown and the case may still be cancelled. The audit must not label the provider operation cancelled merely because support ended.

| Transition | Guard | Recovery behavior |
| --- | --- | --- |
| `queued` → `suppressed_before_dispatch` | Customer `0` or global STOP/privacy wins the shared lock before first dispatch authorization. | Preserve the message and operation audit; create no provider request. |
| `failed_retryable` → `retry_suppressed` | Customer `0` or global STOP/privacy wins before a bounded next attempt; the prior response proves non-acceptance. | Preserve the known failed attempt and suppress only its next attempt; do not imply the prior HTTP request was never made. |
| `failed_retryable` → `queued` | Exact provider contract proves non-acceptance and current case/send policy still authorizes another attempt. | Retry the same operation ID under bounded backoff; do not create another SupportMessage. |
| `queued` → `dispatching` | Worker atomically claims the operation and increments the fencing version after checking current case and send policy; no earlier send remains unresolved for the case. | Duplicate Oban jobs observe non-queued state and exit without sending. If exit/STOP committed first, the operation is already suppressed. |
| `dispatching` → `provider_accepted` | Provider success response and WAMID are validated; DB commit succeeds. | If DB commit fails after provider success, mark outcome unknown from durable reconciliation, not a new send. |
| `dispatching` → `failed_retryable` | Exact provider contract proves this response means no message was accepted. | A bounded retry may follow only after the current case/send policy is checked again; no new SupportMessage. |
| `dispatching` → `failed_permanent` | Definitive validation/auth rejection. | Show failure; require correction or authorized new submission. Do not claim sent. |
| `dispatching` → `outcome_unknown` | Timeout, transport loss, crash after dispatch may have started, ambiguous 5xx, or unknown response. | Stop automatic sends. Reconcile only by a provider-supported stable key; otherwise `needs_review`. |
| Provider status → delivery projection | Verified webhook, exact account scope, exact WAMID match, valid monotonic status transition. | Duplicate/out-of-order events are recorded and ignored or projected monotonically; they do not create a new send. |

### 6.3 Intake state on `Sales.Conversation`

The November proposal's `collecting_support_description` checkpoint may be retained as a minimal `Sales.Conversation.state` value so a restart between Help selection and description does not route free text into sales. It is not a support case or a transcript. The owner must adopt this change because it is not part of the approved October state vocabulary. The first accepted description creates the case and encrypted message atomically. No separate `SupportHandoff` record is needed.

## 7. Message and operation identity strategy

1. **Inbound identity:** verified provider account scope plus WAMID is the stable source identity for a customer message. A Postgres unique constraint prevents duplicate transcript insertion even after Redis dedupe expiry or duplicate Oban execution.
2. **Agent submission identity:** issue a high-entropy random submission key with the reply form and reuse it on LiveView retries/reconnects. Scope the unique key to the configured provider account, not only the case, so reuse against another case also conflicts; persist the submitting actor and immutable operation kind. Before lookup, authorize the current actor to access the requested case and any receipt allowed by the current read policy. If the key exists, require its stored case, actor, operation kind, and exact semantic payload to match before returning a status-only receipt. For text-only replies, compare the candidate UTF-8 body bytes and message type to the original body after decrypting it in memory. Do not persist a plaintext body hash. A different actor, case, payload, or operation kind returns a non-content-bearing conflict and creates no message, operation, or job; do not reveal an existing operation ID for that conflict. If authorization or decryption fails, fail closed without revealing whether the key exists. Only a new key proceeds to reply authorization, stale-version validation, and UUIDv7 operation creation. Do not generate a new key when acknowledgement is lost; retry the original key.
3. **Operation identity:** after authorization and the duplicate-key lookup, the server creates a UUIDv7 `operation_id` once for the accepted logical reply. It is persisted in the same transaction as `SupportMessage`, `SupportCaseEvent`, and the outbox/Oban row. A failed transaction creates no accepted operation.
4. **Postgres integrity:** require unique operation ID; unique `(provider_account_key, client_submission_id)`; unique operation per message/provider/kind; unique inbound WAMID per provider account on `SupportMessage` and on the body-free `0` event path; unique message sequence per case; and one active case per conversation. Intake checks the provider key across both receipt paths under the shared conversation lock before classifying the event. The operation row, not Redis, is the durable dedupe guard.
5. **Worker coordination:** a conditional update/row lock plus fencing version grants one worker the right to dispatch. Oban uniqueness reduces duplicate jobs but is not the correctness mechanism. A stale or repeated job reads Postgres and exits unless the operation is provably in a safe queued state.
6. **Transaction boundary:** current authorization, exact replay comparison or new-submission validation, message persistence, operation creation, audit event, case sequence/version increment, and durable Oban enqueue commit together. A unique-key race is resolved by re-reading through the same authorization and exact-match rules; a mismatch never creates a second operation. No database transaction remains open across a Meta HTTP request.
7. **Crash recovery:** a crash before dispatch is safely recoverable from the committed queued operation. A crash after dispatch may have started is ambiguous; lease expiry does not authorize another send. Recovery moves it to reconciliation or `needs_review`.
8. **Provider correlation limit:** the current reviewed FastCheck path stores Meta's WAMID after a successful response and uses WAMID for later status reconciliation. A local UUIDv7 is not a Meta idempotency key. The status webhooks document a provider message `id`; they do not by themselves prove that a lost send response can be mapped to the local operation. Any provider-side idempotency or opaque correlation feature must be verified against the exact API version before use. Until then, an unknown outcome remains unresolved and blocks closure.
9. **No content-based deduplication:** two distinct submission keys with identical text are two intentional logical replies. Do not suppress one by a body hash. Duplicate prevention applies to the same submission identity and operation, not to guessed user intent.

Meta's current official [messages webhook reference](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/reference/messages) describes separate `sent`, `delivered`, and `read` status webhooks and correlates them by a provider message ID. That supports post-ack status tracking; it does not establish exactly-once send behavior or recovery of a lost create response. It is not a pinned Graph API version contract; implementation must verify the configured version and any correlation feature before relying on it.

## 8. Conversation close-fence protocol

### Shared transaction and lock order

The current implementation does not yet provide the proposed support fence. At repository revision `3893d2afeee0cdbb05dc8c331e18996f4cfa3e98`, `InboundCheckpoint.checkpoint/2` opens its own `FastCheck.Repo.transaction`, takes `pg_advisory_xact_lock` using the WhatsApp ID, and creates or updates `Sales.Conversation`. The webhook controller then commits that checkpoint before writing the Redis session and inserting the inbound Oban job. `last_inbound_message_id` is a latest-value checkpoint, not a durable ordered inbox. A later support write cannot claim to share the checkpoint transaction or lock.

The support path must refactor ingress to use one caller-owned `FastCheck.Repo` transaction. It must not call the current `checkpoint/2`, let that transaction commit, then write support state in another transaction. Ash actions for `Sales.Conversation` and `FastCheck.Support` must join that same repository transaction. The current STOP/privacy suppression authority must also be identified and checked by dispatch authorization; until its durable source and transactional read path are verified, support sends stay disabled. Every write that can affect support ordering, send authorization, case state, or closure follows this order:

1. Acquire the existing per-`wa_id` `pg_advisory_xact_lock` first. This also serializes creation when no `Sales.Conversation` row exists.
2. Lock or create the `Sales.Conversation` row.
3. Lock or create the relevant `SupportCase` row.
4. Lock the active `ConversationClosure` row, if one exists.
5. Read or write message, operation, audit, and durable Oban rows.

Inbound intake, agent claim/reply/exit/resolve, dispatch authorization, and any provider-status transition that can affect closure use this order. No path may acquire a lower item first and later request a higher item. Never hold the database transaction open across Meta HTTP. If Ash/Oban cannot participate in this transaction, the specification is not met; implementation must stop until a transactional Postgres ingress/outbox path is approved.

For every verified inbound event routed to support, the transaction checks the approved global STOP/privacy rule first, looks up `(provider_account_key, provider_message_id)` across the support-message and `0`-event receipt paths, updates the Sales checkpoint, and then records the event once. Ordinary support text becomes an encrypted `SupportMessage` with the next message sequence. A `0` command on an active case becomes a body-free `SupportCaseEvent` and cancels the case in the same transaction. Global STOP/privacy remains owned by its existing authority, which must retain its own durable provider identity and idempotency. Insert any required durable processing job before acknowledging the webhook; job arguments contain only the internal receipt ID. Postgres uniqueness and the shared conversation lock are authoritative; Redis dedupe is only an accelerator and cannot cause an event to be discarded without a durable receipt. Apply `0` and STOP decisions in the transaction; STOP creates no support-send job. Message sequence order is the order in which these locked transactions commit, not provider timestamps or worker completion order.

If the transaction rolls back, it leaves no checkpoint, support receipt, sequence, or job. If the webhook response is lost after commit, the same provider message ID resolves to the existing receipt and job instead of creating another sequence. A worker restart resumes from Postgres/Oban. An inbound event whose transaction commits after a close fence receives a later sequence and follows the race rules below; an event not yet delivered to FastCheck cannot be included in a local close proof.

### 8.1 Fence and resolution

The shared conversation lock order above is the serialization point for inbound message acceptance, agent reply acceptance, claim/assignment, dispatch authorization, customer exit, global STOP/privacy handling, and closure. This produces one durable order for accepted support events, case sequence numbers, send authorization, and the close fence.

1. **Request:** the current assignee requests resolution with the case version shown in the workspace. In one transaction following the shared lock order, FastCheck locks/CASes the case, rejects a stale version, verifies no other closure is active, creates the next `ConversationClosure` epoch, stores the highest committed support sequence as `fence_sequence`, marks the case closure-pending, and appends an audit event. This commit is the fence. A displayed `CLOSING` label is derived from durable closure state.
2. **Reject later agent writes:** any reply action that obtains the case lock after the fence sees closure-pending and rejects. No message, operation, or job is created. Two concurrent agents cannot overwrite each other: only the current assignee can reply, and each accepted message receives a unique sequence in the serialized transaction.
3. **Finish pre-fence work:** operations referencing messages with sequence at or below the fence may finish. The closure reconciler reads Postgres and accounts for every accepted reply. A callback or PubSub event is not required to establish local completeness.
4. **Block unresolved outcomes:** queued, dispatching, safely retryable, reconciling, unknown, and needs-review operations block business resolution until they reach a known send disposition or receive an authorized, audited disposition. `suppressed_before_dispatch` is known non-acceptance because no provider request was authorized; `retry_suppressed` preserves a conclusive earlier non-acceptance and records that no further attempt will run. A definitive permanent rejection requires an operator-visible disposition before resolution. A provider-accepted reply is accounted for even if its delivery receipt is still pending; the workspace must say “accepted by Meta, delivery unconfirmed.” Whether customer delivery confirmation is a resolution prerequisite is an owner decision.
5. **Finalize:** when all messages through the fence are durably present, every pre-fence outbound has a known send disposition, and the current assignee explicitly confirms resolution against the current case version, one transaction marks the closure and `SupportCase` resolved, conditionally clears support routing, and appends the final events. A newer inbound message makes the version stale or aborts the active closure, so the operator must review the updated case. The case's resolved state is independent of delayed PubSub delivery.
6. **Unknown outcome:** mark closure `recovery_required`; keep the case nonterminal and block business resolution. Do not retry the uncertain operation. Final resolution requires an authoritative reconciliation result or a separately approved owner risk decision that changes the business requirement. This guard does not block a customer `0` exit: exit aborts the closure attempt, cancels the case, suppresses unsent work, and preserves the unknown operation for audit.

### 8.2 Inbound messages, callbacks, and reopening

- An inbound customer message whose durable receipt commits before the fence is included through its sequence and must be reviewed/disposed before resolution. If its receipt commits after the fence but before finalization, append it with the next sequence, abort the closure attempt, and keep the case open. A customer `0` during this interval aborts the closure, cancels the case, and suppresses queued sends even when an older operation is unknown.
- If an inbound message reaches FastCheck only after a case has resolved, its provider timestamp cannot move it before the committed fence. Route it through the adopted new-generation rule or the existing safe routing path; never append it to the resolved transcript or claim the fence covered a webhook not yet received. New-generation behavior remains an owner decision because October does not define reopening.
- Global STOP/privacy handling takes precedence over support routing under the same lock order. It applies the existing suppression authority and prevents new dispatch authorization. The authority's durable source and transactional read path are an implementation gate; until verified, disable support sends. STOP is not a support exit and does not trigger the `0` response. A request already in `dispatching` cannot be recalled; preserve its actual or unknown outcome.
- Provider delivery-status events may be delayed, duplicated, or reordered. They update only the matching operation/message projection and audit trail. They do not alter the case sequence, clear the closure fence, or reopen a resolved case.
- A restart reloads the active closure and operations from Postgres. Redis, ETS, PubSub, and LiveView snapshots are not close barriers.

### 8.3 Enforceability and limits

- **A.** An agent cannot create a support reply directly in Chatwoot because Chatwoot is not in the MVP agent path.
- **B.** An agent cannot resolve a case outside `FastCheck.Support` actions.
- **C.** Ash policies and Postgres state transitions reject writes before commit; LiveView is only a caller.
- **D.** Every FastCheck-accepted reply has a committed transcript row before any provider dispatch. Every support-routed inbound event also has a durable WAMID-keyed receipt and sequence before its webhook path acknowledges acceptance.
- **E.** Delayed/lost/duplicate callbacks cannot delete the local row or advance a closure; provider delivery status can still remain unknown.
- **F.** Inbound support intake, reply, exit, dispatch authorization, STOP/privacy suppression, and resolution serialize in the single lock order in §8.
- **G.** An accepted reply cannot appear only after closure because its transcript row commits before it is acknowledged; an ambiguous provider send can still produce a late customer delivery, and must be shown as unknown until reconciled.
- **H.** Restart recovery reads durable state, not memory snapshots.
- **I.** Reopening creates a new case generation and closure history.
- **J.** The local close barrier is enforceable only if all write paths, including administrative tooling and provider callbacks, use the same Ash actions and Postgres guards. A direct SQL/admin bypass is outside the invariant and must be prohibited operationally.

The proposal can prove local transcript completeness for support events durably received by FastCheck up to a committed fence. It cannot include an inbound event that Meta has not yet delivered to the webhook, prove Meta delivered a message to a customer's device from a successful HTTP response, or automatically resolve an ambiguous send without a provider contract that correlates or queries that send. “Resolved” is the support business decision, not a provider delivery receipt. Customer exit remains available while these provider facts are unknown.

## 9. FastCheck agent workspace design

### Routes and authorization

Proposed routes are `/dashboard/support` and `/dashboard/support/:support_case_id` under `[:browser, :dashboard_auth, :global_ops_auth]`, matching the repository's current browser and global operations boundaries. The actual LiveView mount and every Ash action must revalidate the actor; client parameters never supply an actor or broader scope. The present dashboard actor is a username identity from `GlobalAccess`, not a user table. Use it only as a stable actor key if the owner ensures distinct allowlisted operator identities.

### Minimum surfaces

- **Queue:** waiting cases oldest first; cases assigned to the current operator; bounded recently resolved lookup for reference. Show masked operational context, wait time, language, assignment, and unresolved-operation warning.
- **Case:** bounded, keyset-paginated canonical transcript; claim/release; reply composer; delivery state (`queued`, `accepted`, `delivered`, `failed`, `suppressed before dispatch`, `retry suppressed`, `outcome unknown`); resolution request; reopen as a new case generation where approved.
- **Recovery:** show unresolved external operation and block reply/resolve controls when the durable state requires it. Expose only safe failure categories and operation IDs.

### Synchronous and asynchronous actions

| Operation | Behavior |
| --- | --- |
| Queue/case read | Synchronous bounded Ash read, with decrypted message body returned only after policy authorization. Keyset pagination by case sequence, maximum 50 rows per page. |
| Claim/release/reassign | Synchronous Ash transaction with version guard and audit event. |
| Submit reply | Synchronous acceptance only: validate, encrypt, insert `SupportMessage`, operation, event, and Oban job in one Postgres transaction. The UI reports accepted only after commit. |
| Meta send and status reconciliation | Asynchronous Oban worker. No Meta HTTP request runs in a LiveView handler or database transaction. |
| Request resolution | Synchronous fence transaction; reconciliation and pre-fence workers proceed durably. Finalization occurs only when guards pass. |
| Reopen | Synchronous new-case action with new generation and full audit; exact permissions and allowed triggers require owner adoption. |

LiveView receives PubSub events after commit. PubSub payloads contain internal IDs, sequence/version, and event type only; the view reloads authorized data through Ash. No polling is required. A missing PubSub event may delay display refresh, but cannot change durable acceptance or closure. All writes call authorized Ash actions; templates and event handlers never write directly to the database.

## 10. Data flow and proposed module structure

### Data flow

```text
Verified Meta webhook
  -> existing WhatsApp verifier / normalizer
  -> one FastCheck.Repo transaction in the §8 lock order
       -> global STOP/privacy check first
          -> if STOP/privacy: apply existing global suppression authority; no support-send job
       -> otherwise: Sales.Conversation checkpoint + locked support-route decision
       -> SupportCase + encrypted SupportMessage or body-free `0` control event
       -> durable processing job with internal receipt ID only
  -> commit and acknowledge; Redis dedupe remains an accelerator
  -> SupportRouter processes the durable receipt before any Sales transition

Agent LiveView
  -> authorized Ash action
  -> Postgres transaction: SupportMessage + ExternalCreateOperation
     + SupportCaseEvent + Oban job + sequence/version commit
  -> Support dispatch worker (ID-only args)
  -> strict support policy adapter
  -> existing WhatsApp Meta client
  -> provider acknowledgement/status webhook
  -> operation reconciliation + PubSub after commit

Resolution request
  -> Postgres fence transaction in the shared conversation lock order
  -> pre-fence operation reconciliation
  -> final closure transaction or recovery_required
```

### Proposed paths

```text
lib/fastcheck/support.ex
lib/fastcheck/support/support_case.ex
lib/fastcheck/support/support_message.ex
lib/fastcheck/support/external_create_operation.ex
lib/fastcheck/support/conversation_closure.ex
lib/fastcheck/support/support_case_event.ex
lib/fastcheck/support/intake.ex                 # cross-domain support intake facade
lib/fastcheck/support/message_delivery.ex       # durable acceptance/reconciliation orchestration
lib/fastcheck/support/closure.ex                # close-fence actions and guards
lib/fastcheck/messaging/whatsapp/inbound_checkpoint.ex # caller-owned transaction and existing advisory lock
lib/fastcheck/messaging/whatsapp/support_router.ex
lib/fastcheck_web/controllers/webhooks/whatsapp_controller.ex # durable support receipt before webhook acknowledgement
lib/fastcheck/messaging/whatsapp/support_delivery_policy.ex
lib/fastcheck/messaging/whatsapp/support_delivery.ex  # existing Client boundary, strict result mapping
lib/fastcheck/workers/support/dispatch_reply_worker.ex
lib/fastcheck/workers/support/reconcile_operation_worker.ex
lib/fastcheck_web/live/support/inbox_live.ex
lib/fastcheck_web/live/support/case_live.ex
test/fastcheck/support/
test/fastcheck/messaging/whatsapp/support_router_test.exs
test/fastcheck/workers/support/
test/fastcheck_web/live/support/
```

`FastCheck.Sales` retains `Conversation`, orders, payments, resend, and commercial guards. `FastCheck.Messaging.WhatsApp` retains verified ingress, bot routing, delivery-window evaluation, and the existing Req-based Meta client. `FastCheck.Support` owns support business rules and durable resources. `FastCheckWeb.Support` owns display and invokes Ash actions. Oban workers own asynchronous external effects. No new Chatwoot context or duplicate sales conversation resource is introduced.

## 11. Security and performance review

### Durable correctness and isolation

- Postgres transactions, unique constraints, case versioning, and operation fencing are the correctness controls. Redis, ETS, PubSub, and GenServer coordination are disposable accelerators only.
- All support queries scope through the authorized case and its parent `Sales.Conversation`; message decryption requires support policy. Cross-case and cross-channel reads are denied by Ash, not hidden UI controls.
- The inspected Sales/Events model has no `tenant_id` or `organization_id`. The MVP is limited to the configured WhatsApp account and current global-ops boundary. Multi-account or tenant support must wait for a separately approved durable account mapping and corresponding composite keys/policies.
- Run the approved global STOP/privacy handler before support routing. Apply existing WhatsApp service-window and template rules, with a strict timestamp provenance check immediately before each send. This proposal does not define or waive CG-1 or create new consent rules. If an approved durable send-authorization/consent source is missing, customer sends remain blocked pending owner resolution.
- Encrypt message bodies at rest; keep key version and ciphertext only in persistence. Do not persist plaintext payload hashes. Do not place plaintext, phone numbers, tokens, provider payloads, or body hashes in Oban args, Redis, logs, metrics, or PubSub. Oban args contain internal operation IDs only. LiveView responses are not CDN-cacheable, and decrypted transcript content is not stored in browser localStorage/IndexedDB.
- Record operator, system, and provider transitions in `SupportCaseEvent`; separate retention and deletion policy must be approved before production use.

### Hot/warm/cold data and cache rules

| Tier | Proposed use and controls |
| --- | --- |
| Postgres, cold authority | Cases, encrypted messages, operations, closure epochs, audit events, and Oban jobs. Every cache can be rebuilt from this state. Use PgBouncer transaction pooling where the deployment uses it. |
| Redis, warm | Non-sensitive queue/case summaries and operational counters keyed by internal IDs. Follow the October design's field-specific 30-second to 5-minute summary TTLs. Never store message plaintext, phone, email, credentials, operation payload, or ownership locks. Redis outage falls back to bounded Postgres reads; write correctness remains in Postgres. |
| ETS/GenServer, hot | Per-node queue counts and short-lived snapshots with seconds-to-minutes lifetime. Rebuild from Postgres/Redis; no cross-node ownership or close decision. |
| PubSub | After-commit `support_case_changed`, `support_message_accepted`, `support_operation_changed`, and `support_closure_changed` notifications with IDs/version only. Missed events cause a later authorized reload, never a state transition. |
| Browser | LiveView memory for the rendered page only; no support PII in persistent browser storage. |

Invalidate summaries on case state, assignment, message sequence, operation status, closure epoch, and retention changes. Use per-key single-flight refresh or bounded GenServer aggregation to limit stampedes; this is an optimization, not a lock. Do not add polling refreshes.

### Query paths and indexes

Required indexes are listed in §5 and must be validated with `EXPLAIN` against approved production-like cardinalities. Transcript reads use keyset pagination on `(support_case_id, sequence)` and never load an unbounded history. Queue reads are bounded by status/time/assignment. Operation workers select due rows through a partial state/time index. No peak-time full transcript scan or PII search is required for the MVP.

### 100k concurrent users and failure behavior

The October design identifies 100k-user safety and sub-100 ms ordinary API/read latency as design targets, not measured guarantees. This proposal makes no throughput promise. The critical write path is one short Postgres transaction per accepted reply or case transition, followed by asynchronous work. Contention is per case/conversation; no global GenServer lock is required. At 100k concurrent users, pool sizing, hot-case lock contention, queue depth, and LiveView fanout require approved load and recovery tests.

- **Duplicate job execution:** durable operation CAS/fencing blocks a second dispatch.
- **Worker crash:** before external dispatch, queued operation is recoverable; after dispatch may begin, state becomes unknown and no retry occurs.
- **Out-of-order callback:** provider WAMID/account scope and monotonic status projection prevent unrelated message mutation; persist safe evidence and ignore stale transitions.
- **Database failover:** do not report accepted until message and job commit. If failover leaves commit outcome uncertain, read by the same submission ID. If Meta may already have accepted, mark unknown. HA durability and failover timing remain untested.
- **Network partition:** no external send without a durable operation and current lease; uncertain in-flight send is quarantined.
- **Redis outage:** no correctness degradation; use bounded database reads or reject/shed nonessential queue views if Postgres is pressured. Never accept duplicate work because a Redis lock disappeared.
- **PubSub outage:** UI may be stale; reload from Postgres. No closure depends on event delivery.
- **100k-user load:** untested. Owner must set concurrent-user, queue-age, message-rate, latency, failover, and recovery targets before performance qualification.

## 12. Failure-mode matrix

| Failure | Durable result | Required behavior |
| --- | --- | --- |
| Duplicate inbound webhook/WAMID | Existing SupportMessage, body-free `0` event, or approved global suppression receipt found by provider source key. | Return prior processing state; do not allocate another sequence or enqueue duplicate work. |
| Same LiveView submission retried | Authorized actor, operation kind, case, and exact payload match the account-scoped stored submission key. | Return a status-only receipt; never return message body or mint a new operation ID. Conflicts create nothing. |
| Two operators claim simultaneously | One case version update commits. | Loser sees stale/already-claimed state. |
| Postgres transaction fails before commit | No accepted message, operation, event, or job. | UI may retry with same submission ID. |
| Duplicate Oban job | Operation is already dispatching/terminal. | Exit without provider request. |
| Worker dies before dispatch is possible | Operation remains queued or `suppressed_before_dispatch`. | Retry only if still authorized and queued; a customer exit or STOP suppresses it. |
| Worker dies after request may have started | `outcome_unknown`. | No automatic retry; attempt only verified provider reconciliation, else `needs_review`. |
| Meta returns success but DB write fails | Provider may have accepted; WAMID may be lost. | Unknown outcome; close fence blocks; do not infer rejection. |
| Meta returns 429/5xx | Provider-specific acceptance semantics may vary. | Retry only if exact API contract proves non-acceptance; otherwise unknown. Existing generic `retryable?` is not sufficient proof for support. |
| Delivery callback is duplicate or reordered | Existing operation status and audit rows. | Scope by verified provider account and WAMID; apply only a valid monotonic transition. |
| Customer message races with close | Durable ingress receipt and close fence use the shared lock order. | Include and review pre-fence input; a post-fence receipt before finalization aborts the attempt. A later-received provider event cannot be claimed as covered by the earlier fence. |
| Reply races with close | Shared conversation lock order and case CAS determine the winner. | Reply commits first and falls under the fence, or the fence commits first and reply is rejected before acceptance. |
| PubSub message is delayed/lost | Postgres state is unchanged. | UI may refresh late; closure and authorization read durable state. |
| Redis or node-local state is lost | Durable rows remain. | Rebuild summaries and worker state; never infer closure from cache. |
| Shared operator identity | Audit cannot distinguish humans. | Block multi-agent rollout until distinct authorized identities exist. |
| Cross-account identifier is supplied by client | No authority in request. | Reject; derive account scope from verified channel and bound conversation. |
| WhatsApp consent/window guard is missing or uncertain | No authorized send. | Fail closed; require an owner-approved guard source before send enablement. |

### 12.1 Defect-resolution matrix

| Original problem | Corrected invariant | Transition guards | Failure behavior | Required acceptance test |
| --- | --- | --- | --- | --- |
| October `0` exit could be blocked indefinitely by an unknown Meta send; STOP/privacy precedence did not define what happens to queued work. | `0` always ends support routing. Unknown sends remain auditable and are never called cancelled, delivered, or retried. STOP/privacy blocks new send authorization. | Global STOP/privacy runs first. Exit/STOP and dispatch claim use the shared lock. They move `queued` work to `suppressed_before_dispatch` and a conclusive `failed_retryable` operation to `retry_suppressed`; a committed `dispatching` operation is not recallable. | If exit wins, suppress future attempts and return through October's guarded main-menu path. If dispatch authorization wins, cancel the case or apply the existing STOP state while retaining the actual/unknown operation outcome. Do not send a support response after STOP. | Race an agent reply job against `0` and STOP. Assert the lock winner determines whether a provider request starts, the customer can exit despite `outcome_unknown`, no retry occurs, and the operation remains linked and auditable. |
| `InboundCheckpoint` commits its advisory-locked Sales checkpoint before support persistence and Oban enqueue; latest-message state is not a durable ordered inbox. | Every support-routed inbound WAMID, checkpoint, support sequence/control event, and durable job commit in one transaction and use one lock order: conversation advisory lock, Sales row, SupportCase row, closure row, child rows. | Inbound, agent writes, exit, dispatch authorization, STOP/privacy, and closure acquire locks in that order. Postgres WAMID uniqueness is authoritative; Redis cannot discard an unreceipted event. | Rollback leaves no partial receipt/fence. A repeated WAMID after lost acknowledgement returns the durable receipt and does not allocate another sequence/job. A message committed after a fence aborts closure before finalization; post-resolution delivery follows only an adopted new-generation/safe-routing rule. | Inject rollback and lost-ack replay; race inbound receipt with fence/finalization on separate workers. Assert unique sequence, no lost accepted input, no duplicate job, correct closure abort/order, and no deadlock from inverted locks. |
| Replaying a submission key could return an existing row before checking authorization or payload; conflicting reuse could be confused with an exact retry. | An existing account-scoped key is returned only after current authorization and exact original case, actor, operation-kind, and payload matching. No plaintext payload hash is stored. | For an existing key, authorize access first, then compare the stored actor/operation and decrypt/compare the immutable payload in memory. Only a new account-scoped key evaluates the submitted case version and creates an operation. | Same-key mismatch returns a non-content-bearing conflict and creates no message, operation, or job. Authorization/decryption failure fails closed without revealing the stored body or key existence. | Verify exact authorized replay returns only the original receipt; same key with changed body, operation kind, case, or actor creates nothing; unauthorized replay reveals no content; inspect persistence and logs for absence of plaintext hashes/bodies. |

## 13. Implementation phases and subphases

These phases are a dependency proposal only. Each requires owner adoption and separately authorized implementation. No micro-prompts or implementation code are included.

### Phase 1 — Canonical support domain and invariants

**1.1 Authority and policy adoption**
- **Outcome:** owner adopts or rejects this replacement, chooses reopen and account/agent scope, and confirms the existing support-send authorization source.
- **Resources:** approved October/November documents, `Sales.Conversation`, existing `DashboardAccess` and `GlobalAccess`.
- **Dependencies:** owner decision; no code.
- **Acceptance:** controlling October spec/plan status is explicitly reconciled; named support actors and tenant/channel boundary are documented.
- **Failure:** authority, operator identity, or send policy remains ambiguous.
- **Stop:** `STOP=OWNER_ADOPTION_REQUIRED`.

**1.2 Support resources and transactional intake**
- **Outcome:** Ash domain/resources and inbound intake preserve `SupportCase` states and durably sequence verified provider messages.
- **Resources:** `SupportCase`, `SupportMessage`, `Sales.Conversation`, Postgres constraints, `FastCheck.Support` actions.
- **Dependencies:** 1.1; supported migration plan.
- **Acceptance:** one active case per conversation under concurrent intake; Sales checkpoint, support receipt/sequence, audit, and required job share one transaction and the §8 lock order; repeated WAMID cannot create another receipt/job; failed transaction leaves no partial routing/case/message state; support transcript is not in `Sales.Conversation.state_data`.
- **Failure:** duplicate active case, cross-domain partial commit, missing durable receipt, lock inversion, or commercial-state change.
- **Stop:** `STOP=SUPPORT_DOMAIN_INVARIANT_FAILED`.

**1.3 Durable audit and authorization**
- **Outcome:** case events, role policies, actor identity, encryption and retention boundaries exist.
- **Resources:** `SupportCaseEvent`, Ash policies, existing auth boundary, encryption/key authority.
- **Dependencies:** 1.2; owner-approved retention and key policy.
- **Acceptance:** unauthorized actors cannot list/decrypt/mutate; every state change has a same-transaction audit row; no PII leaks to logs, jobs, cache, or PubSub.
- **Failure:** shared identity prevents attribution or sensitive fields escape.
- **Stop:** `STOP=SUPPORT_AUTH_OR_PRIVACY_UNPROVEN`.

### Phase 2 — Durable reply acceptance and dispatch

**2.1 Idempotent acceptance path**
- **Outcome:** accepted reply and operation are committed before dispatch.
- **Resources:** `SupportMessage`, `ExternalCreateOperation`, `SupportCaseEvent`, Postgres transaction, Oban.
- **Dependencies:** Phase 1.
- **Acceptance:** only an authorized exact actor/case/operation/payload replay returns the original status-only receipt; same-key conflicts create no rows or jobs; different key creates a distinct logical reply; operation/job/event failure rolls back acceptance.
- **Failure:** duplicate logical operation or acknowledgement before commit.
- **Stop:** `STOP=REPLY_ACCEPTANCE_NOT_DURABLE`.

**2.2 Durable worker and provider mapping**
- **Outcome:** ID-only Oban dispatch, per-case ordering, strict provider classification, and WAMID status reconciliation.
- **Resources:** support delivery adapter/policy, dispatch worker, existing WhatsApp client and status webhook.
- **Dependencies:** 2.1; verified current Meta contract for non-acceptance, status callbacks, and any correlation field.
- **Acceptance:** duplicate jobs cannot double dispatch; ambiguous send is never retried; known provider status maps to exactly one operation.
- **Failure:** external ambiguity is mistaken for rejection or successful delivery.
- **Stop:** `STOP=PROVIDER_OUTCOME_UNRECONCILABLE`.

**2.3 Unknown-outcome recovery**
- **Outcome:** authoritative lookup/correlation where supported; otherwise visible `needs_review` and a safe recovery decision.
- **Resources:** `ExternalCreateOperation`, reconciliation worker/action, `SupportCaseEvent`, operator recovery view.
- **Dependencies:** 2.2; owner-approved recovery policy.
- **Acceptance:** failure injection after provider acceptance and before DB persistence either resolves by provider identity or remains blocked without another send.
- **Failure:** the system must guess, blindly retry, or claim delivery without evidence.
- **Stop:** `STOP=EXTERNAL_OUTCOME_UNKNOWN`.

### Phase 3 — Guarded closure and recovery

**3.1 Durable fence**
- **Outcome:** inbound receipt, reply, customer exit, send authorization, and close serialize on one conversation lock order.
- **Resources:** `SupportCase`, `SupportMessage`, `ConversationClosure`, `SupportCaseEvent`.
- **Dependencies:** Phase 2.
- **Acceptance:** both commit orders of inbound/exit/reply-vs-close produce the specified result; pre-fence messages are enumerated by durable sequence; post-fence operator writes fail before acceptance.
- **Failure:** accepted reply can be omitted from closure or overwritten.
- **Stop:** `STOP=CLOSE_FENCE_UNPROVEN`.

**3.2 Reconciliation, resolution, and new case generation**
- **Outcome:** closure waits for required pre-fence dispositions and preserves prior history when support resumes.
- **Resources:** closure/reconciliation actions, provider status mapping, new `SupportCase` generation.
- **Dependencies:** 3.1; owner decision on provider-delivery requirement and reopen semantics.
- **Acceptance:** unknown operations prevent business resolution but not customer `0` exit; delayed PubSub/status events cannot mutate closure; new support request follows only an owner-approved generation rule.
- **Failure:** closure proceeds with unresolved required work or reopens a terminal case in place.
- **Stop:** `STOP=CLOSURE_RECOVERY_UNSAFE`.

### Phase 4 — Minimal LiveView workspace

**4.1 Authorized queue and case view**
- **Outcome:** bounded queue, paginated transcript, masked context, and durable status display.
- **Resources:** `FastCheckWeb.Support.InboxLive`, `CaseLive`, router pipelines, Ash read policies.
- **Dependencies:** Phases 1–3; distinct operator identities.
- **Acceptance:** both HTTP and LiveView/Ash actions enforce browser and global-ops authorization; no polling or unbounded transcript load.
- **Failure:** direct access or decryption bypasses policies.
- **Stop:** `STOP=SUPPORT_UI_AUTH_FAILED`.

**4.2 Claim, reply, resolve, recovery, reopen**
- **Outcome:** all workspace writes invoke Ash actions; users see unresolved operation warnings and correct delivery distinctions.
- **Resources:** support LiveViews, `FastCheck.Support` actions, Oban worker boundary, PubSub.
- **Dependencies:** 4.1.
- **Acceptance:** no direct Meta send from LiveView; no recipient override; failure state is visible and actionable.
- **Failure:** UI can bypass the operation ledger or closure fence.
- **Stop:** `STOP=SUPPORT_WRITE_PATH_BYPASS`.

### Phase 5 — Integration, concurrency, and security validation

**5.1 Domain and cross-boundary validation**
- **Outcome:** integration tests cover webhook intake, sales suppression, ticket-resend coexistence, role policies, and provider status.
- **Resources:** support/Ash tests, WhatsApp webhook fixtures, existing resend and Sales tests.
- **Dependencies:** Phases 1–4; synthetic fixtures.
- **Acceptance:** no support write changes order/payment/ticket authority; WAMID duplicates and account-scope attacks fail safely.
- **Failure:** commercial or privacy invariant regression.
- **Stop:** `STOP=SUPPORT_INTEGRATION_INVARIANT_FAILED`.

**5.2 Failure injection and multi-node validation**
- **Outcome:** crash/retry/failover and close races are tested with bounded synthetic workloads.
- **Resources:** Oban duplicate-job tests, Postgres transaction/failover test setup, provider adapter fakes, closure concurrency tests.
- **Dependencies:** 5.1; approved workload and failure envelope.
- **Acceptance:** duplicate worker, DB uncertainty, Redis loss, out-of-order callbacks, and reply/close races meet the state rules above.
- **Failure:** a retry or stale node can duplicate dispatch or finalize closure incorrectly.
- **Stop:** `STOP=SUPPORT_RECOVERY_TEST_FAILED`.

### Phase 6 — Performance and deployment qualification

**6.1 Approved workload qualification**
- **Outcome:** queue/read/write paths are measured against owner-approved concurrency, latency, queue-age, and recovery targets.
- **Resources:** production-like synthetic dataset, query plans, pool/queue metrics, load and recovery harness.
- **Dependencies:** Phase 5; owner-defined capacity basis.
- **Acceptance:** indexed query plans, pool/Oban bounds, memory/disk and recovery evidence meet the approved profile. No 100k claim without a matching test.
- **Failure:** target is unapproved or measured capacity misses it.
- **Stop:** `STOP=SUPPORT_CAPACITY_UNPROVEN`.

**6.2 Operations and rollback readiness**
- **Outcome:** runbooks and alerts cover stuck operations, unknown sends, close recovery, key rotation, and safe disablement.
- **Resources:** operations runbook, support alerts, retention/backup controls, recovery dashboards.
- **Dependencies:** 6.1; approved retention, backup, and support-on-call policy.
- **Acceptance:** operators can locate and contain a stuck case without retrying an unknown send or deleting audit history.
- **Failure:** recovery depends on raw logs, secret exposure, or manual database edits.
- **Stop:** `STOP=SUPPORT_OPERATIONS_UNREADY`.

## 14. MVP acceptance criteria

The MVP is ready for a separately authorized synthetic release gate only when all of these are verified:

1. FastCheck is the only authoritative support transcript and the only agent reply/resolve write path.
2. `SupportCase` retains `waiting`, `claimed`, `resolved`, and `cancelled`; there is at most one active case per Sales conversation.
3. A verified duplicate inbound WAMID and an authorized exact repeated agent submission return only the original status receipt without creating a second one; conflicting key reuse creates nothing.
4. FastCheck acceptance commits encrypted transcript, operation, audit, sequence/version, and durable job before reporting acceptance or dispatching. Support inbound receipts and the Sales checkpoint use the same transaction and lock order.
5. Worker concurrency and crash recovery cannot dispatch the same known-safe logical operation twice.
6. Any potentially accepted but unconfirmed Meta send becomes `outcome_unknown`/`needs_review`; it is never automatically retried or described as delivered. It does not block customer `0` exit; queued work becomes `suppressed_before_dispatch`, known retryable work becomes `retry_suppressed`, and an already `dispatching` outcome remains auditable.
7. Provider acknowledgement, provider delivery confirmation, local transcript persistence, and business resolution are displayed and stored as distinct facts.
8. The close fence orders durably received replies, customer messages, send authorization, and resolution. Unknown/pre-fence required work blocks business resolution; a customer exit remains available; late PubSub cannot change the stored result.
9. Resolved cases remain terminal; reopening creates a new case generation and preserves prior audit history.
10. LiveView routes and Ash actions enforce the support policy; no UI code sends directly to Meta or writes directly to the database.
11. Recipient derives only from the bound `Sales.Conversation`; STOP/privacy, service-window/template, and approved send authorization rules run before dispatch.
12. No plaintext payload hash is persisted. Customer content, credentials, phone numbers, provider payloads, and plaintext bodies do not enter logs, Oban arguments, PubSub, Redis, or browser persistent storage.
13. Ticket resend, orders, payments, inventory, and ticket issuance remain under their current approved FastCheck authorities.
14. All future implementation phases pass their stated tests, and capacity targets are owner-approved and measured. The existing October 100k target is not assumed met.

## 15. Risks and unresolved owner decisions

| Decision | Why it blocks or constrains the design |
| --- | --- |
| Adopt this replacement and reconcile the October authority plus November proposal/plan. | This document is not an approval and cannot supersede either design. |
| Confirm `collecting_support_description` and reopen-by-new-case semantics. | They are proposed lifecycle additions; October defines no explicit reopen transition. |
| Define whether business resolution requires provider acceptance or actual customer delivery confirmation. | Delivery receipts are asynchronous and can be absent. The workspace must not call acceptance “delivered.” |
| Approve the unresolved Meta send policy and verify a provider idempotency/correlation/query contract. | Local UUIDv7 and WAMID do not resolve a lost response before WAMID persistence. Without provider evidence, the case remains blocked indefinitely. |
| Confirm the durable source for support reply authorization, current STOP/privacy precedence, service-window/template checks, and CG-1 relationship. | This document does not add or waive customer consent rules. If authorization cannot be established, sends stay disabled. |
| Decide whether October's customer-facing `0` response needs an added notice when a reply had already crossed dispatch authorization and may still arrive. | The proposal keeps the October safe main-menu response and does not claim that a dispatching send can be recalled. Until an owner approves different copy, the workspace and audit must not promise cancellation or non-delivery. |
| Confirm single configured WhatsApp account for MVP or authorize a durable account/channel identity model. | Current Sales resources lack a tenant/account key; multi-account isolation cannot be claimed from a conversation ID alone. |
| Ensure separate named support identities in the existing global-ops allowlist. | Current actor identity is a username and may be shared; shared credentials undermine assignment and audit attribution. |
| Approve message encryption/key lifecycle, retention, deletion, and backup rules. | Support transcript is sensitive durable data; deletion cannot destroy unresolved operation/audit evidence prematurely. |
| Set workload, latency, queue-age, failover, and recovery targets. | October describes scaling targets and 100k-user safety questions, not certified capacity. |
| If a Chatwoot mirror is later requested, approve an enforceable read-only boundary. | UI labels or callback discipline do not prevent agents from using direct write routes. No mirror is included now. |

## 16. Explicit adoption recommendation

Adopt Option B as the replacement direction, subject to owner decisions above. Keep the existing October support and resend business rules; preserve its `SupportCase` terminology and terminal states; replace only the agent workspace, transcript owner, delivery ledger, and closure mechanism. Do not adopt the proposed November `SupportHandoff`/Chatwoot ownership model or add a writable Chatwoot dependency to the MVP.

This proposal gives FastCheck a design for durable local acceptance and an enforceable local close fence. It does not claim exactly-once Meta delivery, a provider reconciliation capability that has not been verified, 100k-user capacity, or a passed Chatwoot Gate A. If the owner requires every unknown Meta outcome to be automatically resolved and Meta provides no authoritative idempotency or correlation path, the complete requirement is not currently designable with FastCheck alone. Keep that condition explicit instead of weakening the invariant.

**Adoption state:** awaiting an explicit owner decision. Until then, the October 15 design remains approved, the November 10 design remains proposed, the Gate A feasibility verdict remains unchanged, and no implementation is authorized.
