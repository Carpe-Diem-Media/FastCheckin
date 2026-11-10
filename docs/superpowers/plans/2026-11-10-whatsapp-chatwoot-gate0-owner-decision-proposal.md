# FastCheck WhatsApp/Chatwoot Gate 0 Owner Decision Proposal

| Field | Value |
|---|---|
| Document ID | FASTCHECK-WA-CHATWOOT-GATE0-DECISION-001 |
| Version | 0.1.2 |
| Date prepared | 2026-11-10 |
| Status | PROPOSED — UNSIGNED |
| Repository baseline | `e5ec24e53d44b0cebd472c1a05f138f314bb337f` |
| Architecture reference | `docs/superpowers/specs/2026-11-10-whatsapp-flows-chatwoot-integration-design.md`, v0.2.3, Proposed |
| Plan reference | `docs/superpowers/plans/2026-10-15-whatsapp-customer-service-resend.md`, approved plan plus proposed Chatwoot appendix |
| Candidate spec Git blob | `953d9d77eca1afbc6405cd032eac5619dbbf6e29` |
| Candidate plan Git blob | `a77a0842c3d8cd93ff76e6c5f6ee176d76f6220f` |
| Superseded proposal Git blob | `8d722a91fcc0ea7fc841ae3feda8274d1074168b` |
| Implementation authorization | NO |
| Effective date | Pending owner approval |

> This is a decision proposal, not an approval record. It does not change the current authority, authorize implementation, or establish that any policy has been approved.

## Revision history

| Version | Change |
|---|---|
| 0.1.1 | Separates queued intent, fresh per-attempt consent authorization, Meta attempt start, and provider outcome; adds delayed-worker race acceptance criteria and records unresolved historical-consent and paid-ticket fulfillment decisions. H1 and H3 recommendations remain unchanged. |
| 0.1.2 | Pins the exact CG-1-enabled plan blob, names CG-1 as the H2 outbound prerequisite, and clarifies the signed authority precedence for no-send Support Gate A feasibility work. |

## 1. Purpose and current authority

This proposal gives the owner explicit H1-H3 decisions for Gate 0: the support workspace and task replacement, durable WhatsApp opt-out/re-consent behavior, and disposition of held support messages. It also defines the precedence a signed amendment would have over the October 15 plan.

At the recorded baseline, the October 15 plan remains approved for gated execution, with Gate 0 as the only current authorization. The current source recognizes a standalone `STOP` input and applies state-specific handling. The reviewed source does not establish a durable, global opt-out authority for all WhatsApp send paths. The Chatwoot integration spec and its appended plan amendment remain proposals until approved.

Gate 0 closes only after H1, H2, and H3 are each explicitly approved, all required policy fields below are completed, the exact document revisions are recorded, and the owner signs this amendment with an effective date. A partial, conditional, blank, or unsigned decision leaves Gate 0 open and does not supersede any October task.

## 2. H1 — support workspace and task replacement

**Recommendation: `RECOMMEND_APPROVE` Option A.**

Keep FastCheck as the only Meta webhook owner and WhatsApp sender, and as the authority for customer binding, routing, orders, checkout, Paystack verification, inventory, ticket issuance, and resend. Use Chatwoot API Inbox for the human-support workspace and transcript after the separately authorized Support Gate A verifies the selected self-hosted Community Edition contract.

The task map is:

| October 15 task | Proposed decision | Instruction after this amendment takes effect |
|---|---|---|
| Gate 0, Task 0.1 — canonical signed authority documents | Retain and complete with the signed decision amendment. | Record the exact approved spec and plan revisions, owner, signature, and effective date. No implementation authorization follows from Gate 0 closure. |
| Gate A, Tasks A1-A2 — navigation and contextual `0` | Retain unchanged. | Continue to follow the October task definitions and their existing commercial/order safeguards. |
| Gate B, Tasks B1-B6 — email-first resend and one-ticket selection | Retain unchanged. | Continue to follow the October task definitions. Chatwoot does not change resend proof, candidate binding, OTP, or ticket-delivery authority. |
| Gate C, Tasks C1-C4 — support records, encryption, routing, queue mirrors/PubSub | Supersede only after H1-H3 approval and signature. | Do not execute the old SupportCase/SupportMessage, custom queue, or queue-mirror instructions. Use the approved Support Gates for those responsibilities. |
| Gate D, Tasks D1-D5 — custom inbox, claim, case history, outbound worker, resolution UI | Supersede only after H1-H3 approval and signature. | Do not build the FastCheck agent inbox, custom operator queue/claim UI, or its reply interface. Use Chatwoot for agents and the approved FastCheck bridge for routing and Meta delivery. |
| Gate E, Tasks E1-E3 — sandbox fixture and certification | Retain. | Keep the supported fixture, Paystack test-only rule, evidence matrix, and certification sequence. Exercise human support through the approved Chatwoot bridge. These tasks grant no production or deployment authority. |
| WhatsApp Flows | Remain deferred. | No Flow work is included in this decision or the support MVP. |

The replacement Support Gates 0 and A-F in the proposed Chatwoot appendix are the sole implementation instructions for the superseded C1-C4 and D1-D5 responsibilities once this amendment is effective. The old task text remains in the October plan as history and must be marked **superseded — do not execute** in the signed authority index or revision record. Agents must not choose between the old and replacement instructions themselves.

H1 approval adopts the task map above; it does not authorize Chatwoot installation, Meta configuration, application changes, migrations, deployment, or production traffic. Each later gate requires its own authorization.

**H1 owner decision:**

- [ ] APPROVE Option A and the task map above.
- [ ] REJECT; retain the October custom-support tasks.
- [ ] REVISE; record exact task IDs and requested changes: ____________________

## 3. H2 — durable STOP, opt-out, and re-consent policy

**Status: `PROPOSED_POLICY`; owner and policy review required.**

### 3.1 Proposed global STOP rule

Treat a recognized, unqualified `STOP` (or an owner-approved equivalent opt-out request) as a request to stop future outbound WhatsApp messages from the identified FastCheck business number to that verified customer WhatsApp identity. Apply it before support or Sales routing. Do not store or forward the STOP text as support content. A normal later inbound message, a new order, or a support request does not by itself restore WhatsApp permission.

An unqualified STOP applies as a global outbound deny across marketing, support, and transactional message categories. No category is an automatic exception. If fulfilling an existing order requires customer communication, preserve FastCheck's order, payment, inventory, and ticket truth; use another channel only when its existing authority permits it. Do not substitute a WhatsApp template or create a new delivery exception to bypass the opt-out.

### 3.2 Proposed durable consent lifecycle

Persist the consent decision in a durable FastCheck authority, independent of SupportHandoff and event-specific Sales state. Scope it to the verified recipient identity and the FastCheck business WhatsApp number, across events and support episodes. Keep an audit history of state changes and evidence. The specific resource, protected identity representation, retention period, and approved privacy basis must be selected and recorded before implementation; no new resource is implemented or assumed by this proposal.

| State | Allowed transition | Required guard and effect |
|---|---|---|
| `unverified` | `opted_in` | Only an explicit, auditable consent event through an owner-approved process. Record the evidence and the allowed category scope. A purchase, inbound message, or operator assumption is not consent evidence. |
| `unverified` or `opted_in` | `opted_out` | A recognized STOP or equivalent request. Record the durable deny immediately for all WhatsApp categories and create an audit event without retaining the STOP body as support text. |
| `opted_out` | `reconsent_pending` | Only an explicit customer-initiated re-consent request through the owner-approved, identity-verified process. Ordinary inbound messages do not trigger this transition. Do not send a WhatsApp verification prompt while opted out. |
| `reconsent_pending` | `opted_in` | Only after the approved verification succeeds. Record the evidence, actor/system, time, and categories the customer explicitly accepted. Do not infer permission for categories not covered by that evidence. |
| `reconsent_pending` | `opted_out` | On failed verification, customer cancellation, or expiry. Expiry returns to the opted-out state; it never releases the deny. |
| `opted_in` | `opted_out` | A later recognized STOP or equivalent request takes precedence over every category grant. |

There is no automatic expiry from `opted_out` to an allowed state and no permanently terminal customer identity. Only the approved re-consent process can restore explicitly granted categories. An operator cannot clear opt-out by editing a support case or conversation. Any exceptional administrative authority, if the owner wants one, must be separately specified and audited; it is not part of this proposal.

The consent record is authoritative in Postgres. A cache, job, queue, Chatwoot field, or per-event flag cannot grant permission. Store only the minimum evidence needed to enforce and audit the decision. Retain the suppression record for the owner-approved period; if privacy rules require removal of detailed evidence, retain an approved suppression-safe record so deletion does not silently re-enable messaging.

### 3.3 Categories and unresolved policy fields

Record separate category scope for **marketing**, **support**, and **transactional** messages. The global `opted_out` state denies every category, regardless of the message's purpose. An `opted_in` record grants only categories supported by its evidence. `unverified` is not affirmative consent; outbound eligibility for that state must follow an identified, separately approved category policy. Do not infer an exception from an active order, a 24-hour service window, or a Chatwoot agent's judgment.

Before H2 can be approved, the owner must record:

- the policy owner and source path for recognized STOP/equivalent language and identity matching;
- the allowed outbound behavior for each category while state is `unverified` and the approved mapping for existing customers;
- the historical consent-evidence inventory and migration rule, including provenance and identity matching; missing or ambiguous evidence must not be bulk-mapped to `opted_in` without an owner-approved basis;
- the exact re-consent journey, identity verification, category wording, and who/what may record the result;
- whether a one-time STOP confirmation is allowed, its exact approved text, channel, and idempotency key; absent explicit approval, send no confirmation;
- the opt-out audit and retention/deletion schedule, including how suppression remains effective after evidence minimization; and
- the permitted alternative channel and controlling authority for delivery of a paid ticket after WhatsApp opt-out; do not assume a fallback or change ticket-delivery authority.

If those rules cannot be agreed without changing the existing commercial delivery authority, record `STOP=COMMERCIAL_INVARIANT_CHANGE` and defer the affected behavior for a separate owner decision. Do not treat that conflict as permission to weaken the opt-out.

### 3.4 Shared outbound suppression and STOP/dispatch race

The future implementation must enforce consent at the shared FastCheck WhatsApp outbound authorization boundary used by sales, support, resend, ticket/payment delivery, system notices, and retries. A Chatwoot-only check is insufficient. Chatwoot never sends directly to Meta.

Upon signed H2 approval, Global WhatsApp Consent Gate CG-1 is the mandatory implementation prerequisite for all new or modified WhatsApp outbound send paths. H2 approval does not itself authorize CG-1 implementation; CG-1 requires its separate gate authorization and must pass before any such send path is implemented or changed. Support Gate A may proceed independently only as an explicitly authorized no-send feasibility exercise.

Keep these steps and records distinct:

1. **Queued dispatch intent:** a durable request to consider a send. It is not consent approval or permission to call Meta. It may be delayed, restarted, re-enqueued, or claimed by another worker without carrying any send authorization.
2. **Final per-attempt consent authorization:** only after a worker claims the queued intent and is ready to send, the shared send boundary re-reads the durable consent decision under the same per-business-number/recipient concurrency guard used to commit STOP. If STOP has committed, the attempt is blocked and no Meta call is made. Otherwise, issue a short-lived, single-use authorization bound to the exact recipient, message/attempt identity, consent revision, and attempt number. It is not issued at enqueue/prefetch, serialized in a job, cached for another attempt, or reusable after restart, worker handoff, expiry, or delay.
3. **Meta attempt start:** consume that authorization once and invoke `FastCheck.Messaging.WhatsApp.Client` immediately in the same worker execution. If execution pauses, ownership changes, or the authorization expires before invocation, discard it and repeat final consent authorization. A retry is a new attempt and always requires a fresh authorization.
4. **Provider outcome:** exact provider acceptance and WAMID evidence records `meta_accepted`; a timeout, crash, or response that cannot establish acceptance remains `recovery_required`/unknown. A queued intent or authorization is never provider evidence.

Serialize STOP persistence and final consent authorization for the same business-number/recipient identity with a durable concurrency guard. The outcomes are:

- If STOP commits before final consent authorization, the worker records a blocked/suppressed outcome and makes no Meta call.
- If STOP commits while a worker is delayed after the earlier queued intent, the worker must revalidate, observe `opted_out`, and make no Meta call. The old queue intent cannot be promoted into permission.
- If STOP commits after final authorization but before the worker immediately invokes the client, the database check and external HTTP start cannot be made atomic. Minimize this interval, document it, and treat the attempt as potentially in flight once it crosses the immediate authorization-to-client boundary. Do not describe this narrow race as a transactional guarantee.
- If the Meta client request has started, STOP cannot recall it. Persist the opt-out, prohibit every later attempt and retry, and reconcile the actual response/status. An ambiguous result stays unknown; do not mark it cancelled, accepted, delivered, or read without evidence.

An `authorization_granted` record or in-memory permit is not reusable permission. The implementation must define a short expiry without choosing a value in this proposal, invalidate permits on consent-revision change, and ensure a restarted or delayed worker cannot resume with the prior permit. Do not hold a database transaction open across a Meta network request. Audit the consent revision, attempt identity, authorization time, actual client-start boundary, and provider result without recording message plaintext or raw customer identifiers.

#### Proposed acceptance criteria for the STOP/dispatch race

- A durable queued intent followed by STOP and then a delayed worker results in no authorization and no Meta client invocation.
- A worker restart, lost claim, expired permit, queue retry, or attempt retry cannot reuse a prior authorization; each actual attempt performs a fresh consent read.
- If STOP commits before the final authorization transaction, no client call occurs even if the message was previously queued or marked dispatching by a scheduling system.
- A controlled test pauses the worker after an old intent, commits STOP, resumes the worker, and proves the send is suppressed.
- A separate boundary test records the narrow interval between final authorization and HTTP invocation, proves the attempt is single-use, and verifies that any started/ambiguous call is reconciled without claiming recall or retrying after STOP.
- Provider acceptance is recorded only from exact provider evidence; unknown outcomes remain recoverable and never become a fabricated cancellation or delivery receipt.

**H2 owner decision:**

- [ ] APPROVE this proposed policy after every field in §3.3 is completed and reviewed.
- [ ] REJECT; identify the controlling alternative policy and exact authority path: ____________________
- [ ] REVISE; attach the replacement state transitions, category rules, and race behavior: ____________________

## 4. H3 — held-message disposition on support exit

**Status: `PROPOSED_POLICY`; owner approval required.**

### 4.1 Customer exit (`0` / retained `#`)

Recommend that a customer exit closes the current support episode without carrying messages into another episode:

- Cancel customer-to-Chatwoot BridgeMessages still `queued` or `held` and not accepted by Chatwoot. Record `cancelled` with the exit reason, handoff ID, and source-message identity. Keep ciphertext only for the owner-approved retention interval, then delete it while retaining the minimum audit evidence.
- Cancel pre-dispatch agent/system-to-WhatsApp BridgeMessages that are still queued. Do not admit new agent replies after the close fence.
- Do not mark a Chatwoot-accepted inbound message cancelled or delete it from Chatwoot as part of exit. Its transcript status and any deletion request follow the separately approved retention/privacy process.
- Do not cancel a Meta dispatch already in progress. Reconcile its provider result; do not claim recall. Do not retry an ambiguous or accepted send.
- Do not carry a cancelled BridgeMessage into a successor episode. A later support request starts a new episode with new inbound message identities.

The cancellation is a delivery/routing disposition, not immediate physical deletion. It must satisfy the v0.2.3 close barrier: every held inbound record has an explicit disposition before the handoff becomes terminal. Existing orders, payments, tickets, unrelated `needs_human` reasons, and commercial state are unaffected.

### 4.2 STOP after H2 is approved

Recommend that the durable global opt-out is committed before any support close or reply routing:

- Suppress and cancel, with an audited opt-out disposition, all unsent queued agent/system WhatsApp replies and all queued/held support payloads not yet accepted by Chatwoot. Do not forward a held payload to Chatwoot after STOP.
- Do not delete Chatwoot-accepted messages or assert that Meta-accepted messages were recalled. Follow the approved retention policy for stored content and reconcile in-flight provider outcomes.
- Do not carry canceled payloads into a later support episode. A new episode requires a new customer request after an approved re-consent, and uses new BridgeMessage records.
- Send no opt-out confirmation unless H2 explicitly approves the one-time message, its exact copy, channel, and an audited single-use exception to ordinary outbound suppression.
- Keep the handoff nonterminal while any dispatch, callback-order, held-message, or provider-outcome item remains unresolved. The v0.2.3 close barrier remains in force.

If privacy policy requires deletion, the system records the approved cancellation/deletion disposition and removes encrypted body content on the approved schedule. Until that policy is approved, retain the body encrypted, do not forward it, and do not terminalize the handoff on the assumption that it may be discarded.

### 4.3 Owner selections

For customer exit, the owner must approve the exact customer-facing exit response or explicitly choose no response. Do not invent or send exit copy. The STOP confirmation decision remains governed by H2 and defaults to no WhatsApp confirmation without explicit approval. The owner must also complete the retention/deletion schedule for each trigger.

| Trigger | Proposed disposition | Owner decision |
|---|---|---|
| Customer exit (`0` / retained `#`) | Cancel queued/held undelivered support content with an audited reason; do not carry it into a successor episode. Reconcile any already-dispatching reply. | Pending |
| STOP after H2 policy takes effect | Commit opt-out first; suppress/cancel unsent content under the approved retention rule; do not carry it forward. Reconcile already-dispatching work without claiming recall. | Pending |

**H3 owner decision:**

- [ ] APPROVE both proposed dispositions and complete the retention/deletion schedule.
- [ ] APPROVE only customer-exit behavior; STOP disposition remains pending.
- [ ] APPROVE only STOP behavior; customer-exit disposition remains pending.
- [ ] REVISE; specify per-trigger disposition, approved exit notice or no-notice choice, and retention rules: ____________________

A partial H3 approval does not close Gate 0 or permit implementation of the unresolved trigger path.

## 5. Signed-authority precedence and effective date

This is a separate, versioned amendment proposal so implementers do not have to infer precedence from the October task text and the proposed Chatwoot appendix.

If and only if H1, H2, and H3 are approved, the required policy fields are completed, and this amendment is signed with an effective date:

1. This signed amendment and the exact approved v0.2.3 architecture spec become the controlling authority for the Chatwoot support-workspace decision and H2/H3 policy.
2. October 15 Gate C Tasks C1-C4 and Gate D Tasks D1-D5 are **superseded and must not be executed**. Their old wording remains historical context only.
3. The proposed Support Gates in the exact signed plan revision become the sole implementation instructions for those replaced C/D responsibilities. Name that plan revision and its Git commit/blob at signing; do not rely on a mutable filename alone.
4. October 15 Gate A Tasks A1-A2, Gate B Tasks B1-B6, and Gate E Tasks E1-E3 remain in force as mapped in H1. This amendment does not change commercial, resend, navigation, sandbox, or Paystack authority.
5. The prior proposed appendix is not independently effective. If it conflicts with this signed decision amendment, this amendment controls for H1-H3 and C/D precedence. The signed plan revision controls gate execution details within those approved decisions.
6. Approval closes only Gate 0. No application changes, migrations, Chatwoot installation, Meta configuration, secrets, deployment, or production activity are authorized. Each next gate needs a separate written authorization.
7. Upon signed H2 approval, Global WhatsApp Consent Gate CG-1 is the mandatory implementation prerequisite for all new or modified WhatsApp outbound send paths. Support Gate A may proceed independently only as an explicitly authorized no-send feasibility exercise.

If any H decision is rejected, conditional, unsigned, or missing its required policy fields, none of the supersession clauses take effect. The October 15 plan remains the authority, current authorization remains Gate 0 only, and implementation must stop for owner direction.

## 6. Approval record — intentionally blank

Do not treat this proposal as signed. The owner completes the record only after reviewing the exact candidate documents.

| Approval field | Owner completion |
|---|---|
| H1 decision | Pending |
| H2 decision and policy authority path | Pending |
| H3 customer-exit disposition and retention rule | Pending |
| H3 STOP disposition and retention rule | Pending |
| Exact spec version and Git blob/commit | Pending |
| Exact signed plan revision and Git blob/commit | Pending |
| Owner name and authority | Pending |
| Signature | Pending |
| Effective date | Pending |
| Next separately authorized gate | None |

## 7. Gate 0 status

Stop if the baseline or authority changes before signature, if the consent authority or category rules remain unresolved, or if an exception is proposed without explicit approval. The implementation gates must also stop if the approved opt-out policy would require an unapproved commercial invariant change or application work without separate authorization.

Current Gate 0 remains open for `STOP=OWNER_POLICY_DECISION_REQUIRED`. Conditional stop guards are `STOP=MAIN_MOVED` if the recorded baseline changes, `STOP=CONSENT_EXCEPTION_ASSUMED` if any unapproved message exception is inferred, `STOP=COMMERCIAL_AUTHORITY_CHANGED` if the proposal changes commercial ownership, `STOP=POLICY_VALUES_INVENTED` if an unresolved policy value is filled without owner authority, and `STOP=NON_DOC_CHANGE` if this task changes anything beyond documentation. Application work requires a later gate authorization; until then use `STOP=APPLICATION_CHANGE_REQUIRED` for any attempted implementation.

```text
DOCUMENT_STATUS=PROPOSED_UNSIGNED
H1=RECOMMEND_APPROVE
H2=PROPOSED_POLICY_AWAITING_OWNER_APPROVAL
H3=PROPOSED_POLICY_AWAITING_OWNER_APPROVAL
AUTHORITY_PRECEDENCE=NOT_EFFECTIVE
GATE_0=OPEN
SUPPORT_GATE_A=NOT_AUTHORIZED
IMPLEMENTATION_AUTHORIZED=NO
PRODUCTION_AUTHORIZED=NO
MERGE_RECOMMENDATION=NO
STOP=OWNER_POLICY_DECISION_REQUIRED
STOP=DECISION_RECORD_CORRECTED
```
