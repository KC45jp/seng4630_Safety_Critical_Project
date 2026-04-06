# seng4630_Safety_Critical_Test

# Scenario Commands

Run everything from the repository root unless noted otherwise.

## Build Ada

```bash
cd autopilot_system
alr build
cd ..
```

## Generate Scenario CSV Files

```bash
python3 -m SensorData.MainGenerator
```

This regenerates all integrated scenario CSV files under `SensorData/scenarios/`.

## List Available Scenarios

```bash
python3 -m ScenarioTest.run_scenarios list
```

## Validate Scenario CSV Schema Only

Validate all scenario CSV files:

```bash
python3 -m ScenarioTest.run_scenarios validate-scenarios
```

Validate one scenario CSV file:

```bash
python3 -m ScenarioTest.run_scenarios validate-scenarios --scenario nominal_engage_cruise
```

## Run and Validate Scenarios

Run and validate all scenarios:

```bash
python3 -m ScenarioTest.run_scenarios run
```

Run and validate one scenario:

```bash
python3 -m ScenarioTest.run_scenarios run --scenario nominal_engage_cruise
```

Print the commands without executing Ada:

```bash
python3 -m ScenarioTest.run_scenarios run --dry-run
```

## Validate an Existing Trace

```bash
python3 -m ScenarioTest.run_scenarios validate-trace \
  --scenario nominal_engage_cruise \
  --trace ScenarioTest/traces/nominal_engage_cruise.trace.csv
```

## Run Ada Directly

You can also run the Ada executable directly after building:

```bash
cd autopilot_system
./bin/main \
  --scenario ../SensorData/scenarios/nominal_engage_cruise.csv \
  --trace-out ../ScenarioTest/traces/manual_nominal.trace.csv
cd ..
```

## Notes

- Scenario inputs live in `SensorData/scenarios/`.
- Generated trace CSV files are written under `ScenarioTest/traces/`.
- `transition_lookback_ticks` and `note` in the scenario CSV files explain transition-boundary tolerance for validation.
