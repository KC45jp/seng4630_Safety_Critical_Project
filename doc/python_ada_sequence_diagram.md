# Python-Ada Sequence Diagram

This diagram keeps the integration boundary intentionally simple:
Python validates scenario input, launches the Ada executable, then validates
the trace produced by Ada.

For Ada-internal runtime behavior, see
[Ada Internal Sequence Patterns](./ada_internal_sequence_patterns.md).

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Py as ScenarioTest.run_scenarios
    participant Schema as ScenarioSupport.scenario_schema
    participant Scenario as scenario.csv
    participant Ada as ./bin/main
    participant Trace as trace.csv

    User->>Py: run --scenario <name>
    Py->>Schema: read_scenario_csv(path)
    Schema->>Scenario: parse and validate rows
    Scenario-->>Schema: CSV content
    Schema-->>Py: ScenarioRow list

    Py->>Ada: subprocess.run(--scenario path --trace-out path)
    Note over Py,Ada: File-based boundary between Python and Ada

    Ada->>Scenario: replay scenario input
    Ada->>Trace: write observed trace rows
    Ada-->>Py: exit code

    Py->>Schema: read_trace_csv(path)
    Schema->>Trace: parse and validate rows
    Trace-->>Schema: CSV content
    Schema-->>Py: TraceRow list

    Py->>Py: compare expected state/fault/output window
    Py-->>User: PASS / FAIL
```
