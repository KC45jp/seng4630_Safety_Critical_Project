# ADAS Design Alternatives and Decision Matrix

This note summarizes the three design solutions considered during the iterative
engineering design process for the simplified ADAS project.

It complements the runtime diagrams in
[ADAS State Transition Diagram](./adas_state_transition_diagram.md) and
[Ada Internal Sequence Patterns](./ada_internal_sequence_patterns.md).

## Common Safety Baseline

All three solutions satisfy the core safety-critical requirements from the
project brief. The alternatives are not compared on whether they use these
mechanisms, but on how those mechanisms are organized and how easy they are to
verify.

Common elements in every solution:

- State-based logic for mode control
- Enumerated types for system states and fault levels
- Contracts or guarded checks on sensor values, actuator outputs, and state transitions
- Prevention of unsafe states such as autopilot engagement with invalid sensors
- Exception handling and fail-safe defaults
- Ada tasking, protected objects, and driver-command coordination

## Solution 1: Centralized Controller

Solution 1 uses a single main controller to read sensors, process driver
commands, classify faults, manage state transitions, and generate actuator
outputs. The full safety logic is kept in one place.

In this solution, the required state machine, contracts, and unsafe-state
prevention still exist, but they are implemented inside one central module
rather than being distributed across separate control and supervision layers.

Main strengths:

- Simple structure and low implementation overhead
- Deterministic behavior is easy to understand
- Useful as a baseline architecture

Main weaknesses:

- Limited modularity
- Safety responsibilities are concentrated in one unit
- Harder to scale cleanly as more features are added

## Solution 2: Hierarchical Supervision

Solution 2 separates normal driving logic from safety enforcement. Feature or
control components generate commands, while a higher-level safety supervisor
checks whether those commands and operating conditions are acceptable before the
commands are applied.

This solution still uses state-based logic, enumerated states, contracts, and
unsafe-state prevention. The main difference from Solution 1 is that safety
responsibility is now separated from nominal control responsibility.

Main strengths:

- Better modularity than Solution 1
- Clearer separation between normal control and safety supervision
- Improved fault handling and easier future extension

Main weaknesses:

- More design coordination between layers
- More interfaces to define and test
- Safety logic may still be expressed as scattered conditional checks rather
  than a fully explicit supervisory state machine

## Solution 3: Hierarchical Supervision with Explicit FSM

Solution 3 is a refinement of Solution 2. It keeps the hierarchical structure,
but the safety supervisor is implemented as an explicit finite state machine
(FSM). Operating modes such as `STANDBY`, `ENGAGING`, `ACTIVE`,
`WARNING_ACTIVE`, `SENSOR_FAULT`, `EMERGENCY`, and `SAFE_STOP` are treated as
formal system states with controlled transitions.

This solution still shares the same baseline safety mechanisms as the other
alternatives, but it makes them more explicit and easier to verify. Instead of
relying mainly on distributed rule checks, the design makes the allowed
transitions and fail-safe paths first-class parts of the architecture.

Main strengths:

- Strong modularity with clear supervisory responsibility
- Explicit safety states and deterministic transitions
- Strong fail-safe behavior and unsafe-state prevention
- Easier verification, testing, and traceability

Main weaknesses:

- Highest design complexity of the three options
- More transition cases to specify and validate
- Slightly more effort to maintain than Solution 2

## Decision Matrix

Scoring scale:

- `1` = weak
- `2` = moderate
- `3` = strong

Because all three solutions already include state-based logic, enumerated
states, contracts, and unsafe-state prevention, those items are treated as
common requirements rather than differentiating criteria.

| Criterion | Weight | S1: Centralized | S2: Hierarchical | S3: Hierarchical + FSM |
| --- | ---: | ---: | ---: | ---: |
| Simplicity of implementation | 1 | 3 | 2 | 1 |
| Modularity | 2 | 1 | 3 | 3 |
| Separation of safety responsibility | 3 | 1 | 3 | 3 |
| Fault handling capability | 3 | 2 | 3 | 3 |
| Determinism and verifiability | 3 | 2 | 2 | 3 |
| Fail-safe behavior clarity | 3 | 2 | 2 | 3 |
| Scalability | 2 | 1 | 3 | 3 |
| Weighted total | - | 28 | 44 | 49 |

## Final Selection

Solution 3 is the preferred final design.

The reason is not that it is the only solution with state-based logic or safety
rules, since all three solutions include those. Its advantage is that the
safety behavior is the most explicit and the most structured. That makes it a
better fit for a safety-critical Ada project that emphasizes deterministic
behavior, clear state transitions, contracts, and fail-safe operation.

At the same time, Solution 2 remains a strong intermediate step in the design
process. It is best viewed as the architectural predecessor to Solution 3,
rather than a completely unrelated alternative.

## Relationship to the Current Ada Implementation

The current Ada prototype is closest overall to Solution 3, with some
execution-style characteristics of Solution 1.

- The implementation uses explicit enumerated system states and guarded state transitions.
- It separates sensor replay, fault detection, control, and driver input into distinct Ada tasks.
- It uses a dedicated fault-detection path to supervise safety conditions.
- It also uses a periodic execution model for the main runtime tasks, which gives it some of the deterministic flavor of Solution 1.
- Immediate override and emergency reactions create a hybrid model: mostly periodic, but with direct safety intervention when required.

For that reason, the implementation is best described as a hierarchical
supervisory design with an explicit state machine, executed in a mostly
deterministic periodic runtime structure.
