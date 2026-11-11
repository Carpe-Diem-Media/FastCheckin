# Solo-maintainer review policy

| Field | Value |
|---|---|
| Version | 1.0 |
| Status | PROPOSED |
| Scope | FastCheckin pull requests and retrospective review exceptions |
| Effective date | On adoption in signed Git history; not effective while this proposal is under review |

## Normal review

Independent human review is the normal path and remains required wherever an applicable higher-priority instruction makes it a merge condition. The owner remains accountable for each merge decision and must inspect the exact base and head, full diff, controlling authority, applicable CI and tests, unresolved findings, and repository status. An owner exception may replace a review only when no controlling rule prohibits that exception.

A separate AI session or agent may provide an adversarial technical assessment. Record it as AI review with its actual source and scope. It is not independent human approval, a GitHub review, or an owner decision. Do not describe it as such.

## When no independent human reviewer is available

The owner may authorize a documented solo-maintainer exception when no controlling rule prohibits it. The exception applies only to the identified PR and scope. It does not lower the evidence standard or transfer merge accountability.

The record must include:

- A unique exception decision ID.
- PR number, repository, base SHA, head SHA, and merge SHA if retrospective.
- Changed paths, scope, and risk classification.
- The exact controlling documents and any authority differences.
- CI status, actual test coverage, and checks that were not run.
- Any independent technical assessment that is available, with its author type and scope. Record when no independent human assessment was available.
- Outstanding findings and the specific risks the owner accepts.
- An explicit owner decision from an authenticated account, with decision date and the scope accepted.
- A statement that no historical review or approval is being created or implied.

The owner decision and final exception disposition must be preserved in signed Git history or in an authenticated, durable GitHub decision that is referenced by a signed record. Do not rewrite or backdate GitHub reviews.

## Limits

This policy alone does not authorize production deployment, destructive database operations, payment or ticket-integrity changes, weaker authorization or security, live customer messaging, secret or credential changes, or irreversible production state transitions. Those actions remain subject to their existing specific approval and acceptance gates. A review exception does not grant implementation, release, or production authority.

If a controlling rule prohibits an exception, or a material authority mismatch remains unresolved, stop. Do not use this policy to override that rule or mismatch.

## Retrospective exceptions

A retrospective request must name the already-merged PR and exact merge SHA. It must state that required pre-merge review did not occur, identify the review evidence that exists, and compare the merged content with the approved authority. It must record the owner's explicit risk acceptance and any unresolved findings. It cannot create a pre-merge approval, substitute for a historical GitHub review, or authorize later implementation or production activity.

## Decision lifecycle

Use one uniquely identified decision record and these states:

| State | Entry guard and required action |
|---|---|
| `PENDING` | Request identifies the PR or scope, owner, and missing review. No exception is granted. |
| `EVIDENCE_VERIFIED` | A maintainer has checked the exact diff and identities, authority, CI and test evidence, scope, findings, and signature status where applicable. Record the verifier and evidence. This is not owner acceptance. |
| `OWNER_ACCEPTED` | The authenticated owner explicitly accepts the identified residual risks and scope. No controlling-policy conflict or unresolved material authority mismatch may remain. Record the decision and date. |
| `CLOSED` | The decision record, evidence, and owner decision are preserved in signed Git history or referenced there by exact durable GitHub record identity. Closure grants no downstream gate. |
| `REJECTED` | The owner rejects the request, or a required guard fails. Record the reason and evidence. |

Allowed transitions are `PENDING -> EVIDENCE_VERIFIED -> OWNER_ACCEPTED -> CLOSED`. `PENDING` or `EVIDENCE_VERIFIED` may transition to `REJECTED`. No state may skip a guard. `CLOSED` and `REJECTED` are terminal. Do not reopen or edit a terminal decision; create a separately identified record for a new decision.

## Adoption

This policy becomes active only after it passes review and is adopted on signed Git history. It does not amend or override higher-priority instructions. Until adoption, use the existing review requirements and do not treat the proposal as an available waiver. Adoption of this policy does not accept any particular exception or close Gate 0.
