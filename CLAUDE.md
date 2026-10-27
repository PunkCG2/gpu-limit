# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Standalone PowerShell scripts (Windows, Spanish-language UI/comments) that cap an NVIDIA GPU's power limit and max clocks to a percentage of factory values via `nvidia-smi`. No build, lint, or test tooling; not a git repo.

## Running

```powershell
.\gpu_limite.ps1 -Gpu 90 -Memoria 95            # apply now (self-elevates via RunAs if not admin)
.\gpu_limite.ps1 -Gpu 90 -Instalar              # apply + save to gpu_limite.json + register/update the single logon task
.\gpu_limite.ps1 -Aplicar                       # apply what gpu_limite.json holds (what the task runs)
.\gpu_limite.ps1 -Quitar                        # reset selected GPUs, drop them from the json; task removed when none left
.\gpu_limite.ps1 -Restaurar                     # reset to factory only, json and task untouched
.\gpu_limite_95.ps1 [-SinTarea|-Quitar|-Restaurar]   # preset wrapper: installs the task by default; -SinTarea = apply once only
```

`-Ayuda` / `-h` / `-help` / `--help` prints the full parameter reference (`Mostrar-Ayuda` in `gpu_limite.ps1`; wrappers forward it). Update that text whenever a parameter or preset changes. `-Instalar`, `-Quitar`, `-Restaurar`, `-Aplicar` are mutually exclusive; unknown arguments print the help and exit 1.

## Architecture

- `gpu_limite.ps1` is the only script with logic. `-Gpu` (1-100) scales power limit and max graphics clock; `-Memoria` (1-100, default 100 = no cap) scales max memory clock via `nvidia-smi -lmc` (warns if the driver/GPU rejects it). Targets are snapped to the nearest step in `nvidia-smi -q -d SUPPORTED_CLOCKS` (`Soportadas`/`Ajustar`). `-Indice` (`"0"`, `"0,1"`, `"todas"`) picks GPUs; without it and with >1 GPU in an interactive session a menu asks. Single GPU or non-interactive = all GPUs.
- `gpu_limite_85/90/95.ps1` and `gpu_restaurar.ps1` are thin wrappers that call the base with fixed values (85 → GPU 85/Mem 50, 90 → GPU 90/Mem 85, 95 → GPU 95/Mem 90; tuned for a specific Gigabyte GPU, `-Memoria` can override; this GPU only supports memory clocks 405/810/7001/13801/14001 MHz, so 50 % → 7001 MHz and 85/90 % both snap to 13801 MHz) and always pass `-Instalar` unless `-SinTarea/-Quitar/-Restaurar/-Ayuda` is given. Add a new preset by copying a wrapper; never duplicate logic.
- Power = `power.default_limit * pct` clamped to at least `power.min_limit`; clock caps = `clocks.max.{graphics,memory} * pct` via `-lgc "0,<clk>"` / `-lmc "0,<clk>"`. Settings are lost on reboot, hence the scheduled task.
- Persistence: `-Instalar` upserts one entry per GPU (key = UUID, so index changes don't matter) in `gpu_limite.json` next to the script, then registers the single task `"GPU limite"` (SYSTEM, ServiceAccount, no window, `-Force` replaces it) whose action is just `gpu_limite.ps1 -Aplicar`. Installing for another GPU adds an entry instead of overwriting; the task never carries per-GPU args. `-Instalar` also deletes the legacy per-percent tasks (`GPU limite 85/90/95`). Moving the scripts breaks the task; re-run `-Instalar` after moving.
- Scripts are UTF-8 with BOM and contain accented Spanish text; preserve the BOM and language when editing.
