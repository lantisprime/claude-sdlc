---
slug: payments
last_reviewed: 2026-04-25
owner: platform-team
suggested_roles: [product, security, compliance]
---
# Payments

## Glossary

- **Idempotency key** — a client-generated unique ID that prevents a duplicate charge if a request is retried after a timeout. Required for any mutating payment operation.
- **PCI scope** — the set of systems that store, process, or transmit cardholder data. Reducing PCI scope (via tokenization or a hosted-fields approach) reduces audit burden.
- **Tokenization** — replacing a raw card number with a processor-issued token. The token is useless outside the processor's system; your system never stores the PAN.
- **Webhook signature** — a HMAC signature the payment processor attaches to event payloads. Must be verified before processing to prevent spoofed events.
- **Idempotent refund** — a refund that is safe to retry; the processor deduplicates by refund ID.
- **Reconciliation** — the process of matching your internal ledger against the processor's settlement records. Gaps indicate lost events or processing errors.

## Typical NFRs

- All payment operations must be idempotent — retrying a timed-out request must not produce a duplicate charge or refund.
- Webhook endpoints must respond within 5 seconds (most processors retry on timeout; slow handlers cause duplicate event processing).
- Audit trail: every state transition (initiated, authorized, captured, refunded, disputed) must be logged with timestamp and actor.
- Cardholder data must never appear in application logs, error messages, or crash reports.

## Regulatory concerns

- **PCI-DSS**: Applies to any system that stores, processes, or transmits cardholder data. Using a processor's hosted fields or tokenization can reduce scope to SAQ-A or SAQ-A-EP, avoiding the full SAQ-D audit. This plugin does not deliver PCI-DSS compliance — it surfaces the question.
- **Strong Customer Authentication (SCA / PSD2)**: Required for card-present and most online payments in the EU/EEA. 3D Secure v2 is the standard implementation. Check whether your processor handles SCA automatically or requires explicit flow changes.
- **OFAC / sanctions screening**: Some payment flows require checking payer identity against sanctions lists. Processor-level screening exists but coverage varies.

## Common pitfalls

- **Missing idempotency keys**: Forgetting to send an idempotency key on charge or refund calls. Network errors cause retries; without keys, users get double-charged.
- **Trusting webhook payload without signature verification**: Attackers can POST fake event payloads to trigger refunds or fulfillment. Always verify `Stripe-Signature` / processor equivalent before acting.
- **Webhook retry storms**: A slow or erroring handler causes the processor to retry, which causes more load, which causes more errors. Use a queue to decouple receipt from processing.
- **Race condition on concurrent refunds**: Two support agents initiating a refund simultaneously can exceed the original charge amount. Lock by order/charge ID before issuing refunds.
- **Logging card data accidentally**: Logging the full request body during debugging. PAN exposure in logs is a PCI incident.
- **Assuming processor errors are final**: `card_declined` errors from the network can be retried; `insufficient_funds` usually can't. Handle error codes specifically, not generically.

## Stack notes

- **Stripe**: Use `stripe-node` / `stripe-python` SDK. Idempotency keys go in the `Idempotency-Key` header (SDK handles this via `idempotencyKey` option). Webhook verification via `stripe.webhooks.constructEvent`.
- **Braintree**: GraphQL API preferred over REST for new integrations. Idempotency handled via client SDK nonce — nonces are single-use.
- **PayPal**: REST API v2 for Orders. `PayPal-Request-Id` header is the idempotency key. Webhook verification requires fetching event via API (don't trust the payload directly).
- Regardless of processor: store the processor's transaction/charge ID alongside your internal order ID from the moment of creation, not just on success.

## Security hotspots

- **Payment form inputs**: Must be hosted fields (iframes served by the processor) or fully PCI-scoped. Never collect raw card numbers in your own DOM.
- **Webhook endpoint**: Must be unauthenticated (processor can't send credentials) but signature-verified. Rate-limit it separately from user-facing endpoints.
- **Refund authorization**: Refund triggers must be gated behind internal authorization checks — not just "is the user authenticated" but "is the user authorized to refund this order."
- **Processor API keys**: Must be in `tools.local.json` (never committed). Rotate on any suspected exposure. Publishable keys (client-side) and secret keys (server-side) have different exposure risk profiles.
- **Order state machine**: Ensure transitions are enforced server-side. A client claiming an order is "paid" before the processor confirms it is a classic fraud vector.

## Scope must address

- PCI scope boundary: which systems are in-scope, and the strategy for reducing scope (tokenization, hosted fields, or full SAQ-D)
- Which payment processor(s) are in use
- Whether SCA / 3D Secure applies to the target markets
- Idempotency strategy for charge and refund operations
- Reconciliation approach: how your ledger is kept in sync with processor settlements

## Questions plan must answer

- Which payment processor is in use, and which SDK/API version? (required: true)
- Is this change PCI-scoped? If yes, what is the cardholder data isolation strategy? (required: true)
- What is the idempotency key strategy for mutating operations (charges, refunds, captures)?
- How are webhook events authenticated (signature verification mechanism)?
- Is SCA / 3D Secure required for the target markets? If yes, which flow?
- How are processor API keys stored and rotated?
- Is there an existing reconciliation job? Does this change affect what it needs to reconcile?
