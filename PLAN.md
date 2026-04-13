# ADAS Project Implementation Plan

**SENG 4630 — Safety Critical Software Systems**
Due: April 14, 2026

---

## 1. Project Overview

Implement a simplified Car Autopilot / Driver Assistance System (ADAS) in Ada.
All sensors and actuators are simulated in software.

**Requirements summary (from spec):**

| Item | Detail |
|---|---|
| Language | Ada 2012 |
| Sensors (simulated) | Speed, front distance, lane position |
| Actuators (simulated) | Throttle, brake, steering |
| Driver inputs | engage / disengage / manual override |
| Required Ada concepts | Tasks/rendezvous, Protected objects, Contracts, Enumerated types |
| Fault classification | Classified by severity level (see Section 3.4) |

---

## 2. Package Structure

```
autopilot_system/src/
├── autopilot_system.adb                      ← Main entry point (launches all tasks)
├── autopilot_system-types.ads                ← Shared types and constants (spec only)
├── autopilot_system-vehicle_state.ads/.adb   ← Protected object (shared state hub)
├── autopilot_system-sensors.ads/.adb         ← Sensor task
├── autopilot_system-fault_detection.ads/.adb ← Fault detection task
├── autopilot_system-control.ads/.adb         ← Control task
└── autopilot_system-driver_input.ads/.adb    ← Driver input task (rendezvous)
```

---

## 3. Package Details

### 3.1 `Autopilot_System.Types` (spec only, `.ads`)

Defines all shared types and constants. Every other package `with`s this one.

```ada
package Autopilot_System.Types is

   -- State machine nodes
   type System_State is (
      STANDBY,      -- Waiting (autopilot off)
      ENGAGING,     -- Safety check in progress before activation
      ACTIVE,       -- Autopilot running normally
      WARNING_ACTIVE,  -- Minor fault (warning only, driving continues)
      SENSOR_FAULT,  -- Major fault (degraded control)
      EMERGENCY,    -- Emergency braking in progress
      SAFE_STOP     -- Vehicle stopped safely (terminal state)
   );

   -- Fault severity levels
   type Fault_Level is (NONE, CRITICAL, FATAL);

   -- Sensor data record
   type Sensor_Data is record
      Speed          : Float;   -- km/h
      Front_Distance : Float;   -- m (distance to front obstacle)
      Lane_Offset    : Float;   -- m (lateral offset from lane centre)
      Valid          : Boolean; -- False if sensor is unavailable/timed out
   end record;

   -- Actuator output record
   type Actuator_Output is record
      Throttle : Float;   -- 0.0 to 1.0
      Brake    : Float;   -- 0.0 to 1.0
      Steering : Float;   -- -1.0 (full left) to 1.0 (full right)
   end record;

   -- Driver commands
   type Driver_Command is (ENGAGE, DISENGAGE, OVERRIDE);

   -- Safety constants
   MAX_SPEED         : constant Float    := 130.0;  -- km/h
   MIN_SAFE_DISTANCE : constant Float    := 10.0;   -- m
   MAX_LANE_OFFSET   : constant Float    := 0.5;    -- m
   SENSOR_TIMEOUT    : constant Duration := 0.5;    -- seconds

end Autopilot_System.Types;
```

---

### 3.2 `Autopilot_System.Vehicle_State` (Protected object)

Manages all shared data that multiple tasks read and write concurrently.
Uses Ada's `protected` construct to prevent race conditions.

```
[Access pattern]
Sensor_Task        → writes sensor data
Fault_Detection    → reads sensor data, writes state/fault level
Driver_Input_Task  → writes state (override / engage / disengage)
Control_Task       → reads sensor data + current state
```

```ada
protected type Vehicle_State_Object is
   procedure Update_Sensors (Data : in Sensor_Data);
   procedure Set_State      (S    : in System_State);
   procedure Set_Fault      (F    : in Fault_Level);
   function  Get_Sensors    return Sensor_Data;
   function  Get_State      return System_State;
   function  Get_Fault      return Fault_Level;
private
   Sensors : Sensor_Data  := (...);
   State   : System_State := STANDBY;
   Fault   : Fault_Level  := NONE;
end Vehicle_State_Object;
```

---

### 3.3 `Autopilot_System.Sensors` (Task)

Runs every 50 ms. Simulates sensor readings and updates `Vehicle_State`.

- Values generated from random numbers or pre-scripted scenarios
- Records a timestamp for timeout detection
- Sets `Valid := False` when a value is out of range or missing

```ada
task type Sensor_Task is
   entry Start;
   entry Stop;
end Sensor_Task;
```

---

### 3.4 `Autopilot_System.Fault_Detection` (Task)

Runs every 100 ms. Monitors `Vehicle_State` and classifies any faults.

| Condition | Fault Level | Action |
|---|---|---|
| Sensor value out of range | CRITICAL | Transition to SENSOR_FAULT |
| Sensor timeout | CRITICAL | Transition to SENSOR_FAULT |
| Front distance < MIN_SAFE_DISTANCE | CRITICAL | Transition to EMERGENCY |
| Speed > MAX_SPEED | NONE | Transition to WARNING_ACTIVE |
| Multiple sensors failed simultaneously | FATAL | Transition to SAFE_STOP |

```ada
task type Fault_Detection_Task is
   entry Start;
end Fault_Detection_Task;
```

---

### 3.5 `Autopilot_System.Control` (Task)

Runs every 100 ms. Calculates and outputs actuator commands based on current state.

| State | Control behaviour |
|---|---|
| STANDBY | throttle=0, brake=0, steering=0 (no output) |
| ACTIVE | Speed control + lane keeping (simplified proportional control) |
| WARNING_ACTIVE | Normal control continues + warning displayed |
| SENSOR_FAULT | Throttle reduced, brake prepared |
| EMERGENCY | throttle=0, brake=1.0 (full braking) |
| SAFE_STOP | brake=1.0 until speed=0, then hold |

```ada
task type Control_Task is
   entry Start;
end Control_Task;
```

---

### 3.6 `Autopilot_System.Driver_Input` (Task + rendezvous)

Accepts driver commands via rendezvous and applies them to `Vehicle_State`.

- `ENGAGE` — STANDBY → ENGAGING (transitions to ACTIVE after safety check passes)
- `DISENGAGE` — ACTIVE → STANDBY
- `OVERRIDE` — any state → STANDBY immediately (highest priority)

```ada
task type Driver_Input_Task is
   entry Send_Command (Cmd : in Driver_Command);
   entry Start;
end Driver_Input_Task;
```

---

## 4. State Machine

```
                  ┌─────────────────┐
                  │     STANDBY     │◄─── OVERRIDE / DISENGAGE
                  └────────┬────────┘
                           │ ENGAGE
                           ▼
                  ┌─────────────────┐
                  │    ENGAGING     │  (sensor health check)
                  └────────┬────────┘
           sensors OK ─────┘  └───── sensors NG
                  ▼                        ▼
         ┌────────────────┐     ┌──────────────────┐
         │     ACTIVE     │     │   SENSOR_FAULT    │
         └──┬─────────┬───┘     └────────┬─────────┘
    warning │         │ critical fault   │
            ▼         ▼                  │
   ┌────────────┐  ┌──────────┐          │
   │WARNING_ACTIVE │  │EMERGENCY │◄─────────┘ collision danger
   └────────────┘  └────┬─────┘
                        │ stopped
                        ▼
                  ┌─────────────┐
                  │  SAFE_STOP  │  (terminal state)
                  └─────────────┘
```

---

## 5. Ada Concepts Summary

| Concept | Where used |
|---|---|
| **Tasks** | Sensor_Task, Fault_Detection_Task, Control_Task, Driver_Input_Task |
| **Rendezvous** | `Driver_Input_Task.Send_Command` entry |
| **Protected objects** | `Vehicle_State_Object` (shared sensor data and state) |
| **Contracts (Pre/Post)** | `Set_State` transition guards, sensor value range checks |
| **Enumerated types** | `System_State`, `Fault_Level`, `Driver_Command` |
| **Exception handling** | Sensor read failures, invalid state transitions |

---

## 6. External Libraries

| Library | Recommendation | Reason |
|---|---|---|
| **AUnit** (`alr with aunit`) | Strongly recommended | Unit testing for fault detection logic. Manual testing alone is risky for safety-critical systems. |
| Others | Not needed | `Ada.Real_Time`, `Ada.Text_IO`, `Ada.Numerics` from the standard library are sufficient. |

---

## 7. Implementation Order

1. `Types` package (type definitions)
2. `Vehicle_State` package (protected object)
3. `Sensors` task (simulated sensor values)
4. `Fault_Detection` task (fault detection logic)
5. `Control` task (actuator output)
6. `Driver_Input` task (rendezvous)
7. Update `autopilot_system.adb` to launch all tasks
8. (Optional) Add AUnit tests

---

## 8. Notes and Warnings

- The spec says **Ada 2012**. Ada 2022 is backwards-compatible so it is fine to use, but confirm with the instructor before submitting.
- Execution complexity must be kept to a minimum (spec Design requirement #2).
- Fault conditions must be classified by severity level (spec Design requirement #3).
- This is a **group project** — teamwork strategy is also part of the grade.



# Solutions Considered Previously
Solution 1: Centralized Controller Architecture

In Solution 1, the entire ADAS is managed by a single central controller. This controller reads all sensor inputs, processes driver commands, detects faults, and generates throttle, braking, and steering outputs. All decision-making is performed in one place, which makes the design simple, deterministic, and easy to implement. This approach has low execution complexity and is suitable as a baseline design. However, because all responsibilities are concentrated in one module, the controller can become large and less modular as the system grows.

Main strengths: simplicity, low complexity, deterministic behavior
Main weakness: limited modularity and reduced separation of safety responsibilities

Solution 2: Hierarchical Supervisor Architecture

In Solution 2, the system is divided into feature-specific controllers such as cruise control and lane keeping, while a higher-level safety supervisor monitors the whole system. Each feature controller produces its own commands, and the supervisor checks whether those commands are safe before they are sent to the actuators. If unsafe conditions are detected, such as invalid sensors, timeouts, or driver override, the supervisor can override the normal commands and force a safe response. This architecture improves modularity and separates normal driving logic from safety enforcement. Compared with Solution 1, it is more scalable and better suited for fault handling, although it is also more complex to implement.

Main strengths: modularity, clearer safety separation, better fault handling
Main weakness: more design and coordination complexity than Solution 1

Solution 3: Hierarchical Supervisor with State-Machine Safety Logic (Final Solution)

Solution 3 is a refined version of Solution 2. It keeps the hierarchical architecture, but the safety supervisor is implemented as a finite state machine. Instead of relying only on scattered rule-based checks, the system explicitly manages operating modes such as Off, Ready, Active, Manual Override, Degraded, Fault, and Emergency Stop. State transitions are triggered by events such as engage requests, sensor failures, driver override, or imminent collision. This makes the safety behavior more explicit, deterministic, and easier to verify. It also supports fail-safe operation more clearly because unsafe states can be prevented through controlled transitions. For this reason, Solution 3 is the strongest final design.

Main strengths: explicit safety states, deterministic transitions, strong fail-safe behavior, easier verification and testing
Main weakness: slightly higher design complexity than Solution 2

Overall Comparison
Solution 1 is the simplest and most straightforward design.
Solution 2 improves modularity by separating feature control from safety supervision.
Solution 3 further improves Solution 2 by using a finite state machine to make safety logic clearer and more robust.

Recommended final solution:
Solution 3, because it combines modular architecture with explicit and deterministic safety management.