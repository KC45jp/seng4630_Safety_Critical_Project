# Package Rename Plan

## Goal

Simplify the Ada package and file naming scheme so the codebase is easier to read and the parent-package/main-program naming conflict disappears.

Current root name:

- `Autopilot_System`

Target root name:

- `Autopilot`

Main entry point target:

- `main.adb`

## Why This Change

- Current names are long and repetitive.
- Child packages such as `Autopilot_System.Types` require a parent package, which clashes with the current main procedure name `Autopilot_System`.
- Shorter names will make package references, file names, and future maintenance easier.

## Naming Strategy

Keep the Ada child-package structure, but shorten the root namespace.

Examples:

- `Autopilot_System.Types` -> `Autopilot.Types`
- `Autopilot_System.Vehicle_State` -> `Autopilot.Vehicle_State`
- `Autopilot_System.Sensors` -> `Autopilot.Sensors`
- `Autopilot_System.Fault_Detection` -> `Autopilot.Fault_Detection`
- `Autopilot_System.Control` -> `Autopilot.Control`
- `Autopilot_System.Driver_Input` -> `Autopilot.Driver_Input`

Main program:

- `procedure Autopilot_System` -> `procedure Main`

## Planned File Renames

- `autopilot_system.ads` -> `autopilot.ads`
- `autopilot_system-types.ads` -> `autopilot-types.ads`
- `autopilot_system-vehicle_state.ads` -> `autopilot-vehicle_state.ads`
- `autopilot_system-vehicle_state.adb` -> `autopilot-vehicle_state.adb`
- `autopilot_system-sensors.ads` -> `autopilot-sensors.ads`
- `autopilot_system-sensors.adb` -> `autopilot-sensors.adb`
- `autopilot_system-fault_detection.ads` -> `autopilot-fault_detection.ads`
- `autopilot_system-fault_detection.adb` -> `autopilot-fault_detection.adb`
- `autopilot_system-control.ads` -> `autopilot-control.ads`
- `autopilot_system-control.adb` -> `autopilot-control.adb`
- `autopilot_system-driver_input.ads` -> `autopilot-driver_input.ads`
- `autopilot_system-driver_input.adb` -> `autopilot-driver_input.adb`
- `autopilot_system.adb` -> `main.adb`

## Package Declaration Changes

- `package Autopilot_System is` -> `package Autopilot is`
- `package Autopilot_System.Types is` -> `package Autopilot.Types is`
- `package Autopilot_System.Vehicle_State is` -> `package Autopilot.Vehicle_State is`

Update all `with` / `use` clauses to the new root as well.

## Build Configuration Changes

- Change `.gpr` main file from `autopilot_system.adb` to `main.adb`
- Keep the `.gpr` project name unchanged at first to reduce migration risk

## Sensor/Fault Model Follow-Up

After renaming:

- each sensor component keeps its own `Timestamp`
- `Sensor_Data` keeps an aggregated `Overall_Fault`
- `Vehicle_State_Object` recalculates the aggregated fault on sensor updates

## Implementation Order

1. Rename the main program file to `main.adb`.
2. Add or keep a proper parent package spec `Autopilot`.
3. Rename all source files from `autopilot_system-*` to `autopilot-*`.
4. Update package declarations and `end` names.
5. Update all `with` and `use` clauses.
6. Update the `.gpr` main file reference.
7. Rebuild and fix remaining naming mismatches.
8. Continue the timestamp and aggregated fault integration.

## Risks

- Ada requires package names and file names to match exactly.
- Partial renames will break compilation.
- Scripts or tests using old names must also be updated.

## Success Criteria

- All source files use the shorter `Autopilot.*` hierarchy.
- The main entry point is separated from the parent package.
- The project builds without parent-package naming conflicts.
- The codebase is ready for the timestamp and aggregated fault work.
