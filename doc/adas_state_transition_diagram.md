# ADAS State Transition Diagram

This is the simplified state view of the current implementation. It keeps the major operational modes and collapses repeated arrows so the diagram is easier to read.

```mermaid
stateDiagram-v2
    [*] --> STANDBY

    note right of STANDBY
        manual / autopilot off
    end note

    STANDBY --> ENGAGING: ENGAGE [driver command]

    state "Autopilot Mode" as AUTO {
        [*] --> ENGAGING

        state "Driving Control" as DRIVE {
            [*] --> ACTIVE
            ACTIVE --> WARNING_ACTIVE: overspeed / lane deviation [periodic]
            WARNING_ACTIVE --> ACTIVE: warning cleared [periodic]
        }

        ENGAGING --> DRIVE: sensors healthy [periodic]
        ENGAGING --> SENSOR_FAULT: invalid sensor / timeout [periodic]

        DRIVE --> SENSOR_FAULT: invalid sensor / timeout [periodic]
        DRIVE --> EMERGENCY: unsafe distance [immediate]
    }

    AUTO --> STANDBY: OVERRIDE [immediate]
    DRIVE --> STANDBY: DISENGAGE [driver command]

    AUTO --> SAFE_STOP: multiple failures / fatal stop / stop complete
    SAFE_STOP --> STANDBY: OVERRIDE [immediate]

    note right of SAFE_STOP
        fail-safe landing state
    end note
```

Notes:

- `STANDBY` is outside `Autopilot Mode` because it represents manual driving or autopilot-off operation.
- `Autopilot Mode` contains `ENGAGING`, `Driving Control`, `SENSOR_FAULT`, and `EMERGENCY`.
- `Driving Control` groups `ACTIVE` and `WARNING_ACTIVE` because both represent autopilot-guided driving with different warning status.
- `SAFE_STOP` is outside `Autopilot Mode` because it is the fail-safe terminal mode for autonomous control.
- `OVERRIDE` is accepted immediately from any current state.
- `DISENGAGE` is only accepted from `ACTIVE` and `WARNING_ACTIVE`.
- This is a readability-first diagram; detailed trigger paths remain in the Ada implementation.
