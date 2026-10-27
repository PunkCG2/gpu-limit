# Devuelve la GPU NVIDIA a su potencia y frecuencias de fábrica usando el script base gpu_limite.ps1 (acepta -Indice y --help).
[CmdletBinding(PositionalBinding = $false)]
param([string]$Indice = "", [Alias("h", "help")][switch]$Ayuda, [Parameter(ValueFromRemainingArguments)]$Resto)
& "$PSScriptRoot\gpu_limite.ps1" -Restaurar -Indice $Indice -Ayuda:$Ayuda @Resto
