<#
  Script base: limita la GPU NVIDIA a un porcentaje de su potencia por defecto y de sus frecuencias máximas.
  -Gpu      % de potencia y de frecuencia máxima del núcleo (1-100, por defecto 100)
  -Memoria  % de frecuencia máxima de la memoria (1-100, por defecto 100 = sin límite)
  -Indice   GPU(s) a tratar: "0", "0,1" o "todas". Sin este parámetro, con varias GPU se muestra un menú de selección.
            Las frecuencias se ajustan al paso soportado más cercano (nvidia-smi -q -d SUPPORTED_CLOCKS).

  Uso (en PowerShell; si no es administrador, el script pide permisos solo):
    .\gpu_limite.ps1 -Gpu 90 -Memoria 95              aplica los límites ahora
    .\gpu_limite.ps1 -Gpu 90 -Instalar                aplica y crea la tarea programada (cuenta SYSTEM, sin ventana) que los aplica en cada inicio de sesión
    .\gpu_limite.ps1 -Quitar                          borra la tarea programada y devuelve la GPU a sus valores de fábrica
    .\gpu_limite.ps1 -Restaurar                       devuelve la GPU a sus valores de fábrica sin tocar la tarea programada
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateRange(1, 100)][int]$Gpu = 100,
    [ValidateRange(1, 100)][int]$Memoria = 100,
    [string]$Indice = "",
    [switch]$Instalar, [switch]$Quitar, [switch]$Restaurar, [switch]$Aplicar,
    [Alias("h", "help")][switch]$Ayuda,
    [Parameter(ValueFromRemainingArguments)]$Resto
)

function Mostrar-Ayuda {
    @"
gpu_limite.ps1 - Limita potencia y frecuencias de GPU(s) NVIDIA a un porcentaje de los valores de fábrica.

USO
  .\gpu_limite.ps1 [-Gpu <1-100>] [-Memoria <1-100>] [-Indice <lista>] [-Instalar | -Quitar | -Restaurar | -Aplicar]
  .\gpu_limite.ps1 -Ayuda | -h | -help | --help

PARÁMETROS
  -Gpu <1-100>        % de la potencia por defecto y de la frecuencia máxima del núcleo. Por defecto: 100.
                      La potencia nunca baja del mínimo que permite la GPU (power.min_limit).
  -Memoria <1-100>    % de la frecuencia máxima de memoria. Por defecto: 100 (sin límite; quita cualquier tope previo).
                      Si el driver o la GPU no permiten limitar la memoria, avisa y continúa.
  -Indice <lista>     GPU(s) a tratar: "0", "0,1" o "todas". Sin este parámetro: con varias GPU y sesión
                      interactiva se muestra un menú; con una sola GPU o sin sesión interactiva se usan todas.
  -Instalar           Aplica los límites, los guarda en gpu_limite.json (una entrada por GPU, clave UUID) y
                      crea/actualiza la tarea única "GPU limite" (cuenta SYSTEM, sin ventana), que en cada
                      inicio de sesión ejecuta -Aplicar. Instalar para otra GPU añade su entrada sin pisar las
                      demás. Borra las tareas antiguas "GPU limite 85/90/95". Si se mueve el script, repetir -Instalar.
  -Aplicar            Aplica lo guardado en gpu_limite.json (es lo que ejecuta la tarea). Sin configuración: error.
  -Quitar             Restaura las GPU seleccionadas a fábrica y las quita de gpu_limite.json; la tarea se
                      borra cuando no queda ninguna GPU configurada.
  -Restaurar          Restaura las GPU seleccionadas a fábrica sin tocar la configuración ni la tarea.
  -Ayuda, -h, -help, --help   Muestra esta ayuda.

NOTAS
  - Las frecuencias se ajustan al paso soportado más cercano (nvidia-smi -q -d SUPPORTED_CLOCKS).
  - Si no se ejecuta como administrador, el script pide permisos solo.
  - Los límites se pierden al reiniciar; por eso existe la tarea programada.
  - -Instalar, -Quitar, -Restaurar y -Aplicar son excluyentes entre sí.

ATAJOS (aceptan -Indice, -Memoria, -SinTarea, -Quitar, -Restaurar, -Ayuda; instalan la tarea automáticamente)
  gpu_limite_85.ps1   GPU 85 %, Memoria 50 %   (-Memoria permite cambiarlo)
  gpu_limite_90.ps1   GPU 90 %, Memoria 85 %   (-Memoria permite cambiarlo)
  gpu_limite_95.ps1   GPU 95 %, Memoria 90 %   (-Memoria permite cambiarlo)
  gpu_restaurar.ps1   Equivale a gpu_limite.ps1 -Restaurar

EJEMPLOS
  .\gpu_limite.ps1 -Gpu 90 -Memoria 95            aplica ahora
  .\gpu_limite.ps1 -Gpu 90 -Instalar -Indice 0    aplica y deja la tarea para la GPU 0
  .\gpu_limite_95.ps1                             preset 95: aplica y deja la tarea programada
  .\gpu_limite_95.ps1 -SinTarea                    preset 95 solo ahora, sin tarea
  .\gpu_limite.ps1 -Aplicar                        reaplica lo guardado
  .\gpu_limite.ps1 -Quitar                        deshace todo
"@ | Write-Host
}

if ($Ayuda -or ($Resto -match '^(-{1,2}help|-h|/\?|-\?)$')) { Mostrar-Ayuda; exit 0 }
if ($Resto) { Write-Host "Argumento no reconocido: $($Resto -join ' ')`n" -ForegroundColor Red; Mostrar-Ayuda; exit 1 }
if (@($Instalar, $Quitar, $Restaurar, $Aplicar).Where({ $_ }).Count -gt 1) {
    Write-Host "-Instalar, -Quitar, -Restaurar y -Aplicar son excluyentes.`n" -ForegroundColor Red; Mostrar-Ayuda; exit 1
}

$NombreTarea = "GPU limite"
$TareasViejas = @("GPU limite 85", "GPU limite 90", "GPU limite 95")
$Ruta = $MyInvocation.MyCommand.Path
$Config = Join-Path (Split-Path $Ruta) "gpu_limite.json"

# --- pedir permisos de administrador si hace falta
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
          [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$Ruta`"", "-Gpu", $Gpu, "-Memoria", $Memoria)
    if ($Indice)     { $argsList += @("-Indice", "`"$Indice`"") }
    if ($Instalar)   { $argsList += "-Instalar" }
    if ($Quitar)     { $argsList += "-Quitar" }
    if ($Restaurar)  { $argsList += "-Restaurar" }
    if ($Aplicar)    { $argsList += "-Aplicar" }
    Start-Process powershell -Verb RunAs -ArgumentList $argsList
    exit
}

function Leer($campo, $i) {
    $v = (nvidia-smi -i $i --query-gpu=$campo --format=csv,noheader,nounits) -split "`n" | Select-Object -First 1
    return [double]$v.Trim()
}

# Frecuencias soportadas por la GPU: @{ Memoria = @(...); Graficos = @(...) } (gráficos del bloque de mayor memoria)
function Soportadas($i) {
    $bloques = @{}; $actual = 0
    foreach ($l in (nvidia-smi -q -d SUPPORTED_CLOCKS -i $i)) {
        if ($l -match '^\s+Memory\s*:\s*(\d+) MHz')     { $actual = [int]$Matches[1]; $bloques["$actual"] = @() }
        elseif ($l -match '^\s+Graphics\s*:\s*(\d+) MHz' -and $actual) { $bloques["$actual"] += [int]$Matches[1] }
    }
    $mem = @($bloques.Keys | ForEach-Object { [int]$_ })
    $gfx = if ($mem.Count) { $bloques["$(($mem | Measure-Object -Maximum).Maximum)"] } else { @() }
    return @{ Memoria = $mem; Graficos = @($gfx) }
}

# Paso soportado más cercano al objetivo; si no hay lista, devuelve el objetivo
function Ajustar($objetivo, $lista) {
    if (-not $lista -or $lista.Count -eq 0) { return [int]$objetivo }
    return ($lista | Sort-Object { [math]::Abs($_ - $objetivo) } | Select-Object -First 1)
}

function Restaurar-Gpu($g) {
    $i = $g.Indice
    $def = Leer "power.default_limit" $i
    nvidia-smi -i $i -rgc | Out-Null
    nvidia-smi -i $i -rmc | Out-Null
    nvidia-smi -i $i -pl ([math]::Round($def)) | Out-Null
    Write-Host "Restaurada a $def W y frecuencias de fábrica." -ForegroundColor Green
}

function Aplicar-Limite($g, $pct, $pctMem) {
    $i = $g.Indice
    $def = Leer "power.default_limit" $i
    $min = Leer "power.min_limit" $i
    $max = Leer "clocks.max.graphics" $i
    $sop = Soportadas $i
    $pl  = [math]::Max([math]::Round($def * $pct / 100), [math]::Ceiling($min))
    $clk = Ajustar ($max * $pct / 100) $sop.Graficos
    nvidia-smi -i $i -pl $pl | Out-Null
    nvidia-smi -i $i -lgc "0,$clk" | Out-Null
    Write-Host ("GPU {0} %  |  Potencia: {1} W -> {2} W   |   Frecuencia máx.: {3} MHz -> {4} MHz" -f $pct, $def, $pl, $max, $clk) -ForegroundColor Green

    if ($pctMem -lt 100) {
        $mmax = Leer "clocks.max.memory" $i
        $mclk = Ajustar ($mmax * $pctMem / 100) $sop.Memoria
        nvidia-smi -i $i -lmc "0,$mclk" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("Memoria {0} %  |  Frecuencia máx.: {1} MHz -> {2} MHz" -f $pctMem, $mmax, $mclk) -ForegroundColor Green
        } else {
            Write-Host "El driver o la GPU no permite limitar la frecuencia de memoria (nvidia-smi -lmc)." -ForegroundColor Yellow
        }
    } else {
        nvidia-smi -i $i -rmc | Out-Null
    }
    Write-Host ("Límite actual reportado por el driver: {0} W" -f (Leer "power.limit" $i))
}

# Configuración guardada: una entrada por GPU (clave: UUID) con su Gpu % y Memoria %
function Leer-Config {
    if (-not (Test-Path $Config)) { return @() }
    try { return @(Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return @() }
}
function Guardar-Config($entradas) {
    if (@($entradas).Count -eq 0) { Remove-Item $Config -ErrorAction SilentlyContinue; return }
    ConvertTo-Json -InputObject @($entradas) | Set-Content $Config -Encoding UTF8
}

if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
    Write-Host "No encontré nvidia-smi (viene con el driver de NVIDIA)." -ForegroundColor Red
    Start-Sleep 5; exit 1
}

$gpus = @(nvidia-smi --query-gpu=index,uuid,name --format=csv,noheader | ForEach-Object {
    $p = $_ -split ",\s*", 3; [pscustomobject]@{ Indice = [int]$p[0]; Uuid = $p[1]; Nombre = $p[2] } })
if ($gpus.Count -eq 0) { Write-Host "nvidia-smi no devolvió ninguna GPU." -ForegroundColor Red; Start-Sleep 5; exit 1 }

# --- modo tarea: aplicar lo guardado en la configuración
if ($Aplicar) {
    $guardada = Leer-Config
    if ($guardada.Count -eq 0) { Write-Host "No hay configuración guardada ($Config). Usa -Instalar primero." -ForegroundColor Yellow; exit 1 }
    foreach ($c in $guardada) {
        $g = $gpus | Where-Object { $_.Uuid -eq $c.Uuid } | Select-Object -First 1
        if (-not $g) { Write-Host ("GPU {0} ({1}) no está presente; se omite." -f $c.Indice, $c.Nombre) -ForegroundColor Yellow; continue }
        Write-Host ("--- GPU {0}: {1}" -f $g.Indice, $g.Nombre) -ForegroundColor Cyan
        Aplicar-Limite $g $c.Gpu $c.Memoria
    }
    if ([Environment]::UserInteractive) { Start-Sleep 5 }
    exit 0
}

# --- elegir GPU(s)
if (-not $Indice -and $gpus.Count -gt 1 -and [Environment]::UserInteractive) {
    Write-Host "GPU detectadas:"
    foreach ($g in $gpus) { Write-Host ("  [{0}] {1}" -f $g.Indice, $g.Nombre) }
    Write-Host "  [T] Todas"
    $Indice = Read-Host "Elige una, varias separadas por coma (ej. 0,1) o T para todas"
}
if (-not $Indice -or $Indice -match '^\s*(t|todas?)\s*$') { $seleccion = $gpus }
else {
    $pedidas = $Indice -split "[,\s]+" | Where-Object { $_ -ne "" } | ForEach-Object { [int]$_ }
    $seleccion = @($gpus | Where-Object { $pedidas -contains $_.Indice })
    if ($seleccion.Count -eq 0) { Write-Host "Ninguna GPU coincide con '$Indice'." -ForegroundColor Red; Start-Sleep 5; exit 1 }
}

foreach ($g in $seleccion) {
    Write-Host ("--- GPU {0}: {1}" -f $g.Indice, $g.Nombre) -ForegroundColor Cyan
    if ($Quitar -or $Restaurar) { Restaurar-Gpu $g } else { Aplicar-Limite $g $Gpu $Memoria }
}

if ($Quitar) {
    # quitar solo las GPU seleccionadas de la configuración; la tarea se borra cuando no queda ninguna
    $uuids = @($seleccion.Uuid)
    $restantes = @(Leer-Config | Where-Object { $uuids -notcontains $_.Uuid })
    Guardar-Config $restantes
    if ($restantes.Count -eq 0) {
        foreach ($t in @($NombreTarea) + $TareasViejas) { Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue }
        Write-Host "Sin GPU configuradas: tarea '$NombreTarea' eliminada." -ForegroundColor Green
    } else {
        Write-Host ("La tarea '$NombreTarea' sigue activa para {0} GPU." -f $restantes.Count) -ForegroundColor Green
    }
    Start-Sleep 5; exit 0
}
if ($Restaurar) { Start-Sleep 5; exit 0 }

# --- tarea programada única (al iniciar sesión, con privilegios elevados): aplica la configuración guardada
if ($Instalar) {
    $uuids = @($seleccion.Uuid)
    $entradas = @(Leer-Config | Where-Object { $uuids -notcontains $_.Uuid })
    $entradas += @($seleccion | ForEach-Object {
        [pscustomobject]@{ Uuid = $_.Uuid; Indice = $_.Indice; Nombre = $_.Nombre; Gpu = $Gpu; Memoria = $Memoria } })
    Guardar-Config $entradas

    foreach ($t in $TareasViejas) { Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue }
    $accion   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Ruta`" -Aplicar"
    $disparo  = New-ScheduledTaskTrigger -AtLogOn
    # Cuenta SYSTEM: corre en segundo plano, sin abrir ninguna ventana al iniciar sesión
    $usuario  = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $ajustes  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    Register-ScheduledTask -TaskName $NombreTarea -Action $accion -Trigger $disparo -Principal $usuario -Settings $ajustes -Force | Out-Null
    Write-Host "Tarea programada '$NombreTarea' lista: aplicará en cada inicio de sesión la configuración de $($entradas.Count) GPU ($Config)." -ForegroundColor Green
    foreach ($e in $entradas) { Write-Host ("  GPU {0} ({1}): {2} % / Memoria {3} %" -f $e.Indice, $e.Nombre, $e.Gpu, $e.Memoria) }
}
if ($Instalar -or [Environment]::UserInteractive) { Start-Sleep 5 }
