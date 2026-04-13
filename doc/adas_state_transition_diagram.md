# ADAS State Transition Diagram

This is the simplified state view of the current implementation. It keeps the major operational modes and collapses repeated arrows so the diagram is easier to read.

To reduce duplication while keeping the layout readable, it uses `super_state` groupings for the overall autopilot mode (`AUTO`) and the monitored operational flow (`OPERATIONAL`).

```mermaid
stateDiagram-v2
    direction TB
    [*] --> STANDBY

    note right of STANDBY
        manual / autopilot off
    end note

    STANDBY --> ENGAGING: ENGAGE [driver command]

    state "Autopilot Mode" as AUTO {
<<<<<<< HEAD
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
=======
        direction TB

        state "Operational States" as OPERATIONAL {
            direction LR
            [*] --> ACTIVE

            ACTIVE --> WARNING_ACTIVE: overspeed or lane warning [periodic]
            WARNING_ACTIVE --> ACTIVE: recovery [periodic]

            ACTIVE --> SENSOR_FAULT: invalid sensor or timeout [periodic]
            WARNING_ACTIVE --> SENSOR_FAULT: invalid sensor or timeout [periodic]
        }

        ENGAGING --> ACTIVE: healthy sensors [periodic]
        ENGAGING --> SENSOR_FAULT: invalid or timed-out sensors [periodic]
        ENGAGING --> SAFE_STOP: multiple sensor failures [immediate]

        ACTIVE --> EMERGENCY: unsafe distance [immediate]
        WARNING_ACTIVE --> EMERGENCY: unsafe distance [immediate]
        SENSOR_FAULT --> EMERGENCY: unsafe distance [immediate]

        OPERATIONAL --> SAFE_STOP: multiple sensor failures [immediate]
        EMERGENCY --> SAFE_STOP: stop reached or fatal condition [immediate]
    }

    AUTO --> STANDBY: OVERRIDE [immediate]
    ACTIVE --> STANDBY: DISENGAGE [periodic]
    WARNING_ACTIVE --> STANDBY: DISENGAGE [periodic]
>>>>>>> 41ba543 (fix degraded output bug)
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
