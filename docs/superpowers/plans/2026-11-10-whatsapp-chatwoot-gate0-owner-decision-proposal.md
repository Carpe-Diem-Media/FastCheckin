# FastCheck WhatsApp/Chatwoot Gate 0 Owner Decision — Owner-Approved Record

| Field | Value |
|---|---|
| Document ID | FASTCHECK-WA-CHATWOOT-GATE0-DECISION-001 |
| Version | 0.1.7 |
| Date prepared | 2026-11-10 |
| Status | OWNER ELECTRONIC APPROVAL RECORDED — SIGNED GIT PUBLICATION AND GATE 0 REPOSITORY ADOPTION PENDING |
| Repository baseline | `e5ec24e53d44b0cebd472c1a05f138f314bb337f` |
| PR head reviewed | `b7b1c5532e212e56c0137d86cc9b8cff833a3f50` |
| Architecture revision proposed for adoption on signature | `docs/superpowers/specs/2026-11-10-whatsapp-flows-chatwoot-integration-design.md`, v0.2.3, Proposed; Git blob `953d9d77eca1afbc6405cd032eac5619dbbf6e29` |
| Plan revision proposed for adoption on signature | `docs/superpowers/plans/2026-10-15-whatsapp-customer-service-resend.md`, approved October plan plus proposed Chatwoot/CG-1 appendix; local candidate blob `2f6146f6e3e1dcb29466778a3c618eb6c460d597`, based on controlling plan blob `fec12201d12a97e9117e415aa3778eac8fdb5ef9` |
| Implementation authorization | NO |
| Owner identity | `jcschoeman96` — Owner; identity and authority self-declared in the approval conversation, not independently authenticated |
| Effective date | 2026-11-10 19:13:30 SAST (UTC+02:00; `2026-11-10T19:13:30+02:00`) — owner-requested sign-off timestamp |

> The owner approved the H1-H3 implementation-level policy directions in chat and subsequently supplied the typed signer name, role, and instruction to use the current SAST date/time. This owner-acknowledged electronic approval is **not a cryptographic signature or independent identity verification**. The controlling repository authority is not replaced until the exact signed documentation is published and independently reviewed under Gate 0. No implementation, production sending, installation, or deployment is authorized.

## Revision history

| Version | Change |
|---|---|
| 0.1.1 | Separates queued intent, fresh per-attempt consent authorization, Meta attempt start, and provider outcome; adds delayed-worker race acceptance criteria and records unresolved historical-consent and paid-ticket fulfillment decisions. H1 and H3 recommendations remain unchanged. |
| 0.1.2 | Pins the exact CG-1-enabled plan blob, names CG-1 as the H2 outbound prerequisite, and clarifies the signed authority precedence for no-send Support Gate A feasibility work. |
| 0.1.3 | Records H1-H3 approval in principle, adds proposed defaults for unresolved consent and support-exit policies, and keeps all unresolved values and formal approval pending. |
| 0.1.4 | Records the greenfield launch basis, removes historical consent migration and customer re-verification from development dependencies, records the bounded first-contact service direction, and preserves October Gate B as incomplete required work. |
| 0.1.5 | Reconciles CG-1 historical handling with the greenfield launch: a provenance-verified zero-genuine-recipient inventory makes historical backfill N/A; genuine or unclassifiable recipients block live release pending an owner-approved migration rule. The new consent schema migration remains required. |
| 0.1.6 | Records the owner-approved-in-chat H1-H3 implementation directions, exact STOP parsing and verified Meta identity binding, category-specific fail-closed sending, default no-confirmation behavior, and the guarded support close barrier. Pins the exact proposed spec and plan revisions; keeps the formal signature and effective date blank. |
| 0.1.7 | Separates CG-1 development prerequisites from production personal-data and live-messaging prerequisites. After Gate 0 signature and separate CG-1 authorization, synthetic-only implementation may proceed while privacy and retention decisions remain pending; those decisions are required before affected production data processing. Keeps owner signature and effective date blank. |

## Owner electronic approval evidence

- **Exact approved decision content:** v0.1.7 candidate Git blob `b7eba09f64f94d16a4317587e5af9f58fce8048c`.
- **Architecture specification approved for adoption:** v0.2.3, Git blob `953d9d77eca1afbc6405cd032eac5619dbbf6e29`.
- **Amended October plan approved for adoption:** Git blob `2f6146f6e3e1dcb29466778a3c618eb6c460d597`.
- **Owner acknowledgement:** explicit `approved` in this conversation, followed by `jcschoeman96 - Owner - todays date and sast time`.
- **Recorded timestamp:** `2026-11-10T19:13:30+02:00` (SAST). This is the independently retrieved time of recording, not a claim to know the instant the owner sent the earlier approval.
- **Proof level:** typed electronic acknowledgement in conversation. No cryptographic signature, verified legal identity, Git publication, merge, or separate implementation authorization is asserted.

## 1. Purpose and current authority

This proposal gives the owner explicit H1-H3 decisions for Gate 0: the support workspace and task replacement, durable WhatsApp opt-out/re-consent behavior, and disposition of held support messages. It also defines the precedence a signed amendment would have over the October 15 plan.

At the recorded baseline, the October 15 plan remains approved for gated execution, with Gate 0 as the only current authorization. The current source recognizes a standalone `STOP` input and applies state-specific handling. The reviewed source does not establish a durable, global opt-out authority for all WhatsApp send paths. The Chatwoot integration spec and its appended plan amendment remain proposals until approved.

### H1-H3 owner directions approved in chat; electronic sign-off recorded

| Decision | Owner position | Scope and effect |
|---|---|---|
| H1 | APPROVED IN CHAT: FastCheck + Chatwoot Option A for the agreed MVP. | FastCheck retains Meta transport and commercial authority. Chatwoot provides the human-support workspace after Gate A. C/D task supersession takes effect only after signed repository adoption. This record does not authorize installation or implementation. |
| H2 | APPROVED IN CHAT: recipient-scoped global STOP, authenticated Meta sender identity, category-specific consent, and bounded customer-initiated service replies. | Match trimmed, case-insensitive `STOP` before Sales/support routing and bind it to the verified sender identity for the configured FastCheck business number. STOP denies every WhatsApp category. Direct service replies are limited to the active customer-initiated exchange and valid 24-hour window; they do not create durable `opted_in` consent. Marketing is not automatically opted in and is excluded from MVP. Any unresolved outbound eligibility remains fail-closed. |
| H3 | APPROVED IN CHAT: audited cancellation of unsent support content, reconciliation of accepted/in-flight provider work, and a guarded support exit. | Cancel only eligible unsent queued/held content with an audit disposition. Reconcile external work without claiming recall. A handoff remains nonterminal until the v0.2.3 close barrier and explicit disposition requirements are satisfied. Retention and any customer-facing exit response remain release decisions. |
| Greenfield basis | OWNER-CONFIRMED: FastCheck has not launched and has no real historical customer base. | Historical consent backfill and existing-customer re-verification are not development dependencies. Before live messaging, verify the launch environment with a read-only inventory and documented provenance. A verified zero genuine recipients makes historical backfill N/A. Genuine recipients or records whose provenance cannot distinguish a test contact from a customer stop live release pending a new owner-approved migration rule. A nonzero raw row count alone does not establish a genuine customer. The new Postgres consent schema migration remains required. |
| Resend | October Gate B remains required and incomplete. | Current name-first resend code and existing email OTP do not satisfy the approved email-first, post-verification one-ticket selection design. |

The owner's chat approval and subsequent typed signer details are recorded in the electronic sign-off in §6. They do not alone establish signed Git-history adoption or independent signer authentication, activate unreviewed repository changes, authorize a send path, or establish legal or provider permission. A signed documentation commit and independent review remain required before any subsequent gate is executed.

The owner's electronic approval supplies the signer details, effective timestamp, and exact proposed document revisions below. Gate 0 repository adoption additionally requires the exact signed documentation to enter reviewed Git history and be verified against those revisions. The actual recipient inventory and any conditional historical migration are pre-release requirements; they are not required to close Gate 0 or begin separately authorized development. Before live messaging, the verified inventory must establish zero genuine recipients or, if genuine recipients exist, the owner-approved migration must be completed. Unclassifiable records require owner review and continue to block release. Values marked as production-release decisions may remain pending during development only when the affected send remains disabled; they block production release. Until the signed documentation has been independently reviewed and adopted in the repository, Gate 0 execution stays closed to other gates and no October task is treated as superseded by an unmerged candidate.

## 2. H1 — support workspace and task replacement

**Owner direction: `APPROVED IN CHAT` for Option A and the task map. Electronic owner sign-off is recorded in §6; repository adoption remains pending.**

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

The recorded owner electronic approval adopts the Option A direction, but operational C/D task replacement waits for independently reviewed adoption of the exact signed documents in the repository. Neither chat approval nor signature authorizes Chatwoot installation, Meta configuration, application changes, migrations, deployment, or production traffic. Each later gate requires its own authorization.

**Recorded H1 direction:** APPROVE Option A and the task map above. Owner electronic sign-off and effective timestamp are recorded in §6; implementation remains separately gated.

## 3. H2 — durable STOP, opt-out, and re-consent policy

**Owner direction: `APPROVED IN CHAT` for durable recipient-scoped global STOP/opt-out, category-specific consent, and bounded customer-initiated service replies. Electronic owner sign-off is recorded in §6; repository adoption remains pending.**

### 3.1 Proposed global STOP rule

For inbound message text, trim surrounding whitespace and compare case-insensitively to the exact token `STOP`. Do not match additional phrases or aliases unless the owner separately approves them. Process this command before every Sales or support route, including active support and collection states. Bind the durable opt-out to the verified sender identity supplied by the authenticated, configured-business-number Meta webhook. Do not derive identity from message text, Chatwoot fields, or operator input. If the sender identity or business-number scope cannot be verified, fail closed and do not route the message as ordinary Sales or support content.

Do not store or forward the STOP text as support content. A later inbound message, new order, or support request does not by itself restore WhatsApp permission or clear `opted_out`. Repeated STOP is idempotent. If STOP arrives during `reconsent_pending`, cancel that pending attempt and return to or retain `opted_out`.

An unqualified STOP applies as a global outbound deny across marketing, support, and transactional message categories. No category is an automatic exception. STOP suppresses WhatsApp delivery; it does not change payment verification, inventory, or ticket issuance under FastCheck's existing commercial rules. An otherwise valid paid ticket must not be cancelled, delayed, or left unissued because WhatsApp delivery is suppressed. Alternative retrieval is a separate channel decision and is permitted only under an independently approved authority. Do not substitute a WhatsApp template or create a new delivery exception to bypass the opt-out.

### 3.2 Proposed durable consent lifecycle

Persist the consent decision in a durable FastCheck authority, independent of SupportHandoff and event-specific Sales state. Scope it to the verified recipient identity and the FastCheck business WhatsApp number, across events and support episodes. Keep an audit history of state changes and evidence. Before CG-1 development, select and record the consent resource, protected recipient-identity representation, and data model needed to enforce the approved H2 rules. Implement and test with synthetic data only. The privacy basis and applicable retention/minimization rules must be approved before any production collection or processing of real recipient personal data. This proposal sets no privacy basis or retention period.

#### H2 approval sequence

| Stage | Required authority |
|---|---|
| Before CG-1 development | Gate 0 has an adopted owner-approved record on signed Git history; CG-1 has separate owner authorization; the H2 implementation rules and protected consent data model described above are approved. |
| During CG-1 implementation and testing | Use synthetic data only. Do not process real recipient personal data or make live customer sends. Keep unresolved release-only behavior disabled. |
| Before production personal-data collection or processing | Approve the privacy basis and applicable retention/minimization rules for the affected consent evidence, messages, transcripts, and audit records. No period or basis is set here. |
| Before live WhatsApp messaging | Approve eligibility for each outbound category and path, authorize paid-ticket retrieval after opt-out, complete the provenance-based recipient inventory and any required migration, and satisfy the release safeguards. |

| State | Allowed transition | Required guard and effect |
|---|---|---|
| `unverified` | `opted_in` | Only an explicit, auditable consent event through an owner-approved process. Record the evidence and the allowed category scope. A purchase, inbound message, or operator assumption is not consent evidence. |
| `unverified` or `opted_in` | `opted_out` | An exact STOP command from the verified Meta sender identity. Record the durable deny immediately for all WhatsApp categories and create an audit event without retaining the STOP body as support text. Repeated STOP is idempotent. |
| `opted_out` | `reconsent_pending` | Only an explicit customer-initiated re-consent request through the owner-approved, identity-verified process. Ordinary inbound messages do not trigger this transition. Do not send a WhatsApp verification prompt while opted out. |
| `reconsent_pending` | `opted_in` | Only after the approved verification succeeds. Record the evidence, actor/system, time, and categories the customer explicitly accepted. Do not infer permission for categories not covered by that evidence. |
| `reconsent_pending` | `opted_out` | On failed verification, customer cancellation, expiry, or an exact STOP command. STOP immediately cancels the pending attempt. No category is restored and the deny is never released by expiry. |
| `opted_in` | `opted_out` | A later exact STOP command takes precedence over every category grant. |

There is no automatic expiry from `opted_out` to an allowed state and no permanently terminal customer identity. Only the approved re-consent process can restore explicitly granted categories. An operator cannot clear opt-out by editing a support case or conversation. Any exceptional administrative authority, if the owner wants one, must be separately specified and audited; it is not part of this proposal.

The consent record is authoritative in Postgres. A cache, job, queue, Chatwoot field, or per-event flag cannot grant permission. Store only the minimum evidence needed to enforce and audit the decision. Retain the suppression record for the owner-approved period; if privacy rules require removal of detailed evidence, retain an approved suppression-safe record so deletion does not silently re-enable messaging.

### 3.3 Category policy and launch decisions

The owner approved this bounded first-contact direction in chat for the greenfield MVP: an `unverified` recipient may receive direct service replies to the customer's active, customer-initiated WhatsApp exchange only while the latest trusted inbound timestamp passes the strict service-window check. This limited reply eligibility does not change the durable state to `opted_in`, grant marketing permission, or authorize unrelated or later business-initiated messages. An opted-out recipient receives no WhatsApp message, including a service reply. This records the product direction; it does not claim legal authorization or replace applicable provider rules.

The strict service-window check requires a valid trusted inbound timestamp and a nonnegative elapsed duration no greater than 24 hours. Missing, malformed, future, or out-of-range timestamps do not open the window. Recheck immediately before each Meta attempt. A server-time fallback cannot establish the customer's service window.

Record separate evidence and permission scope for **marketing**, **support**, and **transactional** messages. An `opted_in` record grants only explicitly evidenced categories. Never create marketing opt-in automatically. Marketing broadcasts are disabled for the MVP. Any business-initiated message without approved category evidence remains blocked. The eligibility of payment links, ticket delivery, and other commercial messages inside or outside a customer-initiated purchase exchange remains a release decision; do not silently classify them as service replies or invent an exception after STOP. An unresolved sender path stays fail-closed.

| Topic | Direction recorded for the MVP | Pending decision or release guard |
|---|---|---|
| Explicit `opted_out` | Hard deny all WhatsApp outbound categories. Match only trimmed, case-insensitive exact `STOP` unless additional phrases are separately approved. Process it before Sales/support routing and bind it to the verified Meta sender for the configured business number. No order, service-window, support-agent, or template exception. Repeated STOP is idempotent; STOP during `reconsent_pending` cancels that attempt. | No additional opt-out phrases are authorized by this record. Identity-verification failure remains fail-closed. |
| `unverified`, customer-initiated service | Allow direct replies to the active customer-initiated service exchange only while a valid, trusted inbound timestamp passes the strict service-window check. Do not create a durable `opted_in` grant. | Before release, decide whether payment-link and ticket-delivery messages in that exchange fall within this approved scope. Until then, do not infer their eligibility. |
| `unverified`, business-initiated messages | No automatic marketing opt-in and no MVP marketing broadcasts. Do not send other business-initiated categories without category-specific evidence. An order, payment, ticket, inbound message, or prior delivery is not evidence by itself. | Eligibility for each business-initiated category, including payment links and ticket delivery, remains pending. Until approved, those messages are blocked. |
| `opted_in` | Permit only categories supported by durable consent evidence, subject to all other WhatsApp and business rules. | Approve consent wording and evidence standard before production release. |
| Historical migration and re-verification | Not a development dependency. Historical backfill is `N/A` only after a read-only inventory verifies zero genuine pre-existing customer recipients in the launch environment. Do not bulk-classify any recipient as `opted_in`. | Before live release, inventory the verified launch environment and classify test/sandbox versus genuine customer records using documented, reviewable provenance. Exclude test contacts only when evidence supports that classification; a nonzero raw count alone does not establish a genuine recipient. If any genuine recipient exists, stop live release pending an owner-approved evidence/migration rule and its completion. If any record cannot be classified, stop live release pending owner review. No customer re-verification or historical migration is a development dependency when the verified genuine-recipient count is zero. |
| Re-consent and administrative recovery | No re-consent portal in MVP. An administrator cannot clear, delete, or directly edit `opted_out`. No automated or unauthorized override is allowed. The recipient remains opted out until explicit customer re-consent is verified through a separately approved process with category selection. | Identity evidence, verifier role, audit steps, and any manual correction procedure remain pending. If they are not approved, the record stays opted out. |
| STOP confirmation | Send no WhatsApp confirmation by default. No acknowledgement is an automatic exception to the global deny. | Any future confirmation requires a separate owner-approved exception, exact copy, channel, and idempotency rule. |
| Consent and opt-out retention | Do not automatically expire `opted_out`. Preserve a suppression record so evidence minimization cannot silently re-enable messages. | Approve evidence and suppression retention, deletion/minimization rules, and privacy basis before release. No duration is set here. |
| Support-message retention | Keep pending or ambiguous content encrypted only as required for delivery and reconciliation. Do not delete it on exit without an approved schedule. | Approve FastCheck bridge and Chatwoot transcript retention, backup, deletion, and audit schedules before production support. |
| Paid-ticket fulfillment after opt-out | Continue payment verification and otherwise valid ticket issuance under existing FastCheck rules. Suppress WhatsApp delivery after STOP; do not cancel or delay issuance. Use no alternative channel unless its authority is approved. | Name and authorize a paid-ticket retrieval path before launch. No WhatsApp delivery exception is approved. |
| Customer exit (`0` / `#`) | Cancel queued or held support content not accepted by Chatwoot, with an audited disposition. Do not carry cancelled content into a later episode. Reconcile accepted or in-flight external work. Use only the existing Main menu response if the H2 authorization permits it; otherwise send nothing. | Confirm response copy or no-response choice, plus retention rules, before production support. |

The owner-approved-in-chat implementation rules are the exact STOP parser and verified Meta sender binding, idempotent global state effects, the bounded direct service-reply window, category-specific evidence for every `opted_in` grant, and fail-closed recovery with no unauthorized override. CG-1 remains separately gated and unauthorized until Gate 0 authority is adopted on signed Git history and CG-1 receives its own authorization. Release-only eligibility decisions may remain pending during development only while the affected sender paths remain disabled. Resolve each before production release; no unapproved message may be sent.

Historical evidence inventory and migration are not CG-1 development dependencies for the greenfield MVP. Before live messaging, perform the read-only inventory required by the matching proposed CG-1 amendment in the plan blob pinned in §1. Classify records using documented provenance; test/sandbox contacts are excluded only when evidence supports that classification, and a raw nonzero count alone is not a stop. If the verified launch environment contains zero genuine pre-existing customer recipients, record historical evidence migration as `N/A`. If genuine recipients exist, stop live release until a new owner-approved evidence/migration rule is implemented and reviewed. If provenance is insufficient to classify any record, stop live release pending owner review. The additive Postgres consent schema migration remains required regardless of the inventory result. No customer is bulk-classified as `opted_in`. All other CG-1 security, concurrency, authorization, audit, and test requirements remain in force.

If any approved behavior would change existing payment, inventory, ticket-issuance, or resend authority, record `STOP=COMMERCIAL_INVARIANT_CHANGE`. Consent denial suppresses WhatsApp delivery; it does not undo a valid commercial result.

### 3.4 Shared outbound suppression and STOP/dispatch race

The future implementation must enforce consent at the shared FastCheck WhatsApp outbound authorization boundary used by sales, support, resend, ticket/payment delivery, system notices, and retries. A Chatwoot-only check is insufficient. Chatwoot never sends directly to Meta.

After the formal Gate 0 signature adopts H2, Global WhatsApp Consent Gate CG-1 is the mandatory implementation prerequisite for all new or modified WhatsApp outbound send paths. H2 approval does not itself authorize CG-1 implementation; CG-1 requires its separate gate authorization and must pass before any such send path is implemented or changed. Support Gate A may proceed independently only as an explicitly authorized no-send feasibility exercise.

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

**Recorded H2 direction:** APPROVE the implementation-level rules in §§3.1-3.4. Electronic owner sign-off is recorded in §6; repository adoption remains pending. CG-1 development requires the predevelopment approvals in §3.2, separate authorization, and synthetic-only data. Release-only eligibility may remain pending only while affected sends stay disabled. Privacy-basis and retention/minimization decisions must be approved before affected production personal-data collection or processing. This record grants no implementation authorization.

## 4. H3 — held-message disposition on support exit

**Owner direction: `APPROVED IN CHAT` for audited cancellation of unsent support content, provider reconciliation, and guarded exit. Electronic owner sign-off is recorded in §6; repository adoption remains pending. Retention and response details remain release decisions.**

### 4.1 Customer exit (`0` / retained `#`)

The H3 direction approved in chat is to close the current support episode without carrying cancelled messages into another episode:

- Cancel customer-to-Chatwoot BridgeMessages still `queued` or `held` and not accepted by Chatwoot. Record `cancelled` with the exit reason, handoff ID, and source-message identity. Keep ciphertext only for the owner-approved retention interval, then delete it while retaining the minimum audit evidence.
- Cancel pre-dispatch agent/system-to-WhatsApp BridgeMessages that are still queued. Do not admit new agent replies after the close fence.
- Do not mark a Chatwoot-accepted inbound message cancelled or delete it from Chatwoot as part of exit. Its transcript status and any deletion request follow the separately approved retention/privacy process.
- Do not cancel a Meta dispatch already in progress. Reconcile its provider result; do not claim recall. Do not retry an ambiguous or accepted send.
- Do not carry a cancelled BridgeMessage into a successor episode. A later support request starts a new episode with new inbound message identities.

The cancellation is a delivery/routing disposition, not immediate physical deletion. It must satisfy the v0.2.3 close barrier: every admitted customer message has an explicit disposition, every admitted agent reply has a dispatch/cancel/reconciliation outcome, and every external send has an evidence-based provider outcome before the handoff becomes terminal. If any item remains ambiguous, the handoff stays nonterminal in recovery. Customer input racing with agent resolution or `0`/`#` exit cannot be discarded or sent to Sales. Existing orders, payments, tickets, unrelated `needs_human` reasons, and commercial state are unaffected.

### 4.2 STOP after H2 is approved

The H3 direction approved in chat is to commit the durable global opt-out before any support close or reply routing:

- Suppress and cancel, with an audited opt-out disposition, all unsent queued agent/system WhatsApp replies and all queued/held support payloads not yet accepted by Chatwoot. Do not forward a held payload to Chatwoot after STOP.
- Do not delete Chatwoot-accepted messages or assert that Meta-accepted messages were recalled. Follow the approved retention policy for stored content and reconcile in-flight provider outcomes.
- Do not carry canceled payloads into a later support episode. A new episode requires a new customer request after an approved re-consent, and uses new BridgeMessage records.
- Send no opt-out confirmation by default. Any future confirmation requires a separate owner-approved exception, exact copy, channel, and audited single-use authorization; it is not implied by this record.
- Keep the handoff nonterminal while any dispatch, callback-order, held-message, or provider-outcome item remains unresolved. The v0.2.3 close barrier remains in force.

If privacy policy requires deletion, the system records the approved cancellation/deletion disposition and removes encrypted body content on the approved schedule. Until that policy is approved, retain the body encrypted, do not forward it, and do not terminalize the handoff on the assumption that it may be discarded.

### 4.3 Exit response and retention decisions

For customer exit, use only the existing October-approved Main menu transition. Send its existing response only if the H2 outbound authorization permits that specific message; otherwise send nothing. Do not send a separate support-closure message or invent exit copy. The default STOP response is no WhatsApp confirmation. The owner must still approve the content retention/deletion schedule for each trigger before production support.

| Trigger | Proposed disposition | Owner decision |
|---|---|---|
| Customer exit (`0` / retained `#`) | Cancel queued/held undelivered support content with an audited reason; do not carry it into a successor episode. Reconcile any already-dispatching reply. Use only the existing Main menu transition and response if H2 permits that send; otherwise send nothing. Terminalize only after the close barrier is complete. | Direction approved by the owner and electronically acknowledged; repository adoption pending. Retention and response eligibility remain pending. |
| STOP | Commit global opt-out first; suppress/cancel unsent content with an audited disposition; do not carry it forward. Reconcile already-dispatching work without claiming recall. Terminalize only after the close barrier is complete. | Direction approved by the owner and electronically acknowledged; repository adoption pending. Retention remains pending. |

**Recorded H3 direction:** APPROVE the audited cancellation, provider reconciliation, and guarded exit behavior above. Electronic owner sign-off is recorded in §6; repository adoption remains pending. Retention periods and any customer-facing exit response remain release decisions and do not authorize sends.

## 5. Signed-authority precedence and effective date

This is a separate, versioned amendment proposal so implementers do not have to infer precedence from the October task text and the proposed Chatwoot appendix.

If and only if this amendment is signed with an effective date and the exact document revisions below are acknowledged:

1. This signed amendment and the exact approved v0.2.3 architecture spec become the controlling authority for the Chatwoot support-workspace decision and H2/H3 policy.
2. October 15 Gate C Tasks C1-C4 and Gate D Tasks D1-D5 are **superseded and must not be executed**. Their old wording remains historical context only.
3. The proposed Support Gates in the exact signed plan revision become the sole implementation instructions for those replaced C/D responsibilities. Name that plan revision and its Git commit/blob at signing; do not rely on a mutable filename alone.
4. October 15 Gate A Tasks A1-A2, Gate B Tasks B1-B6, and Gate E Tasks E1-E3 remain in force as mapped in H1. This amendment does not change commercial, resend, navigation, sandbox, or Paystack authority.
5. The prior proposed appendix is not independently effective. If it conflicts with this signed decision amendment, this amendment controls for H1-H3 and C/D precedence. The signed plan revision controls gate execution details within those approved decisions.
6. Approval closes only Gate 0. It does not authorize application changes, migrations, Chatwoot installation, Meta configuration, secrets, deployment, or production activity. Each implementation gate needs separate written authorization. Support Gate A has separate owner approval in chat for an isolated no-send feasibility exercise; its execution remains blocked until Gate 0 is signed and the disposable-environment, release/license, no-send-isolation, and independent-review prerequisites are met.
7. Upon formal Gate 0 signature adopting H2, Global WhatsApp Consent Gate CG-1 is the mandatory implementation prerequisite for all new or modified WhatsApp outbound send paths. CG-1 must pass before a WhatsApp sales or support launch. Support Gate A may proceed independently only as an explicitly authorized no-send feasibility exercise.
8. The signed greenfield ruling and matching CG-1 plan amendment supersede only the unconditional historical consent inventory/backfill dependency: before live messaging, a read-only inventory must use documented provenance to distinguish test/sandbox contacts from genuine recipients. If the verified genuine-recipient count is zero, historical backfill is N/A. If genuine recipients exist or any record is unclassifiable, production release stops until an owner-approved evidence/migration rule is completed and reviewed. A nonzero raw count alone does not trigger migration. The additive Postgres consent schema migration and all other CG-1 controls remain required in every case.
9. October Gate B Tasks B1-B6 remain mandatory and incomplete until independently implemented and reviewed. The current name-first resend flow and existing email OTP do not satisfy the approved email-first, post-verification one-ticket selection contract.
10. WhatsApp Flows remain deferred until after launch and require a separate purchase-UX design and release gate.

Until the electronically approved amendment is published on signed Git history and independently reviewed for repository adoption, no supersession clause may be acted on. The October 15 plan remains the authority and current authorization remains Gate 0 only. A signed Gate 0 decision does not authorize implementation; each later gate requires separate written authorization. CG-1 is mandatory before any new or modified WhatsApp outbound send path, requires its own authorization, and may proceed only under the signed H2 rules. Release-only eligibility values may remain pending during development only when the affected send remains disabled; no unresolved or unapproved outbound message may be sent.

## 6. Decision register for signature and release

| Decision | Direction recorded in this document | Decision gate |
|---|---|---|
| H1 — Chatwoot Option A and task map | Approved in chat: FastCheck owns Meta transport and commercial authority; Chatwoot is the human-support workspace. | Electronic approval recorded; task-map supersession awaits reviewed signed Git adoption. Before that, October C/D tasks remain controlling. |
| H2 — STOP matching and identity | Approved in chat: trim surrounding whitespace, case-insensitive exact `STOP`, process before Sales/support routing, bind to the authenticated Meta sender identity for the configured business number, and persist a recipient-scoped global deny. No aliases are included. | CG-1 must implement and independently test the rule before any outbound sender path is changed. Identity-verification failure remains fail-closed. |
| H2 — service and category eligibility | Approved in chat: direct service replies to the active customer-initiated exchange are bounded by a valid trusted timestamp and strict 24-hour window; this does not create durable consent. Durable `opted_in` permission is category-specific and evidence-based. Marketing is disabled for MVP; no automatic marketing opt-in. | Payment-link, ticket-delivery, and other unresolved outbound eligibility remains blocked until the owner separately approves the exact category and evidence. No unresolved message may be sent. |
| H2 — re-consent and administrative recovery | No MVP re-consent portal. No automatic or unauthorized opt-out override. `opted_out` remains denied until an explicitly approved, identity-verified customer re-consent process grants named categories. | Before enabling recovery, approve identity evidence, verifier role, audit steps, and manual procedure. Without those approvals, remain opted out. |
| H2 — STOP confirmation | No WhatsApp confirmation by default. | Any future confirmation requires a separate owner-approved exception, exact copy, channel, and idempotency rule. |
| H2 — consent retention | No automatic opt-out expiry; retain only under an approved privacy and retention policy. | Approve evidence and suppression retention, deletion/minimization rules, and privacy basis before collecting or processing affected real recipient personal data in production. No period or basis is invented here. |
| H2 — paid-ticket fulfillment and retrieval | Continue payment verification and otherwise valid ticket issuance under existing commercial rules. STOP suppresses WhatsApp delivery and does not cancel or delay issuance. | Name and authorize an alternative paid-ticket retrieval path before launch. No channel or WhatsApp exception is approved here. |
| H2 — greenfield inventory | Historical backfill is not a development dependency. New Postgres consent schema migration remains required in all cases. | Before live messaging, perform the read-only provenance-based recipient inventory. Zero genuine recipients makes historical migration N/A; genuine or unclassifiable recipients block release pending approved evidence/migration handling. A nonzero raw count alone is not a blocker. |
| H3 — support exit and STOP | Approved in chat: audited cancellation of unsent queued/held content, provider reconciliation for accepted/in-flight/ambiguous work, and no terminal handoff until every admitted item satisfies the v0.2.3 close barrier. Canceled content is not carried into a later episode. | Electronic approval recorded; repository adoption pending. Retention and exact customer-facing exit response remain release decisions; no unauthorized send or false cancellation is allowed. |
| H3 — message and transcript retention | No duration selected. | Approve FastCheck bridge and Chatwoot transcript, backup, deletion, and audit schedules before production support. |
| H3 — customer exit response | Existing Main menu transition only, and only if the specific send passes the approved H2 authorization. Otherwise send nothing. No separate support-closure message. | Resolve message eligibility and any copy change before production; no new response is authorized here. |
| October Gate B resend | Retained and incomplete. Existing name-first collection and email OTP do not satisfy the email-first one-ticket design. | Complete and independently review Tasks B1-B6 before launch certification. |
| WhatsApp Flows | Deferred from MVP. | Separate purchase-UX design and release gate after launch. |
| Formal record | H1-H3 electronically acknowledged by `jcschoeman96` (Owner) at the timestamp in §6. | Publish signed documentation, verify exact blobs, obtain exact-head CI and independent review before treating Gate 0 as repository-adopted. |

### Formal approval record — owner electronic sign-off recorded

The owner explicitly approved H1-H3 in this conversation and then supplied the typed signing identity and role, requesting the current SAST date/time. The typed electronic acknowledgement below records approval of the exact v0.1.7 candidate content and document blobs. It is not a GPG/SSH/digital signature and does not independently authenticate the account holder. To activate the authority in repository practice, publish this record and the pinned plan on signed Git history, independently review the resulting diff and exact-head CI, and verify the approved blobs. This owner sign-off does not separately authorize implementation. Release-only decisions may remain pending during separately authorized synthetic-only development. They do not permit production processing of real recipient personal data or affected outbound sends; approve the applicable privacy basis and retention/minimization rules before the former, and category eligibility before the latter. This record does not authorize implementation or production support.

| Approval field | Owner completion |
|---|---|
| H1 direction | Owner-approved and electronically acknowledged; independent repository adoption pending |
| H2 direction | Approved in chat as specified in §§3.1-3.4; unresolved message eligibility remains fail-closed |
| H3 direction | Approved in chat as specified in §4; release-only retention and response details remain pending |
| Effect of owner electronic approval | Records owner approval of H1-H3 and §5 authority precedence for the exact v0.1.7 content; repository adoption requires the signed Git review process; does not authorize implementation or production activity |
| Architecture spec to adopt | v0.2.3, blob `953d9d77eca1afbc6405cd032eac5619dbbf6e29`, at reviewed PR head `b7b1c5532e212e56c0137d86cc9b8cff833a3f50` |
| Implementation plan to adopt | Proposed October 15 plan plus Chatwoot/CG-1 appendix candidate, blob `2f6146f6e3e1dcb29466778a3c618eb6c460d597`, based on reviewed PR head `b7b1c5532e212e56c0137d86cc9b8cff833a3f50`; not yet present on that PR head |
| Decision record revision | Approved pre-sign content: v0.1.7 Git blob `b7eba09f64f94d16a4317587e5af9f58fce8048c`; the sign-off metadata changes the resulting file blob, which must be verified on publication |
| Owner name and authority | `jcschoeman96` — Owner (self-declared in conversation) |
| Signature / evidence | Typed electronic acknowledgement: `jcschoeman96` — approved H1-H3 in chat and supplied signer details in this conversation; no cryptographic signing claim |
| Effective date | `2026-11-10T19:13:30+02:00` (10 November 2026, 19:13:30 SAST) |
| Support Gate A | Separately approved in chat for isolated no-send feasibility; execution remains blocked until independent Gate 0 repository adoption and all preflight prerequisites are met. This record grants no additional authorization. |
| Implementation authorization | NO |

## 7. Gate 0 status

Stop if the PR head or controlling document blobs change before repository adoption, if an unapproved outbound eligibility is assumed, or if any commercial invariant would change. Owner electronic approval and a SAST effective timestamp are now recorded, but the documentation has not been published and independently reviewed as signed Git authority. Do not treat the unmerged candidate as an operational supersession; no CG-1 implementation or sender-path change is authorized. Support Gate A has separate owner approval for no-send feasibility, but execution remains blocked until authority publication and its stated prerequisites. Conditional stop guards are `STOP=PR_HEAD_MOVED`, `STOP=AUTHORITY_CONFLICT`, `STOP=UNAPPROVED_POLICY_ASSUMPTION`, `STOP=COMMERCIAL_INVARIANT_CHANGE`, `STOP=UNSIGNED_AUTHORITY`, and `STOP=NON_DOC_CHANGE`. Application work requires separate gate authorization; until then use `STOP=IMPLEMENTATION_NOT_AUTHORIZED` for any attempted implementation.

```text
DOCUMENT_STATUS=OWNER_ELECTRONIC_APPROVAL_RECORDED_GIT_PUBLICATION_PENDING
H1=APPROVED_IN_CHAT_FASTCHECK_META_AND_COMMERCIAL_AUTHORITY_CHATWOOT_SUPPORT_WORKSPACE
H2=APPROVED_IN_CHAT_RECIPIENT_SCOPED_GLOBAL_STOP_VERIFIED_META_IDENTITY_CATEGORY_CONSENT_BOUNDED_SERVICE
H3=APPROVED_IN_CHAT_AUDITED_UNSENT_CANCELLATION_PROVIDER_RECONCILIATION_GUARDED_EXIT
STOP_MATCH=TRIM_SURROUNDING_WHITESPACE_CASE_INSENSITIVE_EXACT_STOP
STOP_PRECEDENCE=BEFORE_SALES_AND_SUPPORT_ROUTING
STOP_IDENTITY=AUTHENTICATED_CONFIGURED_META_BUSINESS_NUMBER_SENDER
STOP_CONFIRMATION=NONE_BY_DEFAULT
MARKETING_OPT_IN=NEVER_AUTOMATIC
OPT_OUT_OVERRIDE=NO_UNAUTHORIZED_OVERRIDE; RECONSENT_REQUIRES_SEPARATELY_APPROVED_VERIFIED_CUSTOMER_PROCESS
GREENFIELD_HISTORICAL_BACKFILL=N_A_ONLY_IF_VERIFIED_ZERO_GENUINE_RECIPIENTS
PRE_RELEASE_RECIPIENT_PROVENANCE_CHECK=REQUIRED
CONSENT_SCHEMA_MIGRATION=REQUIRED_ALWAYS
HISTORICAL_MIGRATION=REQUIRED_IF_GENUINE_RECIPIENTS_AND_OWNER_POLICY_APPROVES
TEST_CONTACT_EXCLUSION=DOCUMENTED_PROVENANCE_REQUIRED
CUSTOMER_INITIATED_SERVICE=BOUNDED_TO_ACTIVE_EXCHANGE_AND_STRICT_VALID_24_HOUR_WINDOW
UNRESOLVED_OUTBOUND_ELIGIBILITY=FAIL_CLOSED
MARKETING_BROADCASTS=DISABLED_FOR_MVP
RESEND_GATE_B=RETAINED_INCOMPLETE
CG1=MANDATORY_BEFORE_ANY_EXISTING_NEW_OR_MODIFIED_OUTBOUND_SEND_PATH
CG1_IMPLEMENTATION_AUTHORIZED=NO
CG1_IMPLEMENTATION_AUTHORIZED_IN_CHAT=NO
RELEASE_ONLY_POLICY_VALUES=PENDING_OWNER_DECISION_FAIL_CLOSED
AUTHORITY_PRECEDENCE=APPROVED_BY_OWNER_PENDING_REPOSITORY_ADOPTION
GATE_0=OWNER_ELECTRONIC_APPROVAL_RECORDED_REPOSITORY_ADOPTION_PENDING
SUPPORT_GATE_A=OWNER_APPROVED_NO_SEND_EXECUTION_BLOCKED_PENDING_REPOSITORY_ADOPTION_AND_PREFLIGHT
IMPLEMENTATION_AUTHORIZED=NO
PRODUCTION_AUTHORIZED=NO
WHATSAPP_FLOWS=POST_LAUNCH_SEPARATE_PURCHASE_UX_DESIGN_AND_RELEASE_GATE
MERGE_RECOMMENDATION=NO
STOP=SIGNED_GIT_PUBLICATION_AND_INDEPENDENT_REVIEW_PENDING
STOP=RELEASE_OUTBOUND_ELIGIBILITY_PENDING
STOP=GENUINE_RECIPIENTS_REQUIRE_APPROVED_MIGRATION
STOP=RECIPIENT_PROVENANCE_UNVERIFIED
STOP=IMPLEMENTATION_NOT_AUTHORIZED
```
