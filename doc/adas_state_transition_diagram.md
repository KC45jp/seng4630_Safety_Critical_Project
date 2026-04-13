# ADAS State Transition Diagram

This diagram reflects the current implementation after separating warning states from true faults and adding immediate safety transitions for `OVERRIDE` and emergency-safe-stop paths.

To reduce duplication while keeping the layout readable, it uses `super_state` groupings for the overall autopilot mode (`AUTO`) and the monitored operational flow (`OPERATIONAL`).

```mermaid
stateDiagram-v2
    direction TB
    [*] --> STANDBY

    STANDBY --> ENGAGING: ENGAGE [periodic replay]

    state "Autopilot Mode" as AUTO {
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
    SAFE_STOP --> STANDBY: OVERRIDE [immediate]
    SAFE_STOP --> [*]
```
