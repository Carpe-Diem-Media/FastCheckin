# WhatsApp sales sandbox certification proposal

Status: BLOCKED. `STOP=SALES_SANDBOX_BOUNDARY_UNSAFE`. This document is a
proposal, not an authorization, evidence of an isolated environment, or a
certification. Do not start SALES-08 or contact a provider until the boundary is
proved and the owner has separately recorded approval for the exact operation.
If the boundary is proved but that approval is absent, use
`STOP=SALES_SANDBOX_PROVIDER_AUTHORIZATION_MISSING`.

This supplements [Sandbox Dress Rehearsal](SANDBOX_DRESS_REHEARSAL.md),
[WhatsApp Launch Runbook](VS-23C_FINAL_WHATSAPP_LAUNCH_RUNBOOK.md), and
[Rollback and Pause Sales](ROLLBACK_AND_PAUSE_SALES.md). Their broader launch,
replay and retry instructions do not authorize actions here. This proposal uses
synthetic data only and excludes real customers.

## Owner decision and preflight evidence

Prefer an existing isolated nonproduction instance only if the owner designates
it and custodians provide evidence for the exact deployed release and boundary.
Do not provision or reconfigure anything under this document. The following are
all **MISSING**, including evidence that they exist:

- Environment, release, operator, shutdown owner and access-controlled evidence
  location; fixed synthetic event and offer, price, quantity and sales channel;
  start and end time with timezone.
- Fixed Meta business account, app, phone/sender and test customer identity;
  independently enforced inbound participant and outbound recipient allowlists.
  A sender-only outbound restriction does not restrict inbound discovery or OTP.
- Restricted OTP mail transport, sender and test mailbox; Paystack TEST merchant
  account; HTTPS application, callback, webhook and secure-ticket domains.
- Applicable template names, languages, provider approval and session-window
  availability; the scope and custodian of each evidence record.
- A dated explicit owner approval for the named test-only operations, identities,
  window, limits and stop authority. This approval is absent.

Record sensitive identities in an access-controlled authority and use safe
handles in the review record. Require a custodian's dated, sanitized evidence
binding the deployed environment and release to secret-store credential version
handles and the intended provider account and TEST mode. Require authenticated
provider-side TEST account/mode evidence correlated to that binding. Later, only
under explicit operation approval, correlate the exact transaction with provider
TEST records and server verification. Never make a transaction to find out whether
a credential is safe. Do not copy secrets, configuration dumps or headers into
logs or the record.

`PAYSTACK_ENVIRONMENT=test`, a key prefix, and
`META_WHATSAPP_SANDBOX_MODE` do not prove these controls. Paystack call
validation checks required values, timeout and channels, not credential mode.
WhatsApp ingress authenticates the raw-body signature and scopes the business
account and phone number, not the individual customer. On a shared runtime an
admitted customer can discover an enabled event with an active WhatsApp offer.
If isolation or TEST binding cannot be evidenced, keep the STOP. If a shared
runtime is unavoidable, seek a separate, narrowly scoped decision for a
default-deny customer/event/window boundary and TEST enforcement across the
uncovered paths. This proposal does not authorize an application change.

For custodian review, the relevant runtime key names are `PAYSTACK_ENABLED`,
`PAYSTACK_ENVIRONMENT`, `PAYSTACK_BASE_URL`, `PAYSTACK_PUBLIC_KEY`,
`PAYSTACK_SECRET_KEY`, `PAYSTACK_CALLBACK_URL`, `PAYSTACK_WEBHOOK_URL`,
`PAYSTACK_ALLOWED_CHANNELS`, `META_WHATSAPP_ENABLED`,
`META_WHATSAPP_BUSINESS_ACCOUNT_ID`, `META_WHATSAPP_PHONE_NUMBER_ID`,
`META_WHATSAPP_ACCESS_TOKEN`, `META_WHATSAPP_APP_SECRET`,
`META_WHATSAPP_VERIFY_TOKEN`, `META_WHATSAPP_SANDBOX_MODE`,
`META_GRAPH_API_BASE_URL`, `META_GRAPH_API_VERSION`,
`SALES_INTERNAL_PILOT_ENABLED`, `OTP_EMAIL_FROM_NAME`, and
`OTP_EMAIL_FROM_EMAIL`. Names are inventory, not proof of effective values or
restrictions. The configured mail adapter and delivery restriction need separate
custodian evidence; local/test mail adapters in source do not establish a safe
deployed transport. Keep other checkout entrypoints inaccessible to unapproved
operators.

## Event and offer controls

After all preconditions and operation approval, an authorized event operator
uses `/dashboard` and its event **WhatsApp Sales** control. Dashboard routes use
browser authentication and session revalidation; event access is grant-scoped.
The offer page `/dashboard/events/:event_id/whatsapp-offers` also checks event
access and offer policies. Confirm the selected synthetic event is disabled
before setup. Create the approved offer there with the agreed synthetic details,
leaving **Enable sales after inventory setup** unchecked. Creation can enable
sales when that checkbox is selected and inventory setup succeeds. After saving,
verify that both the resulting offer and event remain disabled, and record safe
evidence before the window.

The active-offer query checks enabled, archive, channel and time predicates.
However, offer administration creates `starts_at` and `ends_at` as nil and
its update action does not expose them. It does not provide an automatic cutoff.
At the approved start, an attending operator enables the offer and then event
sales. At the approved end, disable event sales and the offer, and verify both
states. Verify nondiscovery outside the window under the later approved runtime
procedure. If an independently enforced hard cutoff is required and no existing
control can be evidenced, STOP for a separate decision; do not assume the UI
provides one. Checkout rechecks event and offer eligibility, but this does not
restrict already queued work or all provider traffic.

## Future execution and evidence

Only after preflight evidence, independent review and exact owner approval,
follow the relevant purchase sequence in the rehearsal runbook using the fixed
identities. Confirm signed, account-scoped WhatsApp ingress at
`POST /api/v1/webhooks/whatsapp`; its verification endpoint is the corresponding
GET. A checkout can create a payment-link attempt. Paystack sends its signed
webhook to `POST /api/sales/paystack/webhook`; the browser return at
`GET /sales/payments/paystack/callback` requests server verification and is not
payment proof. Correlate the server-verified reference, amount and currency with
provider TEST evidence, then issuance and ticket delivery. Record the sanitized
callback source and result, not raw payloads. A provider-accepted send is not
recipient delivery; correlate the signed status where available.

The delivery policy chooses a session message inside its window and an
applicable template outside it, with manual review when a template is missing.
The local template catalog is not evidence of provider approval. Confirm the
actual approved language/template and window before any authorized send. Honor
STOP/privacy requests ahead of sales. STOP handling is state-dependent and is not
a global outbound kill switch. For timeout or uncertain payment or delivery,
stop and use manual review; do not blindly retry or infer success or failure.

Record timestamps, safe correlation handles, state transitions, sanitized
results and protected evidence references. Do not record raw phone numbers,
email addresses, OTPs, payment or ticket links, tokens, signatures or payloads.
The preparation itself has observed no real callbacks, sends or payments.

## Pause and end state

Follow [Rollback and Pause Sales](ROLLBACK_AND_PAUSE_SALES.md). Disable event
sales from `/dashboard`, disable the offer on its offer page, and verify both
remain disabled after the window. Event disablement stops new WhatsApp checkout;
existing orders can continue through payment, issuance and delivery. It does not
cancel queued messages, challenges or other provider traffic. Preserve the fixed
account and sender while residual jobs or challenges exist. An authorized
operator must inspect the residual state and assign uncertain items to
`/dashboard/sales/reviews`; use `/dashboard/sales/ops` and the order/audit pages
for the supported observations. Do not delete records, replay callbacks, change
accounts or force retries. If safe handling of residual work is unknown, stop and
obtain a separate decision. Keep the recovery paths described in the rollback
runbook available; do not mark the operation complete merely because the event
is disabled.

## Source references

- `lib/fastcheck_web/router.ex`, `lib/fastcheck_web/plugs/browser_auth.ex`,
  `lib/fastcheck_web/live/dashboard_live.ex`, and
  `lib/fastcheck_web/live/sales/whatsapp_offer_live.ex` define routes and controls.
- `lib/fastcheck/sales/offer_management.ex`, `lib/fastcheck/sales/ticket_offer.ex`,
  `lib/fastcheck/sales/checkout.ex`, and
  `lib/fastcheck/messaging/whatsapp/conversation_state_machine.ex` define offer,
  discovery and checkout gates.
- `config/runtime.exs`, `lib/fastcheck/payments/paystack/config.ex`,
  `lib/fastcheck/messaging/whatsapp/webhook_scope.ex`, `webhook_verifier.ex`,
  `delivery_policy.ex`, `outbound_delivery_policy.ex`, and `template_catalog.ex`
  define configuration, scope and delivery behavior. The last four paths are
  under `lib/fastcheck/messaging/whatsapp/`.
