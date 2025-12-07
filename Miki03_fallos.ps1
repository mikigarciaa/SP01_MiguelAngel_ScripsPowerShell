param(
    [string]$archivo,
    [bool]$dryrun = $false
)

# Validar parámetro
if (-not $archivo) {
    Write-Host "Error: Debes especificar un archivo."
    exit
}
elseif (-not (Test-Path $archivo)) {
    Write-Host "Error: El archivo no existe."
    exit
}
elseif ((Get-Item $archivo).PSIsContainer) {
    Write-Host "Error: El parámetro debe ser un fichero, no un directorio."
    exit
}

# Crear carpeta logs
$carpetaLogs = "C:\logs"
if (-not (Test-Path $carpetaLogs)) {
    New-Item -ItemType Directory -Path $carpetaLogs | Out-Null
}

# Crear carpeta proyecto
$carpetaProyecto = "C:\Users\proyecto"
if (-not (Test-Path $carpetaProyecto)) {
    New-Item -ItemType Directory -Path $carpetaProyecto | Out-Null
}

# Logs
$logErrores = "$carpetaLogs\bajaserror.log"
$logBajas   = "$carpetaLogs\bajas.log"

# Leer archivo
foreach ($linea in Get-Content $archivo) {

    # Separar datos
    $datos  = $linea -split ":"
    $nombre = $datos[0]
    $ap1    = $datos[1]
    $ap2    = $datos[2]
    $login  = $datos[3]

    # Buscar usuario
    $cuenta = Get-ADUser -LDAPFilter "(sAMAccountName=$login)" -ErrorAction SilentlyContinue

    if (-not $cuenta) {
        $marca = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content $logErrores -Value "$marca-$login-$nombre $ap1 $ap2-Usuario no existe"
        continue
    }

    # Rutas
    $personal = "C:\Users\$login"
    $trabajo  = "$personal\trabajo"
    $destino  = "$carpetaProyecto\$login"

    # Crear destino
    if (-not (Test-Path $destino)) {
        New-Item -ItemType Directory -Path $destino | Out-Null
    }

    # Comprobar carpeta trabajo
    if (-not (Test-Path $trabajo)) {
        $marca = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content $logErrores -Value "$marca-$login-$nombre $ap1 $ap2-Carpeta trabajo no encontrada"
        continue
    }

    # Mover archivos
    $archivos = Get-ChildItem $trabajo -File
    $lista = @()
    $contador = 1

    foreach ($f in $archivos) {
        Move-Item $f.FullName $destino -Force
        $lista += "$contador. $($f.Name)"
        $contador++
    }

    # Registrar bajas.log
    $marca = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $logBajas -Value "--------------"
    Add-Content $logBajas -Value "Fecha: $marca"
    Add-Content $logBajas -Value "Login: $login"
    Add-Content $logBajas -Value "Destino: $destino"
    Add-Content $logBajas -Value "Archivos movidos:"
    $lista | ForEach-Object { Add-Content $logBajas -Value $_ }
    Add-Content $logBajas -Value "TOTAL: $($lista.Count)"
    
}
