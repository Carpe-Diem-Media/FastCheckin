# FastCheck WhatsApp/Chatwoot Gate 0 Owner Decision Proposal

| Field | Value |
|---|---|
| Document ID | FASTCHECK-WA-CHATWOOT-GATE0-DECISION-001 |
| Version | 0.1.5 |
| Date prepared | 2026-11-10 |
| Status | PROPOSED — APPROVAL IN PRINCIPLE RECORDED; UNSIGNED |
| Repository baseline | `e5ec24e53d44b0cebd472c1a05f138f314bb337f` |
| Architecture reference | `docs/superpowers/specs/2026-11-10-whatsapp-flows-chatwoot-integration-design.md`, v0.2.3, Proposed |
| Plan reference | `docs/superpowers/plans/2026-10-15-whatsapp-customer-service-resend.md`, approved plan plus proposed Chatwoot appendix |
| Candidate spec Git blob | `953d9d77eca1afbc6405cd032eac5619dbbf6e29` |
| Candidate plan Git blob | `fec12201d12a97e9117e415aa3778eac8fdb5ef9` |
| Superseded proposal Git blob | `8d722a91fcc0ea7fc841ae3feda8274d1074168b` |
| Implementation authorization | NO |
| Effective date | Pending owner approval |

> This unsigned proposal records the owner's approval in principle for H1-H3 and the bounded customer-initiated service direction in §3.3. It is not the completed approval record, does not change the current authority, does not close Gate 0, and does not authorize implementation, production sending, or a legal exception.

## Revision history

| Version | Change |
|---|---|
| 0.1.1 | Separates queued intent, fresh per-attempt consent authorization, Meta attempt start, and provider outcome; adds delayed-worker race acceptance criteria and records unresolved historical-consent and paid-ticket fulfillment decisions. H1 and H3 recommendations remain unchanged. |
| 0.1.2 | Pins the exact CG-1-enabled plan blob, names CG-1 as the H2 outbound prerequisite, and clarifies the signed authority precedence for no-send Support Gate A feasibility work. |
| 0.1.3 | Records H1-H3 approval in principle, adds proposed defaults for unresolved consent and support-exit policies, and keeps all unresolved values and formal approval pending. |
| 0.1.4 | Records the greenfield launch basis, removes historical consent migration and customer re-verification from development dependencies, records the bounded first-contact service direction, and preserves October Gate B as incomplete required work. |
| 0.1.5 | Reconciles CG-1 historical handling with the greenfield launch: a provenance-verified zero-genuine-recipient inventory makes historical backfill N/A; genuine or unclassifiable recipients block live release pending an owner-approved migration rule. The new consent schema migration remains required. |

## 1. Purpose and current authority

This proposal gives the owner explicit H1-H3 decisions for Gate 0: the support workspace and task replacement, durable WhatsApp opt-out/re-consent behavior, and disposition of held support messages. It also defines the precedence a signed amendment would have over the October 15 plan.

At the recorded baseline, the October 15 plan remains approved for gated execution, with Gate 0 as the only current authorization. The current source recognizes a standalone `STOP` input and applies state-specific handling. The reviewed source does not establish a durable, global opt-out authority for all WhatsApp send paths. The Chatwoot integration spec and its appended plan amendment remain proposals until approved.

### Owner approval in principle recorded 2026-11-10

| Decision | Owner position | Scope and effect |
|---|---|---|
| H1 | APPROVED IN PRINCIPLE: Chatwoot human support is required for the agreed MVP; use FastCheck + Chatwoot Option A. | FastCheck retains Meta transport and commercial authority. Chatwoot provides the human-support workspace after Gate A. It does not supersede the October plan or authorize Gate A or implementation. |
| H2 | APPROVED IN PRINCIPLE: durable global WhatsApp STOP/opt-out, category-scoped permission, and bounded replies to a customer-initiated service exchange. | STOP denies all WhatsApp categories. A direct service reply to the customer's active request is allowed only inside the valid service window; it does not create durable `opted_in` consent. Marketing broadcasts are out of MVP. Transaction-specific boundaries and launch-only policy values remain listed in §3.3. |
| H3 | APPROVED IN PRINCIPLE: audited cancellation of unsent support content. | Supports audited cancellation of queued/held content that has not been accepted or dispatched. Already accepted or in-flight external work must be reconciled, not called cancelled. Exact customer response and retention remain pending. |
| Greenfield basis | OWNER-CONFIRMED: FastCheck has not launched and has no real historical customer base. | Historical consent backfill and existing-customer re-verification are not development dependencies. Before live messaging, verify the launch environment with a read-only inventory and documented provenance. A verified zero genuine recipients makes historical backfill N/A. Genuine recipients or records whose provenance cannot distinguish a test contact from a customer stop live release pending a new owner-approved migration rule. A nonzero raw row count alone does not establish a genuine customer. The new Postgres consent schema migration remains required. |
| Resend | October Gate B remains required and incomplete. | Current name-first resend code and existing email OTP do not satisfy the approved email-first, post-verification one-ticket selection design. |

Approval in principle records direction only. It does not count as the completed H1-H3 approval, activate task supersession, authorize a send path, or establish legal or provider permission. The formal decision selections, owner authority, signature, and effective date remain blank below.

Gate 0 closes only after the owner formally approves H1-H3, resolves the Gate 0 and CG-1 implementation-policy prerequisites, records the exact document revisions, and signs this amendment with an effective date. The actual recipient inventory and any conditional historical migration are pre-release requirements; they are not required to close Gate 0 or begin separately authorized development. Before live messaging, the verified inventory must establish zero genuine recipients or, if genuine recipients exist, the owner-approved migration must be completed. Unclassifiable records require owner review and continue to block release. Values marked as production-release decisions may remain pending during development, but they authorize no send and block production release. Approval in principle alone does not meet these conditions. Until signature, Gate 0 stays open and no October task is superseded.

## 2. H1 — support workspace and task replacement

**Owner position: `APPROVED IN PRINCIPLE` for Option A and the task map. Formal approval remains pending.**

Keep FastCheck as the only Meta webhook owner and WhatsApp sender, and as the authority for customer binding, routing, orders, checkout, Paystack verification, inventory, ticket issuance, and resend. Use Chatwoot API Inbox for the human-support workspace and transcript after the separately authorized Support Gate A verifies the selected self-hosted Community Edition contract.

The task map is:

| October 15 task | Proposed decision | Instruction after this amendment takes effect |
|---|---|---|
| Gate 0, Task 0.1 — canonical signed authority documents | Retain and complete with the signed decision amendment. | Record the exact approved spec and plan revisions, owner, signature, and effective date. No implementation authorization follows from Gate 0 closure. |
| Gate A, Tasks A1-A2 — navigation and contextual `0` | Retain unchanged. | Continue to follow the October task definitions and their existing commercial/order safeguards. |
| Gate B, Tasks B1-B6 — email-first resend and one-ticket selection | Retain unchanged and incomplete. | Complete the October task definitions. Current code still enters `collecting_resend_name`; the present email OTP path is not the approved email-first, post-verification one-ticket selection flow. Chatwoot does not change resend proof, candidate binding, OTP, or ticket-delivery authority. |
| Gate C, Tasks C1-C4 — support records, encryption, routing, queue mirrors/PubSub | Supersede only after H1-H3 approval and signature. | Do not execute the old SupportCase/SupportMessage, custom queue, or queue-mirror instructions. Use the approved Support Gates for those responsibilities. |
| Gate D, Tasks D1-D5 — custom inbox, claim, case history, outbound worker, resolution UI | Supersede only after H1-H3 approval and signature. | Do not build the FastCheck agent inbox, custom operator queue/claim UI, or its reply interface. Use Chatwoot for agents and the approved FastCheck bridge for routing and Meta delivery. |
| Gate E, Tasks E1-E3 — sandbox fixture and certification | Retain. | Keep the supported fixture, Paystack test-only rule, evidence matrix, and certification sequence. Exercise human support through the approved Chatwoot bridge. These tasks grant no production or deployment authority. |
| WhatsApp Flows | Post-launch deferral. | Flow purchase UX requires a separate post-launch design and release gate. No Flow work is included in the support MVP. |

The replacement Support Gates 0 and A-F in the proposed Chatwoot appendix are the sole implementation instructions for the superseded C1-C4 and D1-D5 responsibilities once this amendment is effective. The old task text remains in the October plan as history and must be marked **superseded — do not execute** in the signed authority index or revision record. Agents must not choose between the old and replacement instructions themselves.

Formal H1 approval would adopt the task map above; approval in principle does not. Neither status authorizes Chatwoot installation, Meta configuration, application changes, migrations, deployment, or production traffic. Each later gate requires its own authorization.

**H1 owner decision:**

- [ ] APPROVE Option A and the task map above.
- [ ] REJECT; retain the October custom-support tasks.
- [ ] REVISE; record exact task IDs and requested changes: ____________________

## 3. H2 — durable STOP, opt-out, and re-consent policy

**Owner position: `APPROVED IN PRINCIPLE` for durable global WhatsApp STOP/opt-out and bounded customer-initiated service replies. Launch-only values and formal approval remain pending.**

### 3.1 Proposed global STOP rule

Treat a recognized, unqualified `STOP` (or an owner-approved equivalent opt-out request) as a request to stop future outbound WhatsApp messages from the identified FastCheck business number to that verified customer WhatsApp identity. Apply it before support or Sales routing. Do not store or forward the STOP text as support content. A normal later inbound message, a new order, or a support request does not by itself restore WhatsApp permission.

An unqualified STOP applies as a global outbound deny across marketing, support, and transactional message categories. No category is an automatic exception. STOP suppresses WhatsApp delivery; it does not change payment verification, inventory, or ticket issuance under FastCheck's existing commercial rules. An otherwise valid paid ticket must not be cancelled, delayed, or left unissued because WhatsApp delivery is suppressed. Alternative retrieval is a separate channel decision and is permitted only under an independently approved authority. Do not substitute a WhatsApp template or create a new delivery exception to bypass the opt-out.

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

### 3.3 Category policy and launch decisions

The owner approves this bounded first-contact direction for the greenfield MVP: an `unverified` recipient may receive direct service replies to the customer's active, customer-initiated WhatsApp exchange while the latest trusted inbound timestamp passes the strict service-window check. This reply eligibility does not change the durable state to `opted_in`, grant permission for marketing, or authorize unrelated or later business-initiated messages. A recognized STOP overrides it and denies every WhatsApp category. This records the owner's product direction; it does not claim legal authorization or replace applicable provider rules.

The strict service-window check requires a valid trusted inbound timestamp and a nonnegative elapsed duration no greater than 24 hours. Missing, malformed, future, or out-of-range timestamps do not open the window. Recheck immediately before each Meta attempt. A server-time fallback cannot establish the customer's service window.

Record separate evidence and permission scope for **marketing**, **support**, and **transactional** messages. An `opted_in` record grants only evidenced categories. Marketing broadcasts are excluded from the MVP. Business-initiated messages require category-specific evidence. The exact treatment of payment links and ticket delivery inside or outside a customer-initiated purchase exchange remains a launch-only decision; do not silently classify those messages as service replies or invent an exception after STOP.

| Topic | Direction recorded for the MVP | Pending decision or release guard |
|---|---|---|
| Explicit `opted_out` | Hard deny all WhatsApp outbound categories. The recognized `STOP` command takes effect before routing. No order, service-window, support-agent, or template exception. A repeated STOP is idempotent. STOP during `reconsent_pending` returns to and preserves `opted_out`. | Define any additional opt-out phrases and finish recipient identity matching before production release. |
| `unverified`, customer-initiated service | Allow direct replies to the active customer-initiated service exchange only while a valid, trusted inbound timestamp passes the strict service-window check. Do not create a durable `opted_in` grant. | Before release, decide whether payment-link and ticket-delivery messages in that exchange fall within this approved scope. Until then, do not infer their eligibility. |
| `unverified`, business-initiated messages | No marketing broadcasts in MVP. Do not send other business-initiated categories without category-specific evidence. An order, payment, ticket, inbound message, or prior delivery is not evidence by itself. | Final category map and evidence requirements for any business-initiated transactional message. |
| `opted_in` | Permit only categories supported by durable consent evidence, subject to all other WhatsApp and business rules. | Approve consent wording and evidence standard before production release. |
| Historical migration and re-verification | Not a development dependency. Historical backfill is `N/A` only after a read-only inventory verifies zero genuine pre-existing customer recipients in the launch environment. Do not bulk-classify any recipient as `opted_in`. | Before live release, inventory the verified launch environment and classify test/sandbox versus genuine customer records using documented, reviewable provenance. Exclude test contacts only when evidence supports that classification; a nonzero raw count alone does not establish a genuine recipient. If any genuine recipient exists, stop live release pending an owner-approved evidence/migration rule and its completion. If any record cannot be classified, stop live release pending owner review. No customer re-verification or historical migration is a development dependency when the verified genuine-recipient count is zero. |
| Re-consent and administrative recovery | No re-consent portal in MVP. An administrator cannot clear, delete, or directly edit `opted_out`. An administrator may open an audited review, but the recipient remains opted out until explicit customer re-consent is verified under an approved process and category choice. | Before release, approve identity evidence, permitted verifier role, audit steps, and the manual correction procedure. If those are not approved, the record stays opted out. |
| STOP confirmation | No WhatsApp confirmation is sent by default. Do not treat an acknowledgment as an automatic exception to suppression. | Decide whether to send one, its exact copy, channel, and idempotency rule before release. |
| Consent and opt-out retention | Do not automatically expire `opted_out`. Preserve a suppression record so evidence minimization cannot silently re-enable messages. | Approve evidence and suppression retention, deletion/minimization rules, and privacy basis before release. No duration is set here. |
| Support-message retention | Keep pending or ambiguous content encrypted only as required for delivery and reconciliation. Do not delete it on exit without an approved schedule. | Approve FastCheck bridge and Chatwoot transcript retention, backup, deletion, and audit schedules before production support. |
| Paid-ticket fulfillment after opt-out | Continue payment verification and otherwise valid ticket issuance under existing FastCheck rules. Suppress WhatsApp delivery after STOP; do not cancel or delay issuance. Use no alternative channel unless its authority is approved. | Name and authorize a paid-ticket retrieval path before launch. No WhatsApp delivery exception is approved. |
| Customer exit (`0` / `#`) | Cancel queued or held support content not accepted by Chatwoot, with an audited disposition. Do not carry cancelled content into a later episode. Reconcile accepted or in-flight external work. Use only the existing Main menu response if the H2 authorization permits it; otherwise send nothing. | Confirm response copy or no-response choice, plus retention rules, before production support. |

The following H2 rules must be settled before CG-1 implementation authorization: STOP identity matching and idempotent state effects; the permitted customer-initiated service-response boundary; category-specific eligibility for `opted_in`; and the fail-closed administrative recovery rule. The launch-only decisions in the table may remain pending during development only where the implementation stays fail-closed and sends no unapproved message. They must be resolved before production release.

Historical evidence inventory and migration are not CG-1 development dependencies for the greenfield MVP. Before live messaging, perform the read-only inventory required by the matching proposed CG-1 amendment in the plan blob pinned in §1. Classify records using documented provenance; test/sandbox contacts are excluded only when evidence supports that classification, and a raw nonzero count alone is not a stop. If the verified launch environment contains zero genuine pre-existing customer recipients, record historical evidence migration as `N/A`. If genuine recipients exist, stop live release until a new owner-approved evidence/migration rule is implemented and reviewed. If provenance is insufficient to classify any record, stop live release pending owner review. The additive Postgres consent schema migration remains required regardless of the inventory result. No customer is bulk-classified as `opted_in`. All other CG-1 security, concurrency, authorization, audit, and test requirements remain in force.

If any approved behavior would change existing payment, inventory, ticket-issuance, or resend authority, record `STOP=COMMERCIAL_INVARIANT_CHANGE`. Consent denial suppresses WhatsApp delivery; it does not undo a valid commercial result.

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

- [ ] APPROVE the H2 direction and implementation rules in §§3.1-3.4. Items identified as release-only remain unresolved, authorize no send, and must be completed before production release. CG-1 still requires its separate authorization and the implementation prerequisites in §3.3.
- [ ] REJECT; identify the controlling alternative policy and exact authority path: ____________________
- [ ] REVISE; attach the replacement state transitions, category rules, and race behavior: ____________________

## 4. H3 — held-message disposition on support exit

**Owner position: `APPROVED IN PRINCIPLE` for audited cancellation of unsent support content. Trigger-specific details, retention, and formal approval remain pending.**

### 4.1 Customer exit (`0` / retained `#`)

The H3 direction approved in principle is to close the current support episode without carrying cancelled messages into another episode:

- Cancel customer-to-Chatwoot BridgeMessages still `queued` or `held` and not accepted by Chatwoot. Record `cancelled` with the exit reason, handoff ID, and source-message identity. Keep ciphertext only for the owner-approved retention interval, then delete it while retaining the minimum audit evidence.
- Cancel pre-dispatch agent/system-to-WhatsApp BridgeMessages that are still queued. Do not admit new agent replies after the close fence.
- Do not mark a Chatwoot-accepted inbound message cancelled or delete it from Chatwoot as part of exit. Its transcript status and any deletion request follow the separately approved retention/privacy process.
- Do not cancel a Meta dispatch already in progress. Reconcile its provider result; do not claim recall. Do not retry an ambiguous or accepted send.
- Do not carry a cancelled BridgeMessage into a successor episode. A later support request starts a new episode with new inbound message identities.

The cancellation is a delivery/routing disposition, not immediate physical deletion. It must satisfy the v0.2.3 close barrier: every held inbound record has an explicit disposition before the handoff becomes terminal. Existing orders, payments, tickets, unrelated `needs_human` reasons, and commercial state are unaffected.

### 4.2 STOP after H2 is approved

The H3 direction approved in principle is to commit the durable global opt-out before any support close or reply routing:

- Suppress and cancel, with an audited opt-out disposition, all unsent queued agent/system WhatsApp replies and all queued/held support payloads not yet accepted by Chatwoot. Do not forward a held payload to Chatwoot after STOP.
- Do not delete Chatwoot-accepted messages or assert that Meta-accepted messages were recalled. Follow the approved retention policy for stored content and reconcile in-flight provider outcomes.
- Do not carry canceled payloads into a later support episode. A new episode requires a new customer request after an approved re-consent, and uses new BridgeMessage records.
- Send no opt-out confirmation unless H2 explicitly approves the one-time message, its exact copy, channel, and an audited single-use exception to ordinary outbound suppression.
- Keep the handoff nonterminal while any dispatch, callback-order, held-message, or provider-outcome item remains unresolved. The v0.2.3 close barrier remains in force.

If privacy policy requires deletion, the system records the approved cancellation/deletion disposition and removes encrypted body content on the approved schedule. Until that policy is approved, retain the body encrypted, do not forward it, and do not terminalize the handoff on the assumption that it may be discarded.

### 4.3 Owner selections

For customer exit, the proposed default is the existing October-approved Main menu transition. Send its existing response only if the final H2 authorization permits it; if not, make no outbound send. Do not send a separate support-closure message or invent exit copy. The owner must confirm the exact response behavior and copy. The STOP confirmation decision remains governed by H2 and defaults to no WhatsApp confirmation without explicit approval. The owner must also complete the retention/deletion schedule for each trigger.

| Trigger | Proposed disposition | Owner decision |
|---|---|---|
| Customer exit (`0` / retained `#`) | Cancel queued/held undelivered support content with an audited reason; do not carry it into a successor episode. Reconcile any already-dispatching reply. Use only the existing Main menu transition and response if H2 permits the send; otherwise send nothing. | Pending |
| STOP after H2 policy takes effect | Commit opt-out first; suppress/cancel unsent content under the approved retention rule; do not carry it forward. Reconcile already-dispatching work without claiming recall. | Pending |

**H3 owner decision:**

- [ ] APPROVE the audited cancellation and reconciliation dispositions above. Retention/deletion schedules and customer-facing response choices remain production-release blockers.
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
7. Upon signed H2 approval, Global WhatsApp Consent Gate CG-1 is the mandatory implementation prerequisite for all new or modified WhatsApp outbound send paths. CG-1 must pass before a WhatsApp sales or support launch. Support Gate A may proceed independently only as an explicitly authorized no-send feasibility exercise.
8. The signed greenfield ruling and matching CG-1 plan amendment supersede only the unconditional historical consent inventory/backfill dependency: before live messaging, a read-only inventory must use documented provenance to distinguish test/sandbox contacts from genuine recipients. If the verified genuine-recipient count is zero, historical backfill is N/A. If genuine recipients exist or any record is unclassifiable, production release stops until an owner-approved evidence/migration rule is completed and reviewed. A nonzero raw count alone does not trigger migration. The additive Postgres consent schema migration and all other CG-1 controls remain required in every case.
9. October Gate B Tasks B1-B6 remain mandatory and incomplete until independently implemented and reviewed. The current name-first resend flow and existing email OTP do not satisfy the approved email-first, post-verification one-ticket selection contract.
10. WhatsApp Flows remain deferred until after launch and require a separate purchase-UX design and release gate.

If H1, H2, or H3 is rejected or unsigned, none of the supersession clauses take effect. The October 15 plan remains the authority and current authorization remains Gate 0 only. A signed Gate 0 decision does not authorize implementation; each later gate requires separate written authorization. CG-1 cannot be authorized while its implementation prerequisites in §3.3 remain unresolved. Values marked as production-release blockers may remain pending during development only when the relevant implementation remains fail-closed and makes no unapproved send.

## 6. Decision register for signature and release

| Decision | Direction recorded in this document | Decision gate |
|---|---|---|
| H1 task replacement and effective date | Option A and the C/D task map are approved in principle. | Formal H1 approval, exact controlling spec/plan revisions, signature, and effective date. Until then, October C/D tasks remain controlling. |
| H2 eligibility for unverified recipients | Direct service replies to an active customer-initiated exchange are allowed only within the valid service window; this is not durable `opted_in` consent. STOP overrides. Marketing broadcasts are excluded from MVP. | Before release, decide whether payment-link and ticket-delivery messages in the exchange qualify, and approve any other category-specific eligibility and evidence. No unresolved message may be sent. |
| H2 historical consent | No historical backfill or customer re-verification is required during greenfield development. A verified zero-genuine-recipient launch inventory makes historical migration N/A. | Before live release, use documented provenance to distinguish test/sandbox contacts from genuine recipients. A nonzero raw row count alone is not a blocker. Any genuine recipient stops live release until a new owner-approved evidence/migration rule is implemented and reviewed; unclassifiable records stop release pending owner review. The additive consent schema migration remains required. |
| H2 re-consent and admin recovery | No re-consent portal in MVP. An admin cannot directly clear or edit `opted_out`; the state remains denied until explicit customer evidence is verified through an approved process. | Before release, approve the identity evidence, authorized verifier, audit steps, and manual correction procedure. |
| H2 STOP response | No WhatsApp confirmation by default. | Before release, approve no confirmation or an exact one-time response, its channel, exception basis, copy, and idempotency key. |
| H2 consent/opt-out retention | Preserve the minimum suppression record needed to avoid accidental re-enablement; no automatic opt-out expiry. | Before release, approve evidence and suppression retention periods, deletion/minimization rules, and privacy basis. |
| H2 paid-ticket fulfillment and retrieval | Continue payment verification and otherwise valid ticket issuance under existing commercial rules. Suppress WhatsApp delivery after STOP. Do not delay issuance while alternative retrieval is decided; use only an independently authorized retrieval channel. | Before release, name the available retrieval channel and its authority. This proposal approves no channel or WhatsApp exception. |
| H3 held-message and provider outcomes | Audited cancellation for unsent queued/held content; reconcile accepted or in-flight work without claiming recall. | Confirm trigger-specific handling for customer exit and STOP, including ambiguous provider outcomes and any successor-episode rule. |
| H3 message and transcript retention | Encrypted pending/ambiguous FastCheck content only as needed; no duration selected. | Before production support, approve bridge, Chatwoot transcript, backup, deletion, and audit schedules. |
| H3 customer exit response | Existing Main menu transition only; send its existing response only if H2 authorizes it. Otherwise send nothing. No separate support-closure message. | Confirm exact copy and behavior when H2 suppresses the send. STOP confirmation remains a separate H2 decision. |
| October Gate B resend | Retained and incomplete. Existing name-first collection and email OTP do not satisfy the email-first one-ticket design. | Complete and independently review Tasks B1-B6 before launch certification. |
| Formal record | Approval in principle recorded; no formal signature or effective date. | Gate 0 signature: owner name/authority, date, exact H1-H3 decisions, implementation-level H2 values, and exact document revisions. |

### Formal approval record — intentionally blank

Do not treat this proposal as signed. The owner completes the record after reviewing the exact candidate documents and resolving the Gate 0 and CG-1 items in the decision register. Items marked for a later release gate may remain pending, but they authorize no send or production support. Approval in principle is not a substitute for any entry below.

| Approval field | Owner completion |
|---|---|
| H1 decision and C/D task replacement | Pending formal signature |
| H2 global STOP and bounded customer-initiated service direction | Pending formal signature |
| H2 greenfield history rule and provenance-verified pre-release inventory | Pending formal signature |
| H2 category map, re-consent/admin recovery, and launch-only values | Pending owner decisions as listed in §6 |
| H3 customer-exit cancellation and response | Pending formal signature and release-only response/retention values |
| H3 STOP disposition and retention rule | Pending formal signature and release-only retention values |
| Exact spec version and Git blob/commit | Pending |
| Exact signed plan revision and Git blob/commit | Pending |
| Owner name and authority | Pending |
| Signature | Pending |
| Effective date | Pending |
| Next separately authorized gate | None |

## 7. Gate 0 status

Stop if the baseline or authority changes before signature, if the consent authority or category rules remain unresolved, or if an exception is proposed without explicit approval. The implementation gates must also stop if the approved opt-out policy would require an unapproved commercial invariant change or application work without separate authorization.

Current Gate 0 remains open for `STOP=OWNER_POLICY_DECISION_REQUIRED`. The approval in principle does not supersede the October authority or authorize Support Gate A, CG-1 implementation, or any send-path change. Conditional stop guards are `STOP=MAIN_MOVED` if the recorded baseline changes, `STOP=CONSENT_EXCEPTION_ASSUMED` if any unapproved message exception is inferred, `STOP=COMMERCIAL_AUTHORITY_CHANGED` if the proposal changes commercial ownership, `STOP=POLICY_VALUES_INVENTED` if an unresolved policy value is filled without owner authority, and `STOP=NON_DOC_CHANGE` if this task changes anything beyond documentation. Application work requires a later gate authorization; until then use `STOP=APPLICATION_CHANGE_REQUIRED` for any attempted implementation.

```text
DOCUMENT_STATUS=PROPOSED_UNSIGNED_APPROVAL_IN_PRINCIPLE_RECORDED
OWNER_APPROVAL_IN_PRINCIPLE=H1_H2_H3
H1=APPROVED_IN_PRINCIPLE_OPTION_A
H2=APPROVED_IN_PRINCIPLE_GLOBAL_STOP_AND_BOUNDED_CUSTOMER_INITIATED_SERVICE
H3=APPROVED_IN_PRINCIPLE_AUDITED_UNSENT_SUPPORT_CANCELLATION_DETAILS_PENDING
GREENFIELD_HISTORICAL_BACKFILL=N_A_ONLY_IF_VERIFIED_ZERO_GENUINE_RECIPIENTS
PRE_RELEASE_RECIPIENT_PROVENANCE_CHECK=REQUIRED
CONSENT_SCHEMA_MIGRATION=REQUIRED_ALWAYS
HISTORICAL_MIGRATION=REQUIRED_IF_GENUINE_RECIPIENTS_AND_OWNER_POLICY_APPROVES
TEST_CONTACT_EXCLUSION=DOCUMENTED_PROVENANCE_REQUIRED
CUSTOMER_INITIATED_SERVICE=BOUNDED_TO_ACTIVE_EXCHANGE_AND_VALID_WINDOW
MARKETING_BROADCASTS=DEFERRED_FROM_MVP
RESEND_GATE_B=RETAINED_INCOMPLETE
CG1=MANDATORY_BEFORE_OUTBOUND_SEND_PATH_CHANGES
CG1_IMPLEMENTATION_AUTHORIZED=NO
CG1_IMPLEMENTATION_PREREQUISITES=PENDING_OWNER_DECISION
LAUNCH_ONLY_POLICY_VALUES=PENDING_OWNER_DECISION
AUTHORITY_PRECEDENCE=NOT_EFFECTIVE
GATE_0=OPEN
SUPPORT_GATE_A=NOT_AUTHORIZED
IMPLEMENTATION_AUTHORIZED=NO
PRODUCTION_AUTHORIZED=NO
WHATSAPP_FLOWS=POST_LAUNCH_SEPARATE_PURCHASE_UX_DESIGN_AND_RELEASE_GATE
MERGE_RECOMMENDATION=NO
STOP=OWNER_POLICY_DECISION_REQUIRED
STOP=GENUINE_RECIPIENTS_REQUIRE_APPROVED_MIGRATION
STOP=RECIPIENT_PROVENANCE_UNVERIFIED
STOP=DECISION_RECORD_CORRECTED
```
