# PIX RPA Scheduler

A centralized scheduler for PIX robots. It selects the next eligible project by Quartz cron expression, priority, enable flag, and last-run time, then waits for the selected robot to finish.

## Requirements

- PIX Studio 3.0 or newer; the current project metadata targets PIX 3.2.
- The `pix-rpa-framework` repository.
- Dependencies restored from `src/nuget.config` and `src/packages.config`.

## Quick start

1. Clone the repository.
2. Open `src/rpa_scheduler.pixproj` in PIX Studio and restore packages.
3. In the `main.pix` Variables panel, replace `PIX_RPA_FRAMEWORK_ROOT` with a valid C# string expression containing the framework repository path.
4. Replace `PIX_RPA_SCHEDULER_ROOT` with a valid C# string expression containing this repository root.
5. Copy `data/configs/schedule.example.json` to `data/configs/schedule.json`.
6. Replace example paths and cron expressions, then explicitly enable only the required robots.

Every entry in the committed example is disabled, so copying it unchanged cannot launch another robot. The runtime `schedule.json` is intentionally ignored because it contains machine-specific paths and mutable `last_run` values.

The two `PIX_RPA_*` values are deliberate compile-time placeholders, not operating-system environment variables. A fresh copy is intentionally non-compilable until both paths are configured for the target machine.

Detailed Russian-language documentation is available in [docs/readme.md](docs/readme.md).

## Author and license

Aidar Bikmukhametov — ARBikmuhametov@yandex.ru

Released under the [MIT License](LICENSE).
