# FastCheck Support Workspace architecture adoption

| Field | Value |
| --- | --- |
| Decision ID | `FASTCHECK-SUPPORT-WORKSPACE-OPTION-B-001` |
| Status | `ADOPTED — ARCHITECTURE ONLY` |
| Draft date | 2026-11-15 |
| Adoption date | 2026-11-16 |
| Owner decision | [Issue #557 comment 6909586126](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6909586126) |
| Repository | `Carpe-Diem-Media/FastCheckin`, GitHub repository ID `1096911087` |
| Scope | Support-workspace architecture only |
| Implementation authorization | None |

## Decision status and provenance

GitHub issue #557 contains the explicit decision `OPTION_B_SUPPORT_WORKSPACE_ADOPTED` in [comment 6909586126](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6909586126), posted by `JCSchoeman96` on 2026-11-16. The comment author matches the active Carpe-Diem-Media organization account whose membership endpoint reports role `admin`; the repository identity is ID `1096911087`. This verifies the owner/admin authority for this architecture-only adoption record.

The owner adopted the exact November 14 replacement proposal SHA recorded below, with the non-null identity requirements and October administrative-close transition explicitly stated in the decision. The technical review at [comment 6893474669](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6893474669) and earlier assessment at [comment 6873972083](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6873972083) remain supporting technical evidence, not the adoption authority. Issue #557 remains open.

## Verified sources and current authority

| Source | Verified revision or status | Authority today |
| --- | --- | --- |
| Repository snapshot | `main` at `3893d2afeee0cdbb05dc8c331e18996f4cfa3e98`; repository ID `1096911087`. | Canonical repository identity is `Carpe-Diem-Media/FastCheckin`. |
| [October 15 approved support design](../specs/2026-10-15-whatsapp-customer-service-resend-design.md) | Git blob `8a0e7ea8040cb1292fcb0993ae1ec9d881afd79b`; status `APPROVED`; implementation authorization `GATE 0 ONLY`. | Remains the approved authority for customer navigation and support journeys, customer `0` exit, `waiting -> cancelled` administrative close under existing actor policy, ticket resend, privacy and STOP behavior, ticket ownership, payment, inventory, and commercial safeguards. |
| [November 10 Chatwoot design](../specs/2026-11-10-whatsapp-flows-chatwoot-integration-design.md) | Git blob `953d9d77eca1afbc6405cd032eac5619dbbf6e29`; status `Proposed`. | Was never adopted. Its writable Chatwoot workspace is not selected for the proposed MVP. |
| [November 14 replacement proposal](../specs/2026-11-14-fastcheck-support-workspace-replacement-design.md) | Supplied working-tree file SHA-256 `71da64d7ab024c885328017b37841a4e4c63d051364de8e179967e237731ceda`; the file retains its original `PROPOSED — NOT ADOPTED` label. | This ADR records adoption of that exact revision for the support-workspace architecture only. |
| [October 15 implementation plan](../plans/2026-10-15-whatsapp-customer-service-resend.md) | Git blob `2f6146f6e3e1dcb29466778a3c618eb6c460d597`; current authorization `GATE 0 ONLY`. | Remains unchanged. It does not authorize implementation of Option B. |
| Issue #557, comments [6873972083](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6873972083) and [6893474669](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6893474669) | Technical assessment and review; neither is an adoption decision. | Evidence for architecture review and one integrity requirement, not owner authority. |
| Issue #557, owner decision [6909586126](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6909586126) | `OPTION_B_SUPPORT_WORKSPACE_ADOPTED`; author `JCSchoeman96`; active organization role `admin`; posted 2026-11-16. | Authenticated authority for adopting only the support-workspace architecture described in the exact replacement revision above. |

The October spec, November proposal, implementation plan, Gate A results, and replacement proposal remain unedited by this record. No historical document is invalidated. The replacement proposal remains labeled `PROPOSED — NOT ADOPTED` as a historical document; this ADR records the owner's adoption of that exact revision for the defined support-workspace scope.

## Architecture disposition

| Source architecture | Recorded effect of adoption |
| --- | --- |
| October support design | Keep its FastCheck support ownership, `SupportCase` and `SupportMessage` names, four case states, LiveView inbox direction, customer journey, and safety requirements. Replace only the simpler support-send lifecycle and resolution mechanics where they do not account for durable external-operation uncertainty or a serialized close fence. Preserve October's `waiting -> cancelled` administrative-close transition and its existing actor authority; the owner explicitly retained it in the adoption decision without assigning a new role. The existing October customer, resend, payment, ticket, inventory, and privacy requirements do not change. |
| November Chatwoot proposal | Reject its Chatwoot-owned assignment/transcript, `SupportHandoff`, `BridgeMessage`, and callback-based writable agent path for the MVP. It remains a historical proposed document, not an adopted decision. |
| November 14 replacement proposal | Adopt its FastCheck support architecture at the exact revision listed above, with the non-null identity requirements and retained October administrative-close transition stated in the owner decision. It does not replace either historical document wholesale. |

No historical file is rewritten, renamed, or labeled invalid.

The adopted proposal adds a `claimed -> waiting` assignee-release action that is not listed in the October state table. The owner explicitly included this additional transition by adopting the exact proposal revision.

## Adopted decision

Option B, the FastCheck-controlled Support Workspace, is adopted as the architecture direction for the support workspace only. FastCheck owns the canonical support transcript, agent reply acceptance, support-case lifecycle, message-dispatch state, and support close fence. Authorized agents use Phoenix LiveView. Chatwoot is not an MVP dependency, and the MVP has no Chatwoot mirror.

This direction preserves the October product and safety requirements. It does not approve implementation, migrations, production WhatsApp sends, infrastructure or deployment changes, a disposition for unknown Meta send outcomes, relaxed STOP/privacy rules, or full Gate A acceptance.

The adopted identity requirements are explicit: operator reply rows require non-null `provider_account_key` and `client_submission_id`; inbound `SupportMessage` and body-free customer `0` receipt rows require non-null `provider_account_key` and `provider_message_id`. Provider-account scope comes from verified channel configuration. Nullable composite unique indexes do not satisfy these requirements.

## Authority boundary

| Area | Authority after the verified owner adoption |
| --- | --- |
| Customer and commercial requirements | October 15 remains authoritative for navigation, the support journey, `0` exit, ticket resend, email OTP, ticket ownership, payment, inventory, privacy, STOP precedence, and commercial safeguards. |
| Support workspace architecture | The exact November 14 proposal revision above controls the specifically adopted support workspace architecture, with the owner-adopted non-null identity requirements stated in this record. |
| November 10 Chatwoot proposal | Remains a historical proposal. Its Chatwoot-owned transcript and write path are not selected for the MVP. |
| Implementation plan | The October plan remains `GATE 0 ONLY`. A new or revised implementation plan must be separately prepared and approved before coding. |
| Chatwoot Gate A | No result changes. `A01-A03=PASS (AI-only)`, `A04=PARTIAL`, `A05=PASS (receiver safeguards only)`, `A06=FAIL`, `A07=BLOCKED`, `A08-A14=NOT RUN`, and `FULL_GATE_A=NOT_ACCEPTED`. The replacement does not turn Chatwoot tests into passes. |

The October design remains controlling for its approved product and safety scope. This record makes the replacement authoritative only for the specifically adopted support-workspace architecture.

## Domain consistency check

The proposal keeps the approved `FastCheck.Support` boundary and `SupportCase` name. It does not add `SupportHandoff`, `BridgeMessage`, `SupportConversation`, or a second conversation aggregate. Assignment remains fields on `SupportCase`; it is not a separate resource.

| Resource | Verified lifecycle and boundary |
| --- | --- |
| `FastCheck.Support.SupportCase` | Owns `waiting`, `claimed`, `resolved`, and `cancelled`. `resolved` and `cancelled` are terminal. Transitions include customer intake to `waiting`, operator claim to `claimed`, the proposal's assignee release back to `waiting`, customer `0` to `cancelled`, the October administrative close from `waiting` to `cancelled`, and guarded resolution from `claimed` to `resolved`. Claim and resolution use the current case version. A later support engagement uses a new generation only under an approved reopen rule. |
| `FastCheck.Support.SupportMessage` | Owns the encrypted, append-only canonical transcript. Authorized operator acceptance commits the message, operation, audit event, sequence, and durable job together. Inbound receipts use the trusted account and provider message identity. |
| `FastCheck.Support.ExternalCreateOperation` | Owns each outbound Meta operation. Its states are `queued`, `dispatching`, `provider_accepted`, `failed_retryable`, `failed_permanent`, `suppressed_before_dispatch`, `retry_suppressed`, `outcome_unknown`, `reconciling`, and `needs_review`. Only proven non-acceptance permits a bounded retry. An unknown outcome is not retried blindly; it remains auditable and can block business resolution, but cannot block the customer's `0` exit. Provider acceptance and customer delivery remain distinct. |
| `FastCheck.Support.ConversationClosure` | Owns closure epochs with `requested`, `fenced`, `reconciling`, `resolved`, `recovery_required`, and `aborted` states. Resolved and aborted attempts are immutable. Resolution requires all pre-fence messages and required operations to have a known disposition. An unresolved outcome leaves closure in recovery; PubSub does not decide closure. |
| `FastCheck.Support.SupportCaseEvent` | Is append-only audit for case, message, operation, closure, and recovery decisions. Events commit with their state changes. Assignment history stays in events while current assignment stays on the case. |

The proposal's transaction guards, authorization policies, side effects, unique indexes, optimistic concurrency, and failure behavior are specified in §§5-8. The owner decision retains October's administrative-close transition using only the actor authority in the existing approved policy, and requires non-null submission and inbound-receipt identity fields because nullable indexes alone are insufficient.

`FastCheck.Sales.Conversation` remains the parent WhatsApp conversation and sales checkpoint. The reviewed proposal requires one transaction and this lock order: WhatsApp advisory lock, `Sales.Conversation`, `SupportCase`, `ConversationClosure`, then messages, operations, audit, and jobs. It requires durable inbound receipt and required work to commit before webhook acknowledgment. No external HTTP request occurs inside that transaction. Ash policy, transaction guards, database constraints, optimistic concurrency, ID-only Oban jobs, and after-commit PubSub remain required. Redis and ETS are rebuildable accelerators, not correctness authorities.

The proposal retains customer navigation and the email-first resend safeguards, with no change to order, payment, ticket, or inventory ownership. It preserves STOP/privacy precedence. If STOP authority cannot be read safely, support sends stay disabled. A queued send is suppressed when `0` or STOP wins before dispatch authorization. A request already in `dispatching` may still reach Meta, stays auditable and possibly unknown, and must not be described as recalled, rejected, or delivered without evidence.

## Owner policy register

These policies remain undecided. Architectural adoption would not approve them. The safe defaults below apply until the owner records each policy for the relevant implementation gate.

| Decision | Status and owner | Gate affected | Safe default |
| --- | --- | --- | --- |
| Meta ambiguous-send disposition and any provider reconciliation contract | Pending owner policy and exact API-version verification. | Before support sends and before recovery implementation. | No blind retry; keep outcome unknown and require review. |
| Whether resolution requires provider acceptance or customer delivery | Pending owner policy. | Closure and release acceptance. | Do not claim delivery; do not resolve a case with required operations still unknown. |
| Durable STOP/consent authority | Pending owner identification and source verification. | Before any support send. | Fail closed; disable support sends if the durable authority is unavailable. |
| Customer notice when a dispatch-authorized send may arrive after `0` or STOP | Pending owner copy and policy. | Customer exit and privacy behavior. | Keep the approved safe exit; do not promise recall or non-delivery. |
| Reopen and new-case-generation rules | Pending owner policy. | Support lifecycle implementation. | Do not reopen a terminal case or create a new generation without an approved rule. |
| Single WhatsApp account boundary | Pending owner confirmation. | Initial release and any multi-account expansion. | Limit to one configured account; do not enable multiple accounts. |
| Named operator identities | Pending owner approval of distinct, stable identities. | Multi-agent production use and audit. | Do not claim individual attribution or enable shared-identity multi-agent production. |
| Encryption keys, retention, deletion, and backup | Pending owner policy. | Production transcript storage and operations. | No production transcript retention until key lifecycle and retention rules are approved. |
| Workload, latency, failover, and recovery targets | Pending owner targets and evidence. | Performance qualification and deployment. | Make no 100k concurrency or capacity claim; do not release without approved targets and measurements. |
| Actor authority for October's administrative close of a waiting case | The October transition is approved, but the acting role must come from the existing support authorization policy; this record does not assign a new role. | Support lifecycle implementation. | Do not enable administrative close until the existing authorized actor policy is verified; preserve customer `0` exit. |

## Performance and safety limits retained

Postgres is the durable authority for acceptance, operation state, and closure. Ash actions and policies guard writes. Unique constraints, non-null identity checks, optimistic concurrency, and the shared lock order enforce correctness. Oban receives internal IDs only. Redis, ETS, and PubSub are rebuildable or post-commit mechanisms. Queries remain indexed and bounded; transcript reads use keyset pagination. No plaintext, PII, credentials, or provider payloads enter logs, job arguments, caches, metrics, or PubSub. The October 100k-user target and all performance and recovery targets remain unverified until measured against owner-approved limits.

## Required implementation-planning gate

The October plan's `GATE 0 ONLY` authorization remains in force. The next separate task is to prepare a revised or replacement implementation plan for Option B. That planning task must preserve the October requirements, carry the owner policy register and non-null identity checks, define gated phases and acceptance tests, and receive its own owner approval. It must not start implementation. Coding, migrations, runtime tests, production sends, and deployment each remain outside this decision.

Do not close issue #557 or modify the historical Chatwoot Gate A verdict through this record.

## Recorded owner decision

The authenticated owner decision is [GitHub issue #557 comment 6909586126](https://github.com/Carpe-Diem-Media/FastCheckin/issues/557#issuecomment-6909586126), posted by `JCSchoeman96` on 2026-11-16. GitHub reports the author as an active organization admin. The decision adopts the exact replacement proposal revision in the source table for support-workspace architecture only and explicitly retains the October requirements, the two identity constraints, and the `waiting -> cancelled` administrative close.

## Current result

`OPTION_B_SUPPORT_WORKSPACE_ADOPTED` for the support-workspace architecture only. Implementation, migrations, production sends, infrastructure, deployment, and release remain unauthorized. The owner policy register remains pending, and the Chatwoot Gate A verdict remains unchanged: `A01-A03=PASS (AI-only)`, `A04=PARTIAL`, `A05=PASS (receiver safeguards only)`, `A06=FAIL`, `A07=BLOCKED`, `A08-A14=NOT RUN`, `FULL_GATE_A=NOT_ACCEPTED`.
