from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path

from ScenarioSupport.scenario_schema import ScenarioRow, write_scenario_csv

DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "scenarios"
IMPLAUSIBLE_SPEED_HIGH = 160.0
IMPLAUSIBLE_SPEED_LOW = -5.0
IMPLAUSIBLE_DISTANCE_HIGH = 300.0
IMPLAUSIBLE_DISTANCE_LOW = -5.0
IMPLAUSIBLE_LANE_HIGH = 6.0
IMPLAUSIBLE_LANE_LOW = -6.0


@dataclass(frozen=True)
class ScenarioDefinition:
    name: str
    rows: list[ScenarioRow]


def _transition_boundary_note(note: str) -> str:
    suffix = "transition boundary; one tick early transition acceptable"
    if not note:
        return suffix
    if suffix in note:
        return note
    return f"{note}; {suffix}"


def _immediate_note(note: str) -> str:
    suffix = "must apply immediately"
    if not note:
        return suffix
    if suffix in note:
        return note
    return f"{note}; {suffix}"


def _annotate_transition_boundaries(rows: list[ScenarioRow]) -> list[ScenarioRow]:
    annotated: list[ScenarioRow] = []
    previous: ScenarioRow | None = None

    for row in rows:
        is_boundary = (
            previous is not None
            and (
                row.expected_state != previous.expected_state
                or row.expected_fault != previous.expected_fault
                or row.expected_actuator_mode != previous.expected_actuator_mode
            )
        )

        if is_boundary and row.transition_window_ticks > 0:
            row = replace(
                row,
                transition_lookback_ticks=max(row.transition_lookback_ticks, 1),
                note=_transition_boundary_note(row.note),
            )

        annotated.append(row)
        previous = row

    return annotated


def scenario_definitions() -> list[ScenarioDefinition]:
    definitions = [
        ScenarioDefinition(
            name="nominal_engage_cruise",
            rows=_nominal_engage_cruise(),
        ),
        ScenarioDefinition(
            name="overspeed_minor_fault",
            rows=_overspeed_minor_fault(),
        ),
        ScenarioDefinition(
            name="lane_deviation_minor_fault",
            rows=_lane_deviation_minor_fault(),
        ),
        ScenarioDefinition(
            name="distance_emergency_stop",
            rows=_distance_emergency_stop(),
        ),
        ScenarioDefinition(
            name="engage_blocked_invalid_sensor",
            rows=_engage_blocked_invalid_sensor(),
        ),
        ScenarioDefinition(
            name="single_speed_invalid_high",
            rows=_single_sensor_invalid("speed", "high"),
        ),
        ScenarioDefinition(
            name="single_speed_invalid_low",
            rows=_single_sensor_invalid("speed", "low"),
        ),
        ScenarioDefinition(
            name="single_distance_invalid_high",
            rows=_single_sensor_invalid("distance", "high"),
        ),
        ScenarioDefinition(
            name="single_distance_invalid_low",
            rows=_single_sensor_invalid("distance", "low"),
        ),
        ScenarioDefinition(
            name="single_lane_invalid_high",
            rows=_single_sensor_invalid("lane", "high"),
        ),
        ScenarioDefinition(
            name="single_lane_invalid_low",
            rows=_single_sensor_invalid("lane", "low"),
        ),
        ScenarioDefinition(
            name="single_speed_timeout",
            rows=_single_sensor_timeout("speed"),
        ),
        ScenarioDefinition(
            name="single_distance_timeout",
            rows=_single_sensor_timeout("distance"),
        ),
        ScenarioDefinition(
            name="single_lane_timeout",
            rows=_single_sensor_timeout("lane"),
        ),
        ScenarioDefinition(
            name="multiple_sensor_failure_safe_stop",
            rows=_multiple_sensor_failure_safe_stop(),
        ),
        ScenarioDefinition(
            name="minor_fault_recovery",
            rows=_minor_fault_recovery(),
        ),
        ScenarioDefinition(
            name="driver_override",
            rows=_driver_override(),
        ),
    ]

    return [
        ScenarioDefinition(
            name=definition.name,
            rows=_annotate_transition_boundaries(definition.rows),
        )
        for definition in definitions
    ]


def generate_all_scenarios(output_dir: Path = DEFAULT_OUTPUT_DIR) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    generated_paths: list[Path] = []
    for scenario in scenario_definitions():
        output_path = output_dir / f"{scenario.name}.csv"
        write_scenario_csv(output_path, scenario.rows)
        generated_paths.append(output_path)

    generated_names = {path.name for path in generated_paths}
    for existing_path in output_dir.glob("*.csv"):
        if existing_path.name == "scenario_manifest.csv":
            continue
        if existing_path.name not in generated_names:
            existing_path.unlink()

    return generated_paths


def _default_actuator_mode(expected_state: str) -> str:
    if expected_state in {"STANDBY", "ENGAGING"}:
        return "IDLE_OUTPUT"
    if expected_state == "SENSOR_FAULT":
        return "DEGRADED_OUTPUT"
    if expected_state in {"EMERGENCY", "SAFE_STOP"}:
        return "EMERGENCY_OUTPUT"
    return "NOMINAL_OUTPUT"


def _default_note(expected_state: str, expected_fault: str) -> str:
    if expected_state == "STANDBY" and expected_fault == "NONE":
        return "standby before engage"
    if expected_state == "ENGAGING":
        return "engage requested; waiting for healthy sensors"
    if expected_state == "ACTIVE" and expected_fault == "NONE":
        return "nominal active cruise"
    if expected_state == "STANDBY" and expected_fault != "NONE":
        return "standby after driver override"
    if expected_state == "WARNING_ACTIVE":
        return "warning condition"
    if expected_state == "SENSOR_FAULT":
        return "major fault condition"
    if expected_state == "EMERGENCY":
        return "emergency condition"
    if expected_state == "SAFE_STOP":
        return "safe stop condition"
    return ""


def _row(
    step: int,
    *,
    expected_state: str,
    expected_fault: str,
    expected_actuator_mode: str | None = None,
    speed_value: float | None = 100.0,
    distance_value: float | None = 45.0,
    lane_value: float | None = 0.0,
    driver_command: str = "NONE",
    transition_lookback_ticks: int = 0,
    transition_window_ticks: int = 4,
    note: str | None = None,
) -> ScenarioRow:
    return ScenarioRow(
        step=step,
        speed_value=speed_value,
        distance_value=distance_value,
        lane_value=lane_value,
        driver_command=driver_command,
        expected_state=expected_state,
        expected_fault=expected_fault,
        expected_actuator_mode=(
            expected_actuator_mode or _default_actuator_mode(expected_state)
        ),
        transition_lookback_ticks=transition_lookback_ticks,
        transition_window_ticks=transition_window_ticks,
        note=(note if note is not None else _default_note(expected_state, expected_fault)),
    )


def _extend_segment(rows: list[ScenarioRow], count: int, **kwargs: object) -> None:
    for offset in range(count):
        row_kwargs = dict(kwargs)
        row_kwargs["step"] = len(rows) + 1
        if offset > 0 and "driver_command" in row_kwargs:
            row_kwargs["driver_command"] = "NONE"
        rows.append(_row(**row_kwargs))


def _nominal_engage_cruise() -> list[ScenarioRow]:
    rows: list[ScenarioRow] = []
    _extend_segment(rows, 2, expected_state="STANDBY", expected_fault="NONE")
    _extend_segment(
        rows,
        1,
        expected_state="ENGAGING",
        expected_fault="NONE",
        driver_command="ENGAGE",
        note="driver requests autopilot engage",
    )
    _extend_segment(
        rows,
        1,
        expected_state="ACTIVE",
        expected_fault="NONE",
        note="healthy sensors activate autopilot",
    )
    _extend_segment(rows, 10, expected_state="ACTIVE", expected_fault="NONE")
    return rows


def _overspeed_minor_fault() -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 4, expected_state="ACTIVE", expected_fault="NONE")
    _extend_segment(
        rows,
        4,
        expected_state="WARNING_ACTIVE",
        expected_fault="NONE",
        speed_value=138.0,
        distance_value=45.0,
        lane_value=0.0,
        note="plausible overspeed 138 km/h triggers warning",
    )
    _extend_segment(
        rows,
        4,
        expected_state="ACTIVE",
        expected_fault="NONE",
        note="speed returns to nominal range",
    )
    return rows


def _lane_deviation_minor_fault() -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 4, expected_state="ACTIVE", expected_fault="NONE")
    _extend_segment(
        rows,
        4,
        expected_state="WARNING_ACTIVE",
        expected_fault="NONE",
        speed_value=95.0,
        distance_value=42.0,
        lane_value=0.85,
        note="lane offset 0.85 m triggers warning",
    )
    _extend_segment(
        rows,
        4,
        expected_state="ACTIVE",
        expected_fault="NONE",
        note="lane offset returns to nominal range",
    )
    return rows


def _distance_emergency_stop() -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 2, expected_state="ACTIVE", expected_fault="NONE")
    _extend_segment(
        rows,
        2,
        expected_state="EMERGENCY",
        expected_fault="CRITICAL",
        speed_value=45.0,
        distance_value=6.0,
        lane_value=0.0,
        transition_window_ticks=0,
        note=_immediate_note("front distance 6 m triggers emergency braking"),
    )
    _extend_segment(
        rows,
        4,
        expected_state="SAFE_STOP",
        expected_fault="CRITICAL",
        speed_value=0.0,
        distance_value=3.0,
        lane_value=0.0,
        transition_window_ticks=0,
        note=_immediate_note("vehicle stops and holds safe stop"),
    )
    return rows


def _engage_blocked_invalid_sensor() -> list[ScenarioRow]:
    rows: list[ScenarioRow] = []
    _extend_segment(rows, 2, expected_state="STANDBY", expected_fault="NONE")
    _extend_segment(
        rows,
        1,
        expected_state="ENGAGING",
        expected_fault="NONE",
        driver_command="ENGAGE",
        note="driver requests autopilot engage",
    )
    _extend_segment(
        rows,
        4,
        expected_state="SENSOR_FAULT",
        expected_fault="CRITICAL",
        lane_value=IMPLAUSIBLE_LANE_HIGH,
        note="implausible lane sample 6.0 m blocks engagement",
    )
    _extend_segment(
        rows,
        1,
        expected_state="STANDBY",
        expected_fault="CRITICAL",
        driver_command="OVERRIDE",
        note="driver override returns to standby",
    )
    _extend_segment(rows, 2, expected_state="STANDBY", expected_fault="CRITICAL")
    return rows


def _single_sensor_invalid(sensor_name: str, direction: str) -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 2, expected_state="ACTIVE", expected_fault="NONE")

    invalid_speed = 100.0
    invalid_distance = 40.0
    invalid_lane = 0.0

    if sensor_name == "speed" and direction == "high":
        invalid_speed = IMPLAUSIBLE_SPEED_HIGH
        note = "implausible high speed sample 160 km/h invalidates speed sensor"
    elif sensor_name == "speed" and direction == "low":
        invalid_speed = IMPLAUSIBLE_SPEED_LOW
        note = "implausible low speed sample -5 km/h invalidates speed sensor"
    elif sensor_name == "distance" and direction == "high":
        invalid_distance = IMPLAUSIBLE_DISTANCE_HIGH
        note = "implausible high distance sample 300 m invalidates distance sensor"
    elif sensor_name == "distance" and direction == "low":
        invalid_distance = IMPLAUSIBLE_DISTANCE_LOW
        note = "implausible low distance sample -5 m invalidates distance sensor"
    elif sensor_name == "lane" and direction == "high":
        invalid_lane = IMPLAUSIBLE_LANE_HIGH
        note = "implausible high lane sample 6.0 m invalidates lane sensor"
    elif sensor_name == "lane" and direction == "low":
        invalid_lane = IMPLAUSIBLE_LANE_LOW
        note = "implausible low lane sample -6.0 m invalidates lane sensor"
    else:
        raise ValueError(
            f"unsupported sensor invalid scenario: {sensor_name}/{direction}"
        )

    _extend_segment(
        rows,
        4,
        expected_state="SENSOR_FAULT",
        expected_fault="CRITICAL",
        speed_value=invalid_speed,
        distance_value=invalid_distance,
        lane_value=invalid_lane,
        note=note,
    )
    _extend_segment(
        rows,
        1,
        expected_state="STANDBY",
        expected_fault="CRITICAL",
        driver_command="OVERRIDE",
        note="driver override returns to standby",
    )
    _extend_segment(rows, 3, expected_state="STANDBY", expected_fault="CRITICAL")
    return rows


def _single_sensor_timeout(sensor_name: str) -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 2, expected_state="ACTIVE", expected_fault="NONE")

    missing_kwargs: dict[str, float | None] = {}
    if sensor_name == "speed":
        missing_kwargs["speed_value"] = None
    elif sensor_name == "distance":
        missing_kwargs["distance_value"] = None
    elif sensor_name == "lane":
        missing_kwargs["lane_value"] = None
    else:
        raise ValueError(f"unsupported sensor timeout scenario: {sensor_name}")

    _extend_segment(
        rows,
        8,
        expected_state="ACTIVE",
        expected_fault="NONE",
        note=f"{sensor_name} samples missing while timeout accumulates",
        **missing_kwargs,
    )
    _extend_segment(
        rows,
        1,
        expected_state="ACTIVE",
        expected_fault="NONE",
        transition_lookback_ticks=1,
        note=(
            f"{sensor_name} timeout boundary; one tick early transition acceptable"
        ),
        **missing_kwargs,
    )
    _extend_segment(
        rows,
        7,
        expected_state="SENSOR_FAULT",
        expected_fault="CRITICAL",
        note=f"{sensor_name} timeout drives SENSOR_FAULT",
        **missing_kwargs,
    )
    _extend_segment(
        rows,
        1,
        expected_state="STANDBY",
        expected_fault="CRITICAL",
        driver_command="OVERRIDE",
        note="driver override returns to standby",
    )
    _extend_segment(rows, 3, expected_state="STANDBY", expected_fault="CRITICAL")
    return rows


def _multiple_sensor_failure_safe_stop() -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 2, expected_state="ACTIVE", expected_fault="NONE")
    _extend_segment(
        rows,
        6,
        expected_state="SAFE_STOP",
        expected_fault="FATAL",
        speed_value=IMPLAUSIBLE_SPEED_HIGH,
        distance_value=IMPLAUSIBLE_DISTANCE_LOW,
        lane_value=0.0,
        transition_window_ticks=0,
        note=_immediate_note(
            "implausible speed and distance samples trigger fatal safe stop"
        ),
    )
    return rows


def _minor_fault_recovery() -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 2, expected_state="ACTIVE", expected_fault="NONE")
    _extend_segment(
        rows,
        2,
        expected_state="WARNING_ACTIVE",
        expected_fault="NONE",
        speed_value=136.0,
        distance_value=42.0,
        lane_value=0.0,
        note="plausible overspeed 136 km/h triggers warning",
    )
    _extend_segment(
        rows,
        4,
        expected_state="ACTIVE",
        expected_fault="NONE",
        note="speed returns to nominal range",
    )
    _extend_segment(
        rows,
        2,
        expected_state="WARNING_ACTIVE",
        expected_fault="NONE",
        speed_value=98.0,
        distance_value=40.0,
        lane_value=0.72,
        note="lane offset 0.72 m triggers warning",
    )
    _extend_segment(
        rows,
        4,
        expected_state="ACTIVE",
        expected_fault="NONE",
        note="lane offset returns to nominal range",
    )
    return rows


def _driver_override() -> list[ScenarioRow]:
    rows = _nominal_engage_cruise()
    _extend_segment(rows, 4, expected_state="ACTIVE", expected_fault="NONE")
    _extend_segment(
        rows,
        1,
        expected_state="STANDBY",
        expected_fault="NONE",
        driver_command="OVERRIDE",
        transition_window_ticks=0,
        note=_immediate_note("driver override returns to standby"),
    )
    _extend_segment(
        rows,
        1,
        expected_state="STANDBY",
        expected_fault="NONE",
        transition_window_ticks=0,
        note=_immediate_note("standby immediately after driver override"),
    )
    _extend_segment(rows, 2, expected_state="STANDBY", expected_fault="NONE")
    return rows
