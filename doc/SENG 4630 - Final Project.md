# ADAS

**Course:** SENG 4630 - Safety Critical Software Systems  
**Project:** Car Autopilot / Driver Assistance System (ADAS)  
**Team Members:** `TBD`  
**Student IDs:** `TBD`  
**Date Submitted:** April 13, 2026

## 1. Executive Summary

This report presents the design, implementation, and evaluation of a simplified Advanced Driver Assistance System (ADAS) developed in Ada 2012 for a safety-critical software systems course. The project goal was to create a fail-safe, deterministic software prototype that can assist a driver using simulated speed, distance, and lane-position sensors while coordinating throttle, braking, and steering outputs under both normal and faulty conditions.

Three candidate architectures were considered. Solution 1 used a single centralized controller and offered low implementation complexity, but it concentrated too many safety responsibilities in one module. Solution 2 separated feature controllers from a higher-level safety supervisor and improved modularity and fault handling. Solution 3, the final design, retained the hierarchical structure of Solution 2 and strengthened it by implementing the safety supervisor as a finite state machine with explicit operating modes: `STANDBY`, `ENGAGING`, `ACTIVE`, `WARNING_ACTIVE`, `SENSOR_FAULT`, `EMERGENCY`, and `SAFE_STOP`. This made safety behavior more deterministic, testable, and easier to verify.

The final prototype was implemented as a concurrent Ada system using tasks, rendezvous, protected shared state, contracts, and enumerated types, as required by the project specification [1]. Sensor inputs are replayed from CSV scenarios, control actions are computed periodically, and all system behavior is recorded into trace files for validation. Final testing covered 17 integrated scenarios, including nominal operation, overspeed, lane deviation, emergency braking, single-sensor invalid data, sensor timeouts, multiple simultaneous failures, and driver override. All 17 scenarios were executed and validated successfully using the repository scenario runner.

The project achieved its main objectives of safety, determinism, modularity, and testability while satisfying the assignment constraints. The main limitations are that the prototype is software-only, uses simplified control laws and threshold-based safety logic, and does not model full real-vehicle dynamics. Even with those limitations, the final design demonstrates a credible safety-critical architecture and a disciplined engineering process suitable for further refinement.

## 2. Introduction

Modern vehicles increasingly rely on software-intensive driver assistance functions, and failures in those systems can directly affect human safety. For this reason, an ADAS cannot be treated as a conventional software project; it must be designed around deterministic behavior, explicit safety rules, fail-safe defaults, and controlled responses to faulty inputs. The project brief for SENG 4630 requires a simplified Ada-based ADAS that coordinates simulated sensors, driver commands, and actuator outputs while remaining robust under sensor failures and unsafe operating conditions [1].

The purpose of this report is to document the engineering design process used to create that ADAS prototype. The report defines the design problem, identifies stakeholders and their needs, compares three alternative architectures, justifies the final solution, and presents evidence from prototype testing. The scope of the work is a software-in-the-loop prototype rather than a physical vehicle implementation. As a result, the report focuses on software structure, operating states, timing behavior, fault classification, and traceable scenario validation rather than hardware fabrication.

The final thesis of this report is that a hierarchical ADAS architecture with a supervisor implemented as an explicit finite state machine is the most appropriate solution for this project. It provides better separation of concerns than a single monolithic controller, supports clearer fail-safe behavior than loosely organized rule checks, and is easier to test and reason about under safety-critical conditions [2], [3].

## 3. Design Problem

The design problem in this project is to create a simplified ADAS that helps a driver maintain safe motion while preventing the software from entering or remaining in unsafe states. Because the project is safety-critical, the design must do more than simply generate steering or braking commands. It must also detect faults, classify their severity, enforce valid operating modes, allow immediate human override, and drive the system toward a safe state whenever inputs become unreliable or dangerous conditions are detected.

### 3.1 Problem Definition

The need addressed by this project is the gap between normal automated driving assistance and safe operation under abnormal conditions. A naive autopilot can perform well when sensors are healthy and the environment is benign, but it becomes dangerous if sensor values are implausible, if communication times out, if a collision threat appears suddenly, or if the driver needs to take back control immediately. Therefore, the problem is not only to automate some vehicle functions, but to automate them in a way that remains deterministic, fail-safe, and explainable under fault conditions.

For this course project, the system must safely coordinate simulated vehicle sensors, driver commands, and actuator outputs. It must permit autopilot engagement only when conditions are acceptable, maintain nominal control when conditions remain safe, classify faults by severity, and degrade or stop safely when those conditions are no longer met. The design must also be practical to implement in Ada 2012 and structured so that its safety behavior can be tested with repeatable scenarios.

### 3.2 Design Requirements

The project requirements were derived from the course overview, which specifies the required functions, the Ada language constraints, and the safety focus for the prototype [1].

#### 3.2.1 Functions

The ADAS shall provide the following functions:

1. Safely engage and disengage autopilot mode.
2. Accept immediate driver override from any active autonomous mode.
3. Maintain a target cruising speed under nominal conditions.
4. Monitor lane position and generate steering correction commands.
5. Detect unsafe front distance and apply emergency braking.
6. Detect invalid sensor values and missing sensor updates.
7. Classify faults by severity and trigger an appropriate response.
8. Prevent unsafe operating states, such as sustained autonomous control with failed sensors.
9. Log state, fault, and actuator behavior for scenario-based validation.

#### 3.2.2 Objectives

The design objectives are expressed as desirable attributes of the final system:

- Safe
- Deterministic
- Reliable
- Modular
- Testable
- Maintainable
- Economical

Objective tree:

```text
Safe
|- fail-safe fault response
|- immediate driver override
|- emergency braking on collision risk

Deterministic
|- explicit operating states
|- bounded periodic control cycles
|- valid state-transition rules

Reliable
|- sensor plausibility checks
|- timeout detection
|- fault severity classification

Modular
|- separated sensor, control, driver, and fault packages
|- isolated shared state
|- clear supervisor responsibility

Testable
|- scenario replay inputs
|- trace-file validation
|- observable state and fault transitions

Maintainable
|- readable package structure
|- enumerated state definitions
|- localized threshold constants

Economical
|- software-only prototype
|- reuse of free/open tooling
|- no dedicated hardware purchases
```

#### 3.2.3 Constraints

The following constraints are binary requirements: a candidate solution either satisfies them or it does not.

1. The implementation must use Ada 2012.
2. The system must use simulated speed, distance, and lane-position sensors.
3. The system must use simulated throttle, braking, and steering outputs.
4. The system must accept `ENGAGE`, `DISENGAGE`, and `OVERRIDE` driver inputs.
5. The design must apply safety-critical concepts including tasks, rendezvous, protected objects, contracts, and enumerated state types [1].
6. Fault conditions must be classified by severity level.
7. The design must remain fail-safe under invalid sensor data and timeout conditions.
8. Execution logic should remain low in complexity and predictable at runtime.
9. The design must be deliverable within the course schedule and student budget.

## 4. Stakeholders

Several stakeholders are affected by this design even though the prototype is implemented in simulation.

| Stakeholder | Primary Need | Design Response |
| --- | --- | --- |
| Driver | Safe assistance without loss of control | Immediate override, explicit disengagement, transparent state changes |
| Passenger | Safe and comfortable operation | Stable control outputs, emergency braking on collision risk, fail-safe behavior |
| Vehicle manufacturer / integrator | Modular, testable architecture | Separate runtime packages, state-machine supervision, trace-based validation |
| Safety assessor / regulator | Evidence that hazards are identified and controlled | Fault classification, deterministic states, repeatable scenarios, trace outputs |
| Software developers / maintainers | Readable and maintainable implementation | Shared type package, protected state object, isolated control and fault logic |
| Course instructor / evaluator | Demonstration of engineering process and Ada concepts | Design alternatives, documented requirements, testing evidence, Ada tasking and contracts |

The most important stakeholder needs are safety, controllability, determinism, and credible evidence that the software behaves correctly when conditions become unsafe.

## 5. Scheduling and Budgeting

The project followed milestone-driven development aligned with the course deliverables [1].

### 5.1 Milestone Schedule

| Milestone | Planned Date | Deliverable |
| --- | --- | --- |
| Requirements and problem definition complete | Feb. 25, 2026 | Problem definition and initial report sections |
| Alternative designs and architecture comparison complete | Mar. 09, 2026 | Solution development section |
| Ada implementation and scenario replay working | Mar. 30, 2026 | Prototype implementation |
| Teamwork and project management updates complete | Apr. 06, 2026 | Team and management sections |
| Final validation, report integration, and submission | Apr. 14, 2026 | Final report, prototype, presentation |

### 5.2 Responsibility Assignment Matrix

Replace the names below with the actual team members before submission.

| Work Item | Member A | Member B | Member C | Member D |
| --- | --- | --- | --- | --- |
| Requirements analysis and stakeholder mapping | R | A | C | I |
| Architecture alternatives and final design selection | A | R | C | I |
| Ada runtime implementation | C | A/R | I | I |
| Scenario generation and validation tooling | I | C | A/R | I |
| Report writing and editing | C | C | C | A/R |
| Final integration and presentation | R | R | R | A |

Legend: `R` = Responsible, `A` = Accountable, `C` = Consulted, `I` = Informed.

### 5.3 Budget Estimate

Because this is a software-only prototype, no new hardware was purchased specifically for the project.

| Resource | Source | Estimated New Cost |
| --- | --- | --- |
| Ada compiler / tooling | Existing course environment / free tooling | $0 |
| Python 3 scenario tooling | Existing installation / free tooling | $0 |
| Git / repository hosting | Existing free academic tooling | $0 |
| Development computers | Student-owned or institution-provided | $0 project-specific |
| Total new out-of-pocket cost |  | **$0** |

This low-cost development approach satisfied the economic objective of producing a safety-focused prototype without adding hardware procurement risk or cost.

## 6. Solution Development

Three valid architectural alternatives were considered. Each solution could satisfy the core functional requirements, but they differ in how they organize decision-making, safety responsibility, and fault handling.

### 6.1 Solution 1: Centralized Controller Architecture

In Solution 1, the entire ADAS is managed by a single central controller. This controller reads all sensor inputs, processes driver commands, detects faults, and generates throttle, braking, and steering outputs. All decision-making is performed in one place, which makes the design simple, deterministic, and easy to implement. This approach has low execution complexity and is suitable as a baseline design. However, because all responsibilities are concentrated in one module, the controller can become large and less modular as the system grows.

Advantages:

- Simple structure and straightforward implementation
- Low execution complexity
- Easy to trace nominal control flow
- Good baseline for early prototyping

Disadvantages:

- Poor separation between nominal control and safety enforcement
- Limited scalability as new features are added
- Harder to isolate and test safety behavior independently
- A defect in the central controller can affect the entire system

### 6.2 Solution 2: Hierarchical Supervisor Architecture

In Solution 2, the system is divided into feature-specific controllers such as cruise control and lane keeping, while a higher-level safety supervisor monitors the whole system. Each feature controller produces its own commands, and the supervisor checks whether those commands are safe before they are sent to the actuators. If unsafe conditions are detected, such as invalid sensors, timeouts, or driver override, the supervisor can override the normal commands and force a safe response. This architecture improves modularity and separates normal driving logic from safety enforcement. Compared with Solution 1, it is more scalable and better suited for fault handling, although it is also more complex to implement.

Advantages:

- Better modularity than a monolithic controller
- Clearer separation between driving logic and safety logic
- Improved fault handling and supervisor-based override
- Easier extension to additional ADAS features

Disadvantages:

- More coordination complexity between controllers
- Requires more careful interface design
- Safety behavior may still be distributed across multiple rules if not formalized

### 6.3 Solution 3: Hierarchical Supervisor with State-Machine Safety Logic (Final Solution)

Solution 3 is a refined version of Solution 2. It keeps the hierarchical architecture, but the safety supervisor is implemented as a finite state machine. Instead of relying only on scattered rule-based checks, the system explicitly manages operating modes such as `STANDBY`, `ENGAGING`, `ACTIVE`, `WARNING_ACTIVE`, `SENSOR_FAULT`, `EMERGENCY`, and `SAFE_STOP`. State transitions are triggered by events such as engage requests, sensor failures, driver override, or imminent collision. This makes the safety behavior more explicit, deterministic, and easier to verify. It also supports fail-safe operation more clearly because unsafe states can be prevented through controlled transitions. For this reason, Solution 3 is the strongest final design.

Advantages:

- Explicit safety states and controlled transitions
- Strong fail-safe behavior
- Clear distinction between warning, degraded, emergency, and safe-stop modes
- Better verification and scenario-based testing support
- Good balance between modularity and determinism

Disadvantages:

- Slightly higher design complexity than Solution 2
- Requires disciplined transition design and validation
- More design effort is needed upfront

### 6.4 Final Solution Selection

Overall comparison:

- Solution 1 is the simplest and most straightforward design.
- Solution 2 improves modularity by separating feature control from safety supervision.
- Solution 3 further improves Solution 2 by using a finite state machine to make safety logic clearer and more robust.

Recommended final solution:

- Solution 3, because it combines modular architecture with explicit and deterministic safety management.

Comparison summary:

| Criterion | Solution 1 | Solution 2 | Solution 3 |
| --- | --- | --- | --- |
| Simplicity | High | Medium | Medium |
| Modularity | Low | High | High |
| Safety separation | Low | Medium-High | High |
| Fault handling | Basic | Strong | Strongest |
| Ease of verification | Medium | Medium | High |
| Suitability as final design | Acceptable baseline | Good | Best |

The final implementation aligns with the component structure and state decomposition documented in the project diagrams [2], [3].

### 6.5 Components and Features

The final prototype is organized into a small set of Ada packages with clear responsibilities:

| Component | Role |
| --- | --- |
| `Main` | Starts the concurrent tasks, configures scenario replay, and reports final state/fault |
| `Autopilot_System.Domain.Types` | Defines system states, fault levels, sensor data, actuator outputs, thresholds, and transition helpers |
| `Autopilot_System.Runtime.State` | Protected object that stores shared sensors, state, fault, actuator outputs, and sensor timestamps |
| `Autopilot_System.Runtime.Control` | Computes throttle, brake, and steering commands based on current state and sensor values |
| `Autopilot_System.Runtime.Fault_Detection` | Monitors sensor validity, timeouts, overspeed, lane deviation, and collision risk; applies safe transitions |
| `Autopilot_System.IO.Sensors` | Replays scenario CSV rows, updates sensor values, and writes trace files |
| `Autopilot_System.IO.Driver_Input` | Accepts driver commands through rendezvous and applies `ENGAGE`, `DISENGAGE`, or `OVERRIDE` |
| Python scenario tooling | Generates scenario CSV files and validates trace files against expected behavior |

Feature summary:

1. Safe engagement: `ENGAGE` moves the system from `STANDBY` to `ENGAGING`, after which sensor health is evaluated before normal autonomous control continues.
2. Adaptive speed control: the control task computes throttle from the difference between current speed and target speed, while also reducing throttle when distance becomes small.
3. Lane keeping: steering output is computed from lane offset under valid operating conditions.
4. Warning handling: overspeed and lane deviation cause `WARNING_ACTIVE`, allowing continued operation while signaling abnormal conditions.
5. Degraded mode: invalid data or sensor timeout causes `SENSOR_FAULT`, where output becomes conservative.
6. Emergency behavior: unsafe front distance triggers `EMERGENCY`, which applies full braking immediately.
7. Safe stop: severe or persistent conditions lead to `SAFE_STOP`, the fail-safe landing state.
8. Driver authority: `OVERRIDE` returns the system to `STANDBY` immediately.

Although the prototype is software-only, the control outputs correspond to real physical processes in a deployed vehicle. A throttle command represents a chain from stored energy to vehicle motion, a brake command dissipates kinetic energy as thermal energy, and a steering command represents electrical and mechanical actuation that changes the vehicle heading. In this prototype, those transformations are abstracted into software signals rather than being physically modeled.

## 7. Prototype Development and Testing

The prototype was developed incrementally. Early work focused on defining states, shared data, and valid transitions. Later work added scenario replay, trace generation, and validation so that the system could be tested under repeatable conditions rather than by ad hoc manual inspection. This was important because safety-critical behavior must be demonstrable and not only plausible.

### 7.1 Initial Testing

Initial testing was performed by running targeted scenarios that exercised one important behavior at a time. The first set of checks focused on nominal engagement, warning generation, collision response, and driver override. Once the nominal behavior was stable, additional cases were added for implausible sensor values and timeout conditions.

The main improvements made during iterative testing were:

1. Introducing per-sensor validity flags instead of a single shared validity value.
2. Tracking individual sensor update timestamps so that timeouts can be detected explicitly.
3. Separating fault detection from control calculation so safety decisions are not hidden inside actuator logic.
4. Adding immediate output application for `OVERRIDE` and emergency conditions.
5. Adding trace-file generation so the observed state, fault, and actuator outputs can be validated automatically.
6. Extending the scenario set to cover recovery from warning conditions and multiple simultaneous failures.

These improvements made the final system more observable, more modular, and safer under abnormal conditions.

### 7.2 Report on Final Testing

Final testing was performed using the repository scenario runner:

```bash
python3 -m ScenarioTest.run_scenarios run
```

This executed and validated 17 scenario files. The scenarios covered nominal operation, warning conditions, emergency response, invalid sensor inputs, timeouts, multiple simultaneous failures, recovery, and driver override.

| Requirement / Objective | Test Method | Measure of Success | Result |
| --- | --- | --- | --- |
| Safe autopilot engagement | `nominal_engage_cruise` | System reaches `ACTIVE` with `NONE` fault under healthy sensors | Pass |
| Immediate driver override | `driver_override` | System returns to `STANDBY` when override is issued | Pass |
| Overspeed warning behavior | `overspeed_minor_fault` | System enters `WARNING_ACTIVE`, suppresses throttle, then recovers to `ACTIVE` | Pass |
| Lane deviation warning behavior | `lane_deviation_minor_fault` | System enters `WARNING_ACTIVE`, applies steering correction, then recovers | Pass |
| Emergency braking on unsafe distance | `distance_emergency_stop` | System enters `EMERGENCY`, applies full brake, then reaches `SAFE_STOP` | Pass |
| Detection of single invalid sensor value | `single_*_invalid_*` scenarios | System transitions to `SENSOR_FAULT` with `CRITICAL` fault | Pass |
| Detection of sensor timeout | `single_*_timeout` scenarios | Missing updates cause timeout-driven `SENSOR_FAULT` | Pass |
| Fail-safe handling of multiple failures | `multiple_sensor_failure_safe_stop` | Multiple simultaneous sensor failures lead to `SAFE_STOP` with `FATAL` fault | Pass |
| Recovery from minor warnings | `minor_fault_recovery` | System returns from `WARNING_ACTIVE` to `ACTIVE` after the condition clears | Pass |

Final testing summary:

- Total scenarios executed: 17
- Total scenarios validated: 17
- Total scenario validation failures: 0

The test evidence demonstrates that the prototype satisfies the major functional and safety requirements of the assignment within the limits of a software simulation.

### 7.3 Environmental, Societal, Safety, and Economic Considerations

This project considered more than pure functionality. Because ADAS behavior can affect human trust, road safety, and deployment cost, the design also addressed societal and economic factors. From a societal perspective, the system was designed to assist rather than replace driver responsibility. The immediate override behavior reinforces that the human operator remains in ultimate control. From a safety perspective, the design treats invalid sensors, timeouts, and collision threats as first-class events rather than as edge cases. From an economic perspective, the prototype minimizes cost by using a software-only architecture and free tooling while still providing structured testing and validation.

#### 7.3.1 Safety Analysis

The safety analysis for this prototype can be expressed more clearly using two complementary views: a Failure Hazard Assessment (FHA) and a Preliminary System Safety Assessment (PSSA). The FHA identifies hazardous failure conditions at the system level and estimates their consequences. The PSSA then maps those hazards onto the selected architecture and explains how the design is intended to control them. Because this is a software-only course prototype rather than a certifiable production vehicle, the severity ratings below are qualitative.

##### Failure Hazard Assessment (FHA)

| Hazardous failure condition | Potential effect on vehicle or occupants | Severity | Safety objective |
| --- | --- | --- | --- |
| Autopilot continues operating with invalid or timed-out sensor data | Incorrect throttle, braking, or steering decisions could be issued from an unreliable perception picture | High | Detect invalid or stale data quickly and remove normal autonomous authority |
| Unsafe front distance is not handled in time | Rear-end collision or inability to stop before impact | High | Detect collision danger and force immediate emergency braking |
| Driver override is ignored or delayed | Human operator loses timely authority to recover the vehicle | High | Accept override from any autonomous mode and return control to the driver |
| Autopilot permits persistent overspeed | Reduced stopping margin and increased accident severity | Medium | Warn, suppress acceleration, and degrade safely until conditions recover |
| Lane deviation is not corrected or is corrected too late | Lane departure or sideswipe risk | Medium | Detect excessive lane offset and apply bounded corrective steering |
| Runtime failure, illegal transition, or software exception occurs during operation | Undefined behavior, frozen outputs, or unsafe persistence of autonomous control | High | Constrain state evolution and force the system into a conservative fail-safe condition |

The FHA shows that the most serious hazards are those that allow the software to keep controlling the vehicle when its inputs are unreliable, when a collision threat is imminent, or when the driver cannot immediately retake control. These hazards shaped the final architecture more strongly than convenience-oriented functions such as speed holding.

##### Preliminary System Safety Assessment (PSSA)

The selected Solution 3 architecture addresses the FHA hazards through explicit state-machine supervision, protected shared state, conservative output selection, and fault-driven transitions. Instead of leaving safety responses distributed across ad hoc control rules, the design allocates each major hazard to a defined detection and mitigation path.

| FHA hazard | Architectural safety measure in the PSSA | Expected effect |
| --- | --- | --- |
| Invalid or stale sensor data during autonomous operation | Sensor plausibility limits and timeout monitoring are treated as first-class safety checks. A single sensor failure moves the system to `SENSOR_FAULT`, while multiple sensor failures drive the system to `SAFE_STOP`. | Prevents continued nominal control on unreliable inputs |
| Failure to stop for a collision threat | Short front distance triggers an immediate transition to `EMERGENCY`, and the control logic applies full braking with zero throttle. If conditions worsen or multiple failures occur, the system escalates to `SAFE_STOP`. | Prioritizes collision avoidance over comfort or feature continuity |
| Loss of driver authority | The state model permits transition to `STANDBY` on override, and the design intent is that `OVERRIDE` is honored immediately from autonomous modes. | Restores human control as the final authority |
| Overspeed or lane departure under otherwise healthy sensing | These are treated as operational warnings rather than immediate fatal failures. The system enters `WARNING_ACTIVE`, suppresses throttle when overspeeding, and applies bounded steering correction for lane offset. | Provides graceful degradation before more severe action is needed |
| Internal runtime or state-management failure | State changes are checked against valid transitions, shared data is protected, and exception handlers attempt to force a conservative fail-safe response with emergency or safe-stop outputs. | Limits the effect of software faults and reduces the chance of undefined autonomous behavior |

This PSSA indicates that the prototype has a coherent safety strategy: hazards are detected early, mapped to explicit supervisory states, and answered with conservative actuator outputs. That is an appropriate result for a course-scale ADAS prototype because it improves determinism, traceability, and testability.

Residual risk still remains. The prototype has no hardware redundancy, no independent watchdog processor, no validated real-vehicle dynamics, and no production-grade human-machine interface. Therefore, the FHA/PSSA result should be interpreted as evidence that the software architecture is safety-oriented and fail-safe by design for simulation, not that it is ready for road deployment without further engineering, verification, and certification.

#### 7.3.2 Economic Considerations

The prototype remained under budget because it reused existing software tools and did not require dedicated hardware purchases.

| Item | Estimated Cost |
| --- | --- |
| New hardware components | $0 |
| New software licenses | $0 |
| Existing computers and lab resources | already available |
| Total new project expenditure | **$0** |

This low direct cost is one advantage of a simulated prototype. However, a production ADAS would require significant additional investment in hardware integration, sensing redundancy, human-machine interface design, certification, testing, and compliance work.

#### 7.3.3 Life Cycle and Environmental Impact Analysis

The environmental impact of this project is relatively small because the prototype is digital and uses existing computers. It avoids new sensors, embedded boards, batteries, and printed hardware for the current course stage. This reduces material consumption and electronic waste compared with building a physical prototype prematurely.

3R considerations:

- Reduce: use a software-only prototype and existing development machines.
- Reuse: reuse open-source tools, reusable scenario files, and maintainable code modules.
- Recycle: if future hardware is added, choose components that support responsible e-waste recycling and long service life.

Recommendations for reducing environmental impact in future iterations:

1. Continue validating logic in simulation before purchasing hardware.
2. Reuse existing development hardware for as long as possible.
3. Keep scenario data and reports digital rather than printed where possible.
4. If physical components are introduced later, select durable parts and recycle retired electronics responsibly.

### 7.4 Limitations

The prototype has several important limitations:

1. It is a software-only simulation and does not control a real vehicle.
2. The control law is simplified and does not include full vehicle dynamics, actuator lag, road curvature, weather, or sensor noise models.
3. Safety decisions are mainly threshold-based rather than formally verified against a full hazard analysis standard.
4. The user interface and operator alerting are minimal.
5. Cybersecurity and malicious input handling are outside the current project scope.
6. Because the system uses periodic concurrent tasks, an invalid sample arriving near an engagement boundary may be handled one cycle later than the engage request; the final design still drives the system to a safe state, but the transition is not yet a fully atomic engage authorization model.

These limitations do not invalidate the educational value of the prototype, but they do define the boundary between a course project and a deployable automotive system.

## 8. Team Work

This section summarizes team structure and meeting records. The text below is written so it can be used directly, but the team names, student IDs, exact times, and final task ownership should be updated before submission.

### 8.1 Group Roles and Responsibilities

| Team Member | Role | Main Responsibility |
| --- | --- | --- |
| Member A (`TBD`) | Requirements and architecture lead | Problem definition, stakeholders, design comparison |
| Member B (`TBD`) | Ada runtime lead | Core Ada packages, state and control logic |
| Member C (`TBD`) | Test and tooling lead | Scenario generation, trace validation, test execution |
| Member D (`TBD`) | Report and integration lead | Documentation, editing, final integration and presentation |

### 8.2 Meeting 1

**Time:** `TBD`  
**Present:** `TBD`  
**Agenda:** scope definition, stakeholder identification, initial role assignment, and report planning

Meeting minutes:

- The team reviewed the course overview and confirmed that the project must be implemented in Ada 2012 with safety-critical concepts such as tasks, protected objects, contracts, and explicit states.
- The group agreed that the main design challenge was not only nominal control, but also safe operation under faulty sensor conditions.
- Initial responsibilities were divided between requirements, architecture exploration, implementation, and testing/documentation.

Task assignment:

| Team Member | Previous Task | Completion State | Next Task |
| --- | --- | --- | --- |
| Member A | N/A | N/A | Draft problem definition and stakeholder section |
| Member B | N/A | N/A | Explore Ada package structure and shared-state design |
| Member C | N/A | N/A | Prepare scenario and test strategy |
| Member D | N/A | N/A | Set up report structure and meeting records |

Record of team rule penalty:

- No penalties recorded at this stage.

### 8.3 Meeting 2

**Time:** `TBD`  
**Present:** `TBD`  
**Agenda:** compare alternative architectures and select a final design direction

Meeting minutes:

- The team compared a centralized controller, a hierarchical supervisor, and a hierarchical supervisor with explicit state-machine logic.
- Solution 1 was considered easiest to implement but too monolithic for safety responsibility.
- Solution 2 improved modularity, but the team decided that Solution 3 was the best final direction because it made safety states and transitions explicit.
- The group agreed to build the software around a protected shared state object plus separate concurrent tasks for sensors, control, fault monitoring, and driver input.

Task assignment:

| Team Member | Previous Task | Completion State | Next Task |
| --- | --- | --- | --- |
| Member A | Problem definition draft | Complete | Write architecture comparison section |
| Member B | Package structure exploration | Complete | Implement state and control packages |
| Member C | Test strategy draft | Complete | Build scenario and trace workflow |
| Member D | Report scaffold | Complete | Update report with selected design |

Record of team rule penalty:

- No penalties recorded.

### 8.4 Meeting 3

**Time:** `TBD`  
**Present:** `TBD`  
**Agenda:** implementation review, scenario coverage, and fault-handling refinement

Meeting minutes:

- The team reviewed progress on the Ada implementation and confirmed that the state machine, fault detection, and control logic were all operational.
- Additional test scenarios were proposed for overspeed, lane deviation, invalid sensor values, timeouts, and multiple simultaneous failures.
- The group discussed how warning conditions should recover and how emergency output should be applied immediately.
- Trace-based validation was selected as the main evidence mechanism for final testing.

Task assignment:

| Team Member | Previous Task | Completion State | Next Task |
| --- | --- | --- | --- |
| Member A | Architecture comparison | Complete | Draft testing and safety sections |
| Member B | State/control implementation | In progress | Finalize fault handling and transition logic |
| Member C | Scenario tooling | In progress | Add final scenarios and validate trace rules |
| Member D | Report update | In progress | Integrate diagrams and revise wording |

Record of team rule penalty:

- No penalties recorded.

### 8.5 Meeting 4

**Time:** `TBD`  
**Present:** `TBD`  
**Agenda:** final validation, report integration, conclusions, and submission planning

Meeting minutes:

- The team reviewed the final scenario run and confirmed that all defined scenarios validated successfully.
- Remaining work focused on cleaning up the report, documenting limitations, and preparing the final presentation.
- The team agreed that the final report should explicitly distinguish the educational prototype from a production automotive system.

Task assignment:

| Team Member | Previous Task | Completion State | Next Task |
| --- | --- | --- | --- |
| Member A | Testing section draft | Complete | Final proofreading |
| Member B | Fault-handling refinement | Complete | Final code review |
| Member C | Scenario validation | Complete | Archive final traces and test evidence |
| Member D | Report integration | Complete | Final submission packaging |

Record of team rule penalty:

- No penalties recorded.

Final summary of team rule penalty records:

| Scores | Team member 1 | Team member 2 | Team member 3 | Team member 4 |
| --- | --- | --- | --- | --- |
| Name | `TBD` | `TBD` | `TBD` | `TBD` |
| Student ID | `TBD` | `TBD` | `TBD` | `TBD` |
| Total mark | `TBD` | `TBD` | `TBD` | `TBD` |
| Notes and Comments | No penalty recorded | No penalty recorded | No penalty recorded | No penalty recorded |

## 9. Project Management

The project was managed using milestone-based planning with iterative implementation and repeated validation. The main management strength was that architecture, implementation, and testing were developed together instead of leaving validation until the end. This reduced integration risk and allowed the team to discover design gaps early.

### 9.1 Task Schedule

| Task ID | Task | Duration | Predecessor | Assigned To | Slack |
| --- | --- | --- | --- | --- | --- |
| T1 | Requirements analysis and stakeholder identification | 2 weeks | none | Member A | 2 days |
| T2 | Alternative architecture development and comparison | 2 weeks | T1 | Members A, B | 2 days |
| T3 | State machine and package design | 1.5 weeks | T2 | Member B | 1 day |
| T4 | Ada implementation of runtime and I/O packages | 3 weeks | T3 | Members B, C | 2 days |
| T5 | Scenario generation and trace validation tooling | 2.5 weeks | T3 | Member C | 2 days |
| T6 | Integration testing and bug fixing | 1.5 weeks | T4, T5 | Members B, C, D | 1 day |
| T7 | Final report, diagrams, and presentation preparation | 2 weeks | T2, T6 | Members A, D | 2 days |

Simple Gantt-style view:

```text
Weeks ->   W1  W2  W3  W4  W5  W6  W7  W8
T1 Req     [==][==]
T2 Alt Sol     [==][==]
T3 FSM/Arch            [==]
T4 Ada Impl                [==][==][==]
T5 Scenarios               [==][==]
T6 Integration                         [==][==]
T7 Report/Pres                 [==][==][==]
Milestones
M1 Problem Def      *
M2 Solution Dev             *
M3 Implementation                      *
M4 Final Submission                              *
```

### 9.2 Management Review

What went well:

1. The team selected an architecture early enough to keep the implementation focused.
2. Scenario-driven testing gave fast feedback and helped keep safety requirements concrete.
3. Package-level separation reduced merge and integration risk.
4. Continuous report updates prevented a last-minute documentation crisis.

What could be improved next time:

1. Formalize engagement authorization further so that edge timing cases are handled more atomically.
2. Add unit tests for lower-level helper logic in addition to scenario-based integration tests.
3. Define meeting attendance and progress records more consistently from the first week.
4. Add buffer time for polishing diagrams and presentation materials.

## 10. Conclusions

This project produced a working software prototype of a simplified safety-critical ADAS in Ada 2012. The final design satisfies the major required functions: safe engagement and disengagement, target-speed assistance, lane-monitoring support, emergency braking, driver override, sensor fault detection, severity-based fault classification, and fail-safe behavior under abnormal conditions. The project also satisfied the main design constraints by using Ada tasks, rendezvous, protected objects, contracts, and enumerated state types.

The most important outcome of the design process was the selection of a hierarchical supervisor architecture with explicit state-machine safety logic. That solution provided the best balance between simplicity, modularity, fault handling, and verifiability. Prototype testing using 17 scenario files showed that the system behaved correctly across nominal, warning, fault, emergency, and override cases. The final implementation is not a production automotive controller, but it is a credible demonstration of how safety-critical software design principles can be applied to a concurrent control system.

This project also reinforced several engineering lessons. Safety logic should be explicit rather than hidden inside nominal control code. Fault handling must be designed from the beginning, not added after the normal case works. Deterministic states and traceable testing make complex concurrent behavior easier to reason about. Most importantly, a safety-critical system should always prioritize safe degradation and human control over uninterrupted automation.

## 11. References

[1] Department of Engineering, "Safety Critical Software Systems - SENG 4630: Car Autopilot / Driver Assistance System (ADAS)," course overview, Winter 2026. Available: `doc/SENG_4630_Overview_2026.md`

[2] Project Team, "ADAS State Transition Diagram," project design document. Available: `doc/adas_state_transition_diagram.md`

[3] Project Team, "ADAS Component Diagram," project design document. Available: `doc/adas_component_diagram.md`

[4] Project Team, "Repository README and Scenario Commands," project documentation. Available: `README.md`

## 12. Appendix

### Appendix A. Useful Project Artifacts

- Overview document: `doc/SENG_4630_Overview_2026.md`
- State diagram: `doc/adas_state_transition_diagram.md`
- Component diagram: `doc/adas_component_diagram.md`
- Scenario runner: `ScenarioTest/run_scenarios.py`
- Scenario definitions: `SensorData/scenario_generator.py`

### Appendix B. Example Validation Command

```bash
python3 -m ScenarioTest.run_scenarios run
```

### Appendix C. Notes for Final Submission Cleanup

Before final submission, replace the following placeholders:

1. Team member names and student IDs
2. Meeting times and attendee lists
3. Final grading/penalty table entries, if required
4. Any figures or screenshots the team wants to embed directly into the final exported report
