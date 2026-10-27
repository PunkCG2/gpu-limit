# GPU Limit

[Leer en español](README.es.md)

PowerShell scripts for Windows that cap an NVIDIA GPU's power limit and maximum clocks (core and memory) to a percentage of its factory values, using `nvidia-smi`. Useful to reduce heat, noise and power draw at a small performance cost.

## Requirements

- Windows with PowerShell 5.1 or later.
- An NVIDIA driver that provides `nvidia-smi`.
- Administrator rights. The scripts ask for elevation on their own.

## Quick start

Presets apply the limit **and** install a scheduled task, so the limit survives reboots:

```powershell
.\gpu_limite_85.ps1    # GPU 85 %, Memory 50 %
.\gpu_limite_90.ps1    # GPU 90 %, Memory 85 %
.\gpu_limite_95.ps1    # GPU 95 %, Memory 90 %
.\gpu_restaurar.ps1    # back to factory values
```

The preset memory values were chosen for an RTX 5070 Ti, which only supports memory clocks of 405, 810, 7001, 13801 and 14001 MHz. There 50 % becomes 7001 MHz, and 85 % and 90 % both become 13801 MHz (about 98 %). Override them with `-Memoria` if your GPU differs.

## Custom limits

```powershell
.\gpu_limite.ps1 -Gpu 90 -Memoria 95             # apply now, until reboot
.\gpu_limite.ps1 -Gpu 90 -Instalar               # apply and persist across reboots
.\gpu_limite.ps1 -Aplicar                        # re-apply the saved configuration
.\gpu_limite.ps1 -Quitar                         # restore factory values and remove from the configuration
.\gpu_limite.ps1 -Restaurar                      # restore factory values, keep the configuration
.\gpu_limite.ps1 --help                          # full reference
```

## Parameters (`gpu_limite.ps1`)

| Parameter | Description |
|---|---|
| `-Gpu <1-100>` | % of default power limit and of max core clock. Default 100. Power never goes below the GPU's minimum. |
| `-Memoria <1-100>` | % of max memory clock. Default 100 (no cap; clears any previous one). Warns if the driver rejects it. |
| `-Indice <list>` | GPUs to act on: `"0"`, `"0,1"` or `"todas"`. Without it, a menu is shown when there are several GPUs and the session is interactive; otherwise all GPUs are used. |
| `-Instalar` | Apply, save to `gpu_limite.json` and create/update the scheduled task. |
| `-Aplicar` | Apply what `gpu_limite.json` holds. This is what the task runs. |
| `-Quitar` | Restore the selected GPUs and drop them from the configuration; the task is deleted when no GPU is left. |
| `-Restaurar` | Restore the selected GPUs without touching configuration or task. |
| `-Ayuda`, `-h`, `-help`, `--help` | Show the help. |

`-Instalar`, `-Quitar`, `-Restaurar` and `-Aplicar` are mutually exclusive. The preset scripts accept `-Indice`, `-Memoria`, `-SinTarea` (apply once, no task), `-Quitar`, `-Restaurar` and `--help`.

## How it works

- Factory values are read from the driver (`power.default_limit`, `power.min_limit`, `clocks.max.graphics`, `clocks.max.memory`), so nothing is hardcoded to a specific GPU. Limits are always computed from factory values, never from the current ones.
- Targets are snapped to the nearest clock the GPU supports (`nvidia-smi -q -d SUPPORTED_CLOCKS`), then applied with `-pl`, `-lgc` and `-lmc`.
- NVIDIA resets these settings on reboot. `-Instalar` stores one entry per GPU (keyed by UUID) in `gpu_limite.json` and registers a **single** scheduled task, `GPU limite`, that runs `gpu_limite.ps1 -Aplicar` at logon under the SYSTEM account with no window. Installing for another GPU adds an entry instead of replacing the previous one.
- If you move the scripts, run `-Instalar` again so the task points to the new location.

## Files

| File | Purpose |
|---|---|
| `gpu_limite.ps1` | All the logic. |
| `gpu_limite_85.ps1`, `_90`, `_95` | Presets: call the base script and install the task. |
| `gpu_restaurar.ps1` | Shortcut for `gpu_limite.ps1 -Restaurar`. |
| `gpu_limite.json` | Saved configuration, created by `-Instalar` and ignored by git. |

## Warning

Changing power and clock limits affects your hardware. Use these scripts at your own risk.
