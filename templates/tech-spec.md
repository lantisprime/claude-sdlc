# Technical Spec: <module-or-service>

- **Owners:** <names>
- **Covers REQs:** REQ-xxx, REQ-yyy
- **Last updated:** <date>

## Responsibility

<What this module/service is responsible for. One paragraph.>

## Public interface

### `function_name(args) -> ReturnType`

- **Purpose:** …
- **Inputs:** …
- **Outputs:** …
- **Error modes:** …
- **Side effects:** …

## Internal data

- <entity>: fields, invariants, lifecycle

## NFRs

- Latency: p95 ≤ <n> ms
- Throughput: ≥ <n> req/s
- Availability: <n>%
- Security controls: <list>

## Deviations from architecture

<Any place this spec refines or deviates from the architecture doc, with justification.>
