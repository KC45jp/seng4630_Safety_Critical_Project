# ADAS State Transition Diagram

This diagram reflects the current implementation after separating warning states from true faults and adding immediate safety transitions for `OVERRIDE` and emergency-safe-stop paths.

```mermaid
stateDiagram-v2
    [*] --> STANDBY

    STANDBY --> ENGAGING: ENGAGE [periodic replay]

    state "Autopilot Mode" as AUTO {
        ENGAGING --> ACTIVE: healthy sensors [periodic]
        ENGAGING --> SENSOR_FAULT: invalid or timed-out sensors [periodic]
        ENGAGING --> SAFE_STOP: multiple sensor failures [immediate]

        ACTIVE --> WARNING_ACTIVE: overspeed or lane warning [periodic]
        WARNING_ACTIVE --> ACTIVE: recovery [periodic]

        ACTIVE --> SENSOR_FAULT: invalid sensor or timeout [periodic]
        WARNING_ACTIVE --> SENSOR_FAULT: invalid sensor or timeout [periodic]

        ACTIVE --> EMERGENCY: unsafe distance [immediate]
        WARNING_ACTIVE --> EMERGENCY: unsafe distance [immediate]
        SENSOR_FAULT --> EMERGENCY: unsafe distance [immediate]

        ACTIVE --> SAFE_STOP: multiple sensor failures [immediate]
        WARNING_ACTIVE --> SAFE_STOP: multiple sensor failures [immediate]
        SENSOR_FAULT --> SAFE_STOP: multiple sensor failures [immediate]
        EMERGENCY --> SAFE_STOP: stop reached or fatal condition [immediate]

        ENGAGING --> STANDBY: OVERRIDE [immediate]
        ACTIVE --> STANDBY: OVERRIDE or DISENGAGE [immediate/periodic]
        WARNING_ACTIVE --> STANDBY: OVERRIDE or DISENGAGE [immediate/periodic]
        SENSOR_FAULT --> STANDBY: OVERRIDE [immediate]
        EMERGENCY --> STANDBY: OVERRIDE [immediate]
    }

    SAFE_STOP --> STANDBY: OVERRIDE [immediate]
    SAFE_STOP --> [*]
```
