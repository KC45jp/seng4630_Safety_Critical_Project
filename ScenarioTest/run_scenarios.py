from __future__ import annotations

import argparse
import csv
import math
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if __package__ in {None, ""}:
    sys.path.insert(0, str(REPO_ROOT))

from ScenarioSupport.scenario_schema import (
    ScenarioFormatError,
    TraceRow,
    read_scenario_csv,
    read_trace_csv,
)

DEFAULT_SCENARIO_DIR = REPO_ROOT / "SensorData" / "scenarios"
DEFAULT_SCENARIO_MANIFEST = DEFAULT_SCENARIO_DIR / "scenario_manifest.csv"
DEFAULT_PROJECT_DIR = REPO_ROOT / "autopilot_system"
DEFAULT_TRACE_DIR = REPO_ROOT / "ScenarioTest" / "traces"
DEFAULT_COMMAND = "./bin/main --scenario {scenario} --trace-out {trace}"
TARGET_SPEED = 100.0
MAX_SPEED = 130.0
SAFE_FOLLOW_DIST = 30.0
ACTUATOR_TOLERANCE = 1.0e-4
RUNNER_PREFIX = "[PYRUN]"
RUNNER_COLOR_MODE = os.environ.get("PYRUN_COLOR", "auto").strip().lower()
ANSI_RESET = "\033[0m"
RUNNER_PREFIX_COLOR = "\033[1;34m"
RUNNER_SEPARATOR_COLOR = "\033[2;36m"
RUNNER_LABEL_COLORS = {
    "START": "\033[1;36m",
    "TRACE": "\033[0;36m",
    "CMD": "\033[2;37m",
    "PASS": "\033[1;32m",
    "FAIL": "\033[1;31m",
    "SUMMARY": "\033[1;35m",
    "SCHEMA": "\033[1;34m",
    "DRYRUN": "\033[1;33m",
}


def _runner_use_color(stream: object) -> bool:
    if RUNNER_COLOR_MODE == "always":
        return True
    if RUNNER_COLOR_MODE == "never":
        return False
    if os.environ.get("NO_COLOR") is not None:
        return False

    is_tty = getattr(stream, "isatty", lambda: False)()
    if not is_tty:
        return False

    term = os.environ.get("TERM", "")
    return term.lower() != "dumb"


def _runner_style(text: str, color: str, stream: object) -> str:
    if not color or not _runner_use_color(stream):
        return text
    return f"{color}{text}{ANSI_RESET}"


def _runner_line(label: str, message: str = "", stream: object = None) -> None:
    target = sys.stdout if stream is None else stream
    prefix = _runner_style(RUNNER_PREFIX, RUNNER_PREFIX_COLOR, target)
    padded_label = f"{label:<7}"
    styled_label = _runner_style(
        padded_label,
        RUNNER_LABEL_COLORS.get(label, ""),
        target,
    )
    if message:
        print(f"{prefix} {styled_label} {message}", file=target)
    else:
        print(f"{prefix} {styled_label}", file=target)


def _runner_separator(stream: object = None) -> None:
    target = sys.stdout if stream is None else stream
    prefix = _runner_style(RUNNER_PREFIX, RUNNER_PREFIX_COLOR, target)
    bar = _runner_style('-' * 72, RUNNER_SEPARATOR_COLOR, target)
    print(f"{prefix} {bar}", file=target)


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command_name == "list":
            return _list_scenarios(args)
        if args.command_name == "validate-scenarios":
            return _validate_scenarios(args)
        if args.command_name == "validate-trace":
            return _validate_trace(args)
        if args.command_name == "run":
            return _run_scenarios(args)
    except ScenarioFormatError as exc:
        _runner_line("FAIL", f"scenario format error: {exc}", stream=sys.stderr)
        return 2
    except RuntimeError as exc:
        _runner_line("FAIL", str(exc), stream=sys.stderr)
        return 3

    parser.error(f"unsupported command: {args.command_name}")
    return 2


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="List, validate, and run integrated ADAS scenario CSV files."
    )
    subparsers = parser.add_subparsers(dest="command_name", required=True)

    list_parser = subparsers.add_parser("list", help="List known scenarios.")
    list_parser.add_argument(
        "--scenario-dir",
        type=Path,
        default=DEFAULT_SCENARIO_DIR,
        help="Directory containing generated scenario CSV files.",
    )
    list_parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_SCENARIO_MANIFEST,
        help="CSV manifest containing scenario names and descriptions.",
    )

    validate_parser = subparsers.add_parser(
        "validate-scenarios",
        help="Validate the scenario CSV schema for one or all scenarios.",
    )
    validate_parser.add_argument(
        "--scenario-dir",
        type=Path,
        default=DEFAULT_SCENARIO_DIR,
        help="Directory containing generated scenario CSV files.",
    )
    validate_parser.add_argument(
        "--scenario",
        help="Scenario name or CSV path. If omitted, validate every scenario in the directory.",
    )

    trace_parser = subparsers.add_parser(
        "validate-trace",
        help="Validate a trace CSV against the expected state/fault columns.",
    )
    trace_parser.add_argument("--scenario", required=True, help="Scenario name or CSV path.")
    trace_parser.add_argument("--trace", required=True, type=Path, help="Trace CSV path.")
    trace_parser.add_argument(
        "--scenario-dir",
        type=Path,
        default=DEFAULT_SCENARIO_DIR,
        help="Directory containing generated scenario CSV files.",
    )
    trace_parser.add_argument(
        "--window",
        type=int,
        default=4,
        help="Default sensor-tick window used when a scenario row does not override transition_window_ticks.",
    )

    run_parser = subparsers.add_parser(
        "run",
        help="Run one or all scenarios and validate the resulting trace CSV.",
    )
    run_parser.add_argument(
        "--scenario-dir",
        type=Path,
        default=DEFAULT_SCENARIO_DIR,
        help="Directory containing generated scenario CSV files.",
    )
    run_parser.add_argument(
        "--scenario",
        help="Scenario name or CSV path. If omitted, every generated scenario is run.",
    )
    run_parser.add_argument(
        "--command",
        default=DEFAULT_COMMAND,
        help=(
            "Shell command template used to run Ada. "
            "Use {scenario} and {trace} placeholders."
        ),
    )
    run_parser.add_argument(
        "--project-dir",
        type=Path,
        default=DEFAULT_PROJECT_DIR,
        help="Directory where the Ada project should be run.",
    )
    run_parser.add_argument(
        "--trace-dir",
        type=Path,
        default=DEFAULT_TRACE_DIR,
        help="Directory where trace CSV files should be written.",
    )
    run_parser.add_argument(
        "--window",
        type=int,
        default=4,
        help="Default sensor-tick window used when a scenario row does not override transition_window_ticks.",
    )
    run_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing them.",
    )

    return parser


def _list_scenarios(args: argparse.Namespace) -> int:
    available_files = _discover_scenario_files(args.scenario_dir)
    manifest_rows = _read_manifest(args.manifest)
    listed: set[str] = set()

    for name, description in manifest_rows:
        status = "ready" if name in available_files else "missing"
        print(f"{name:32} {status:7} {description}")
        listed.add(name)

    for name in sorted(available_files):
        if name in listed:
            continue
        print(f"{name:32} {'ready':7} (no manifest description)")

    return 0


def _validate_scenarios(args: argparse.Namespace) -> int:
    scenario_paths = _resolve_scenarios(args.scenario_dir, args.scenario)
    total_rows = 0
    for scenario_path in scenario_paths:
        rows = read_scenario_csv(scenario_path)
        total_rows += len(rows)
        _runner_line("SCHEMA", f"PASS {scenario_path.name} ({len(rows)} rows)")
    _runner_line("SUMMARY", f"validated {len(scenario_paths)} scenario files ({total_rows} rows total)")
    return 0


def _validate_trace(args: argparse.Namespace) -> int:
    scenario_path = _resolve_scenario_path(args.scenario_dir, args.scenario)
    scenario_rows = read_scenario_csv(scenario_path)
    trace_rows = read_trace_csv(args.trace)
    _assert_expected_window(scenario_path, scenario_rows, trace_rows, args.window)
    _runner_line("TRACE", f"PASS {args.trace} against {scenario_path.name}")
    return 0


def _run_scenarios(args: argparse.Namespace) -> int:
    scenario_paths = _resolve_scenarios(args.scenario_dir, args.scenario)
    args.trace_dir.mkdir(parents=True, exist_ok=True)

    total = len(scenario_paths)

    for index, scenario_path in enumerate(scenario_paths, start=1):
        trace_path = args.trace_dir / f"{scenario_path.stem}.trace.csv"
        command = args.command.format(
            scenario=str(scenario_path.resolve()),
            trace=str(trace_path.resolve()),
        )

        _runner_separator()
        _runner_line("START", f"[{index}/{total}] {scenario_path.stem}")
        _runner_line("TRACE", str(trace_path))
        _runner_line("CMD", command)

        if args.dry_run:
            _runner_line("DRYRUN", f"prepared {scenario_path.stem}")
            continue

        result = subprocess.run(
            command,
            cwd=args.project_dir,
            shell=True,
            text=True,
            capture_output=True,
        )
        if result.stdout:
            print(result.stdout, end="")
        if result.returncode != 0:
            if result.stderr:
                print(result.stderr, file=sys.stderr, end="")
            _runner_line("FAIL", f"{scenario_path.stem} exited with code {result.returncode}", stream=sys.stderr)
            raise RuntimeError(
                f"scenario {scenario_path.stem} failed to run with exit code {result.returncode}"
            )

        scenario_rows = read_scenario_csv(scenario_path)
        trace_rows = read_trace_csv(trace_path)
        _assert_expected_window(scenario_path, scenario_rows, trace_rows, args.window)
        _runner_line("PASS", f"{scenario_path.stem} validated")

    _runner_separator()
    if args.dry_run:
        _runner_line("SUMMARY", f"prepared {total} scenario commands")
    else:
        _runner_line("SUMMARY", f"ran and validated {total} scenario files")
    return 0


def _discover_scenario_files(scenario_dir: Path) -> dict[str, Path]:
    return {
        path.stem: path
        for path in sorted(scenario_dir.glob("*.csv"))
        if path.name != DEFAULT_SCENARIO_MANIFEST.name
    }


def _resolve_scenarios(scenario_dir: Path, scenario: str | None) -> list[Path]:
    if scenario is None:
        paths = list(_discover_scenario_files(scenario_dir).values())
        if not paths:
            raise RuntimeError(f"no scenario CSV files found in {scenario_dir}")
        return paths
    return [_resolve_scenario_path(scenario_dir, scenario)]


def _resolve_scenario_path(scenario_dir: Path, scenario: str) -> Path:
    raw_path = Path(scenario)
    if raw_path.exists():
        return raw_path

    candidate = scenario_dir / scenario
    if candidate.suffix != ".csv":
        candidate = candidate.with_suffix(".csv")
    if candidate.exists() and candidate.name != DEFAULT_SCENARIO_MANIFEST.name:
        return candidate

    raise RuntimeError(f"unable to find scenario CSV for {scenario!r}")


def _read_manifest(manifest_path: Path) -> list[tuple[str, str]]:
    if not manifest_path.exists():
        return []

    with manifest_path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != ["name", "description"]:
            raise RuntimeError(
                f"manifest {manifest_path} has invalid headers: {reader.fieldnames!r}"
            )
        return [
            (row["name"].strip(), row["description"].strip())
            for row in reader
            if row["name"].strip()
        ]


def _assert_expected_window(
    scenario_path: Path,
    scenario_rows: list,
    trace_rows: list[TraceRow],
    window: int,
) -> None:
    if window < 0:
        raise RuntimeError("window must be zero or positive")

    trace_by_step = {row.step: row for row in trace_rows}
    failures: list[str] = []

    for scenario_row in scenario_rows:
        state_fault_matched = False
        actuator_matched = False
        effective_window = getattr(scenario_row, "transition_window_ticks", window)
        if effective_window < 0:
            raise RuntimeError("transition_window_ticks must be zero or positive")
        start_step = max(1, scenario_row.step - scenario_row.transition_lookback_ticks)

        for step in range(start_step, scenario_row.step + effective_window + 1):
            trace_row = trace_by_step.get(step)
            if trace_row is None:
                continue
            if (
                trace_row.observed_state == scenario_row.expected_state
                and trace_row.observed_fault == scenario_row.expected_fault
            ):
                state_fault_matched = True
            if _actuator_mode_matches(scenario_row.expected_actuator_mode, trace_row):
                actuator_matched = True

        if not (state_fault_matched and actuator_matched):
            missing_parts: list[str] = []
            if not state_fault_matched:
                missing_parts.append(
                    f"state/fault={scenario_row.expected_state}/{scenario_row.expected_fault}"
                )
            if not actuator_matched:
                missing_parts.append(
                    f"actuator={scenario_row.expected_actuator_mode}"
                )
            note_suffix = "" if not scenario_row.note else f" [{scenario_row.note}]"
            failures.append(
                f"{scenario_path.name} step {scenario_row.step}{note_suffix}: expected "
                f"{', '.join(missing_parts)} within -{scenario_row.transition_lookback_ticks}/+{effective_window} ticks"
            )

    if failures:
        sample = "\n".join(failures[:10])
        extra = "" if len(failures) <= 10 else f"\n... and {len(failures) - 10} more"
        raise RuntimeError(f"trace validation failed:\n{sample}{extra}")


def _actuator_mode_matches(expected_mode: str, trace_row: TraceRow) -> bool:
    expected_output = _expected_actuator_output(expected_mode, trace_row)
    observed_output = (
        trace_row.observed_throttle,
        trace_row.observed_brake,
        trace_row.observed_steering,
    )
    return all(
        observed is not None and math.isclose(observed, expected, abs_tol=ACTUATOR_TOLERANCE)
        for observed, expected in zip(observed_output, expected_output)
    )


def _expected_actuator_output(expected_mode: str, trace_row: TraceRow) -> tuple[float, float, float]:
    if expected_mode == "IDLE_OUTPUT":
        return (0.0, 0.0, 0.0)
    if expected_mode == "DEGRADED_OUTPUT":
        return (0.0, 0.3, 0.0)
    if expected_mode == "EMERGENCY_OUTPUT":
        return (0.0, 1.0, 0.0)
    if expected_mode == "NOMINAL_OUTPUT":
        return _nominal_output(trace_row)
    raise RuntimeError(f"unsupported actuator mode: {expected_mode}")


def _nominal_output(trace_row: TraceRow) -> tuple[float, float, float]:
    speed = trace_row.observed_speed or 0.0
    distance = trace_row.observed_distance or 0.0
    lane = trace_row.observed_lane or 0.0

    throttle = _clamp((TARGET_SPEED - speed) / 50.0, 0.0, 1.0)
    brake = 0.0
    steering = _clamp(-lane * 2.0, -1.0, 1.0)

    if trace_row.observed_speed_valid and speed > MAX_SPEED:
        throttle = 0.0

    if trace_row.observed_distance_valid and distance < SAFE_FOLLOW_DIST:
        brake = _clamp((SAFE_FOLLOW_DIST - distance) / 20.0, 0.0, 1.0)
        throttle = 0.0

    return (throttle, brake, steering)


def _clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


if __name__ == "__main__":
    raise SystemExit(main())
