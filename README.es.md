# Límite de GPU

[Read in English](README.md)

Scripts de PowerShell para Windows que limitan la potencia y las frecuencias máximas (núcleo y memoria) de una GPU NVIDIA a un porcentaje de sus valores de fábrica, usando `nvidia-smi`. Sirven para reducir calor, ruido y consumo a cambio de una pequeña pérdida de rendimiento.

## Requisitos

- Windows con PowerShell 5.1 o superior.
- Un driver de NVIDIA que incluya `nvidia-smi`.
- Permisos de administrador. Los scripts los piden solos.

## Inicio rápido

Los atajos aplican el límite **y** instalan una tarea programada, así que el límite sobrevive a los reinicios:

```powershell
.\gpu_limite_85.ps1    # GPU 85 %, Memoria 50 %
.\gpu_limite_90.ps1    # GPU 90 %, Memoria 85 %
.\gpu_limite_95.ps1    # GPU 95 %, Memoria 90 %
.\gpu_restaurar.ps1    # vuelve a los valores de fábrica
```

Los valores de memoria de los atajos se eligieron para una RTX 5070 Ti, que solo admite frecuencias de memoria de 405, 810, 7001, 13801 y 14001 MHz. En ella 50 % queda en 7001 MHz, y 85 % y 90 % quedan ambos en 13801 MHz (cerca del 98 %). Cámbialos con `-Memoria` si tu GPU es distinta.

## Límites personalizados

```powershell
.\gpu_limite.ps1 -Gpu 90 -Memoria 95             # aplica ahora, hasta el próximo reinicio
.\gpu_limite.ps1 -Gpu 90 -Instalar               # aplica y persiste tras reiniciar
.\gpu_limite.ps1 -Aplicar                        # reaplica la configuración guardada
.\gpu_limite.ps1 -Quitar                         # restaura fábrica y quita de la configuración
.\gpu_limite.ps1 -Restaurar                      # restaura fábrica y conserva la configuración
.\gpu_limite.ps1 --help                          # referencia completa
```

## Parámetros (`gpu_limite.ps1`)

| Parámetro | Descripción |
|---|---|
| `-Gpu <1-100>` | % de la potencia por defecto y de la frecuencia máxima del núcleo. Por defecto 100. La potencia nunca baja del mínimo de la GPU. |
| `-Memoria <1-100>` | % de la frecuencia máxima de memoria. Por defecto 100 (sin límite; quita uno previo). Avisa si el driver lo rechaza. |
| `-Indice <lista>` | GPU a tratar: `"0"`, `"0,1"` o `"todas"`. Sin él, con varias GPU y sesión interactiva se muestra un menú; si no, se usan todas. |
| `-Instalar` | Aplica, guarda en `gpu_limite.json` y crea o actualiza la tarea programada. |
| `-Aplicar` | Aplica lo guardado en `gpu_limite.json`. Es lo que ejecuta la tarea. |
| `-Quitar` | Restaura las GPU seleccionadas y las quita de la configuración; la tarea se borra cuando no queda ninguna. |
| `-Restaurar` | Restaura las GPU seleccionadas sin tocar la configuración ni la tarea. |
| `-Ayuda`, `-h`, `-help`, `--help` | Muestra la ayuda. |

`-Instalar`, `-Quitar`, `-Restaurar` y `-Aplicar` son excluyentes entre sí. Los atajos aceptan `-Indice`, `-Memoria`, `-SinTarea` (aplicar una vez, sin tarea), `-Quitar`, `-Restaurar` y `--help`.

## Cómo funciona

- Los valores de fábrica se leen del driver (`power.default_limit`, `power.min_limit`, `clocks.max.graphics`, `clocks.max.memory`), así que nada está fijado a una GPU concreta. Los límites se calculan siempre sobre los valores de fábrica, nunca sobre los actuales.
- El objetivo se ajusta a la frecuencia soportada más cercana (`nvidia-smi -q -d SUPPORTED_CLOCKS`) y se aplica con `-pl`, `-lgc` y `-lmc`.
- NVIDIA pierde estos ajustes al reiniciar. `-Instalar` guarda una entrada por GPU (clave: UUID) en `gpu_limite.json` y registra una **única** tarea programada, `GPU limite`, que ejecuta `gpu_limite.ps1 -Aplicar` al iniciar sesión con la cuenta SYSTEM y sin ventana. Instalar para otra GPU añade una entrada en vez de reemplazar la anterior.
- Si mueves los scripts, ejecuta `-Instalar` de nuevo para que la tarea apunte a la nueva ubicación.

## Archivos

| Archivo | Función |
|---|---|
| `gpu_limite.ps1` | Toda la lógica. |
| `gpu_limite_85.ps1`, `_90`, `_95` | Atajos: llaman al script base e instalan la tarea. |
| `gpu_restaurar.ps1` | Atajo de `gpu_limite.ps1 -Restaurar`. |
| `gpu_limite.json` | Configuración guardada; la crea `-Instalar` y git la ignora. |

## Advertencia

Cambiar los límites de potencia y frecuencia afecta a tu hardware. Usa estos scripts bajo tu responsabilidad.
