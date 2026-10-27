# Limita la GPU NVIDIA al 90 % (memoria al 85 %) usando el script base gpu_limite.ps1 e instala la tarea de inicio de sesión automáticamente.
# Acepta -Indice, -Memoria, -SinTarea (solo aplicar ahora), -Quitar, -Restaurar y --help.
[CmdletBinding(PositionalBinding = $false)]
param([string]$Indice = "", [int]$Memoria = 85, [switch]$SinTarea, [switch]$Quitar, [switch]$Restaurar,
      [Alias("h", "help")][switch]$Ayuda, [Parameter(ValueFromRemainingArguments)]$Resto)
$instalar = -not ($SinTarea -or $Quitar -or $Restaurar -or $Ayuda)
& "$PSScriptRoot\gpu_limite.ps1" -Gpu 90 -Memoria $Memoria -Indice $Indice -Instalar:$instalar -Quitar:$Quitar -Restaurar:$Restaurar -Ayuda:$Ayuda @Resto
