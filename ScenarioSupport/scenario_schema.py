from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

SCENARIO_HEADERS = [
    "step",
    "speed_value",
    "distance_value",
    "lane_value",
    "driver_command",
    "expected_state",
    "expected_fault",
    "expected_actuator_mode",
    "transition_lookback_ticks",
    "transition_window_ticks",
    "note",
]

TRACE_HEADERS = [
    "step",
    "observed_state",
    "observed_fault",
    "observed_speed",
    "observed_distance",
    "observed_lane",
    "observed_speed_valid",
    "observed_distance_valid",
    "observed_lane_valid",
    "observed_throttle",
    "observed_brake",
    "observed_steering",
]

DRIVER_COMMANDS = ("NONE", "ENGAGE", "DISENGAGE", "OVERRIDE")
SYSTEM_STATES = (
    "STANDBY",
    "ENGAGING",
    "ACTIVE",
    "WARNING_ACTIVE",
    "SENSOR_FAULT",
    "EMERGENCY",
    "SAFE_STOP",
)
FAULT_LEVELS = ("NONE", "CRITICAL", "FATAL")
ACTUATOR_MODES = (
    "IDLE_OUTPUT",
    "NOMINAL_OUTPUT",
    "DEGRADED_OUTPUT",
    "EMERGENCY_OUTPUT",
)


class ScenarioFormatError(ValueError):
    """Raised when a scenario or trace CSV does not match the formal schema."""


@dataclass(frozen=True)
class ScenarioRow:
    step: int
    speed_value: float | None
    distance_value: float | None
    lane_value: float | None
    driver_command: str
    expected_state: str
    expected_fault: str
    expected_actuator_mode: str
    transition_lookback_ticks: int = 0
    transition_window_ticks: int = 4
    note: str = ""

    def to_csv_row(self) -> list[str]:
        return [
            str(self.step),
            _format_optional_float(self.speed_value),
            _format_optional_float(self.distance_value),
            _format_optional_float(self.lane_value),
            self.driver_command,
            self.expected_state,
            self.expected_fault,
            self.expected_actuator_mode,
            str(self.transition_lookback_ticks),
            str(self.transition_window_ticks),
            self.note,
        ]


@dataclass(frozen=True)
class TraceRow:
    step: int
    observed_state: str
    observed_fault: str
    observed_speed: float | None
    observed_distance: float | None
    observed_lane: float | None
    observed_speed_valid: bool
    observed_distance_valid: bool
    observed_lane_valid: bool
    observed_throttle: float | None
    observed_brake: float | None
    observed_steering: float | None


def write_scenario_csv(path: Path, rows: Iterable[ScenarioRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(SCENARIO_HEADERS)
        for row in rows:
            writer.writerow(row.to_csv_row())


def read_scenario_csv(path: Path) -> list[ScenarioRow]:
    with path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != SCENARIO_HEADERS:
            raise ScenarioFormatError(
                f"{path} has invalid headers: {reader.fieldnames!r}"
            )

        rows: list[ScenarioRow] = []
        for index, raw_row in enumerate(reader, start=2):
            rows.append(_parse_scenario_row(path, index, raw_row))

    _validate_sequential_steps(path, rows)
    return rows


def read_trace_csv(path: Path) -> list[TraceRow]:
    with path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != TRACE_HEADERS:
            raise ScenarioFormatError(
                f"{path} has invalid trace headers: {reader.fieldnames!r}"
            )

        rows: list[TraceRow] = []
        for index, raw_row in enumerate(reader, start=2):
            rows.append(_parse_trace_row(path, index, raw_row))

    _validate_trace_steps(path, rows)
    return rows


def _parse_scenario_row(
    path: Path,
    line_number: int,
    raw_row: dict[str, str],
) -> ScenarioRow:
    step = _parse_positive_int(path, line_number, "step", raw_row["step"])
    driver_command = _parse_enum(
        path, line_number, "driver_command", raw_row["driver_command"], DRIVER_COMMANDS
    )
    expected_state = _parse_enum(
        path, line_number, "expected_state", raw_row["expected_state"], SYSTEM_STATES
    )
    expected_fault = _parse_enum(
        path, line_number, "expected_fault", raw_row["expected_fault"], FAULT_LEVELS
    )
    expected_actuator_mode = _parse_enum(
        path,
        line_number,
        "expected_actuator_mode",
        raw_row["expected_actuator_mode"],
        ACTUATOR_MODES,
    )

    return ScenarioRow(
        step=step,
        speed_value=_parse_optional_float(path, line_number, "speed_value", raw_row["speed_value"]),
        distance_value=_parse_optional_float(
            path, line_number, "distance_value", raw_row["distance_value"]
        ),
        lane_value=_parse_optional_float(path, line_number, "lane_value", raw_row["lane_value"]),
        driver_command=driver_command,
        expected_state=expected_state,
        expected_fault=expected_fault,
        expected_actuator_mode=expected_actuator_mode,
        transition_lookback_ticks=_parse_nonnegative_int(
            path,
            line_number,
            "transition_lookback_ticks",
            raw_row["transition_lookback_ticks"],
        ),
        transition_window_ticks=_parse_nonnegative_int(
            path,
            line_number,
            "transition_window_ticks",
            raw_row["transition_window_ticks"],
        ),
        note=_parse_note(path, line_number, raw_row["note"]),
    )


def _parse_trace_row(
    path: Path,
    line_number: int,
    raw_row: dict[str, str],
) -> TraceRow:
    return TraceRow(
        step=_parse_positive_int(path, line_number, "step", raw_row["step"]),
        observed_state=_parse_enum(
            path, line_number, "observed_state", raw_row["observed_state"], SYSTEM_STATES
        ),
        observed_fault=_parse_enum(
            path, line_number, "observed_fault", raw_row["observed_fault"], FAULT_LEVELS
        ),
        observed_speed=_parse_optional_float(path, line_number, "observed_speed", raw_row["observed_speed"]),
        observed_distance=_parse_optional_float(
            path, line_number, "observed_distance", raw_row["observed_distance"]
        ),
        observed_lane=_parse_optional_float(path, line_number, "observed_lane", raw_row["observed_lane"]),
        observed_speed_valid=_parse_bool(
            path, line_number, "observed_speed_valid", raw_row["observed_speed_valid"]
        ),
        observed_distance_valid=_parse_bool(
            path, line_number, "observed_distance_valid", raw_row["observed_distance_valid"]
        ),
        observed_lane_valid=_parse_bool(
            path, line_number, "observed_lane_valid", raw_row["observed_lane_valid"]
        ),
        observed_throttle=_parse_optional_float(
            path, line_number, "observed_throttle", raw_row["observed_throttle"]
        ),
        observed_brake=_parse_optional_float(
            path, line_number, "observed_brake", raw_row["observed_brake"]
        ),
        observed_steering=_parse_optional_float(
            path, line_number, "observed_steering", raw_row["observed_steering"]
        ),
    )


def _parse_positive_int(path: Path, line_number: int, field_name: str, raw_value: str) -> int:
    try:
        value = int(raw_value)
    except ValueError as exc:
        raise ScenarioFormatError(
            f"{path}:{line_number} invalid integer for {field_name}: {raw_value!r}"
        ) from exc

    if value <= 0:
        raise ScenarioFormatError(
            f"{path}:{line_number} {field_name} must be positive: {value}"
        )
    return value


def _parse_nonnegative_int(path: Path, line_number: int, field_name: str, raw_value: str) -> int:
    try:
        value = int(raw_value)
    except ValueError as exc:
        raise ScenarioFormatError(
            f"{path}:{line_number} invalid integer for {field_name}: {raw_value!r}"
        ) from exc

    if value < 0:
        raise ScenarioFormatError(
            f"{path}:{line_number} {field_name} must be zero or positive: {value}"
        )
    return value


def _parse_enum(
    path: Path,
    line_number: int,
    field_name: str,
    raw_value: str,
    allowed_values: tuple[str, ...],
) -> str:
    value = raw_value.strip().upper()
    if value not in allowed_values:
        raise ScenarioFormatError(
            f"{path}:{line_number} invalid {field_name}: {raw_value!r}; "
            f"expected one of {allowed_values}"
        )
    return value


def _parse_optional_float(path: Path, line_number: int, field_name: str, raw_value: str) -> float | None:
    if raw_value == "":
        return None
    try:
        return float(raw_value)
    except ValueError as exc:
        raise ScenarioFormatError(
            f"{path}:{line_number} invalid float for {field_name}: {raw_value!r}"
        ) from exc


def _parse_note(path: Path, line_number: int, raw_value: str) -> str:
    note = raw_value.strip()
    if "," in note:
        raise ScenarioFormatError(
            f"{path}:{line_number} note must not contain commas because the Ada parser "
            "does not support quoted CSV fields"
        )
    return note


def _parse_bool(path: Path, line_number: int, field_name: str, raw_value: str) -> bool:
    value = raw_value.strip().upper()
    if value == "TRUE":
        return True
    if value == "FALSE":
        return False
    raise ScenarioFormatError(
        f"{path}:{line_number} invalid boolean for {field_name}: {raw_value!r}"
    )


def _validate_sequential_steps(path: Path, rows: list[ScenarioRow]) -> None:
    for index, row in enumerate(rows, start=1):
        if row.step != index:
            raise ScenarioFormatError(
                f"{path}:{index + 1} step sequence mismatch: expected {index}; got {row.step}"
            )


def _validate_trace_steps(path: Path, rows: list[TraceRow]) -> None:
    for index, row in enumerate(rows, start=1):
        if row.step != index:
            raise ScenarioFormatError(
                f"{path}:{index + 1} trace step sequence mismatch: expected {index}; got {row.step}"
            )


def _format_optional_float(value: float | None) -> str:
    if value is None:
        return ""
    return f"{value:.2f}"
