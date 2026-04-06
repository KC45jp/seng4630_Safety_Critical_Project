from __future__ import annotations

if __package__ in {None, ""}:
    from scenario_generator import generate_all_scenarios
else:
    from .scenario_generator import generate_all_scenarios


def main() -> None:
    generated_paths = generate_all_scenarios()
    for path in generated_paths:
        print(f"generated {path}")


if __name__ == "__main__":
    main()
