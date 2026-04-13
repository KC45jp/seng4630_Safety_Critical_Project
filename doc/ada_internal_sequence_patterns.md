# Ada Internal Sequence Patterns

These diagrams focus on the main runtime collaboration inside Ada.

They are based on the state machine described in
[ADAS State Transition Diagram](./adas_state_transition_diagram.md).

Notes:

- `Shared State` is the protected object used by the Ada tasks to exchange state,
  fault, sensor, and actuator values.
- During scenario replay, `Sensor_Task` reuses `Driver_Input.Apply_Command(...)`
  directly. The `Driver_Input_Task.Send_Command` entry exists for external
  command delivery, but the replay path uses the shared command logic
  synchronously.

## Pattern 1: Normal Engage

```mermaid
sequenceDiagram
    autonumber
    participant Sensor as Sensor_Task
    participant Driver as Driver_Input
    participant State as Shared State
    participant Fault as Fault_Detection_Task
    participant Control as Control_Task

    Sensor->>Driver: Apply_Command(ENGAGE)
    Driver->>State: Set_State(ENGAGING)

    Sensor->>State: Update_Speed / Update_Distance / Update_Lane

    Fault->>State: Get_State + Get_Sensors
    alt sensors healthy and no timeout
        Fault->>State: Set_Fault(NONE)
        Fault->>State: Set_State(ACTIVE)
    else invalid or timed-out sensors
        Fault->>State: Set_Fault(CRITICAL)
        Fault->>State: Set_State(SENSOR_FAULT)
    end

    Control->>State: Get_State + Get_Sensors
    Control->>State: Set_Actuators(...)
```

## Pattern 2: Warning And Recovery

```mermaid
sequenceDiagram
    autonumber
    participant Sensor as Sensor_Task
    participant State as Shared State
    participant Fault as Fault_Detection_Task
    participant Control as Control_Task

    Sensor->>State: Update_Speed or Update_Lane

    Fault->>State: Get_State + Get_Sensors
    alt overspeed or lane deviation
        Fault->>State: Set_State(WARNING_ACTIVE)
    else values return to normal
        Fault->>State: Set_State(ACTIVE)
    end

    Control->>State: Get_State + Get_Sensors
    Control->>State: Set_Actuators(NOMINAL_OUTPUT)
```

## Pattern 3: Sensor Fault

```mermaid
sequenceDiagram
    autonumber
    participant Sensor as Sensor_Task
    participant State as Shared State
    participant Fault as Fault_Detection_Task
    participant Control as Control_Task

    Sensor->>State: Update sensor values
    Note over Sensor,State: Invalid value or timeout makes a sensor unhealthy

    Fault->>State: Get_State + Get_Sensors
    Fault->>State: Set_Fault(CRITICAL)
    Fault->>State: Set_State(SENSOR_FAULT)

    Control->>State: Get_State + Get_Sensors
    Control->>State: Set_Actuators(DEGRADED_OUTPUT)
```

## Pattern 4: Emergency To Safe Stop

```mermaid
sequenceDiagram
    autonumber
    participant Sensor as Sensor_Task
    participant State as Shared State
    participant Fault as Fault_Detection_Task
    participant Control as Control_Task

    Sensor->>State: Update_Distance / Update sensors
    Sensor->>Fault: Evaluate_Immediate_Critical_Transitions()

    alt unsafe following distance
        Fault->>State: Set_Fault(CRITICAL)
        Fault->>State: Set_State(EMERGENCY)
        Fault->>Control: Apply_Immediate_Output(EMERGENCY_NOW)
    else multiple sensor failures
        Fault->>State: Set_Fault(FATAL)
        Fault->>State: Set_State(SAFE_STOP)
        Fault->>Control: Apply_Immediate_Output(EMERGENCY_NOW)
    end

    Fault->>State: Get_State + Get_Sensors
    alt emergency vehicle stops or fatal condition persists
        Fault->>State: Set_State(SAFE_STOP)
    end

    Control->>State: Get_State + Get_Sensors
    Control->>State: Set_Actuators(EMERGENCY_OUTPUT)
```

## Pattern 5: Override Or Disengage

```mermaid
sequenceDiagram
    autonumber
    participant Sensor as Sensor_Task
    participant Driver as Driver_Input
    participant State as Shared State
    participant Control as Control_Task

    Sensor->>Driver: Apply_Command(OVERRIDE or DISENGAGE)

    alt OVERRIDE
        Driver->>State: Set_State(STANDBY)
        Driver->>Control: Apply_Immediate_Output(IDLE_NOW)
    else DISENGAGE from ACTIVE or WARNING_ACTIVE
        Driver->>State: Set_State(STANDBY)
    end

    Control->>State: Get_State + Get_Sensors
    Control->>State: Set_Actuators(IDLE_OUTPUT)
```
