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
    if ($dryrun) {
        Write-Host "[DRYRUN] Se crearía $carpetaLogs"
    } else {
        New-Item -ItemType Directory -Path $carpetaLogs | Out-Null
    }
}

# Crear carpeta proyecto
$carpetaProyecto = "C:\Users\proyecto"
if (-not (Test-Path $carpetaProyecto)) {
    if ($dryrun) {
        Write-Host "[DRYRUN] Se crearía $carpetaProyecto"
    } else {
        New-Item -ItemType Directory -Path $carpetaProyecto | Out-Null
    }
}

# Definir logs
$logErrores = "$carpetaLogs\bajaserror.log"
$logBajas   = "$carpetaLogs\bajas.log"

# Leer archivo de entrada
foreach ($linea in Get-Content $archivo) {

    # Separar datos
    $datos  = $linea -split ":"
    $nombre = $datos[0]
    $ap1    = $datos[1]
    $ap2    = $datos[2]
    $login  = $datos[3]

    # Buscar usuario en AD
    $cuenta = Get-ADUser -LDAPFilter "(sAMAccountName=$login)" -ErrorAction SilentlyContinue

    # Registrar error si usuario no existe
    if (-not $cuenta) {

        $marca = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content $logErrores -Value "$marca-$login-$nombre $ap1 $ap2-Usuario no existe"
        continue
    }

    # Definir rutas
    $personal = "C:\Users\$login"
    $trabajo  = "$personal\trabajo"
    $destino  = "$carpetaProyecto\$login"

    # Crear carpeta destino
    if (-not (Test-Path $destino)) {
        if ($dryrun) {
            Write-Host "[DRYRUN] Se crearía $destino"
        } else {
            New-Item -ItemType Directory -Path $destino | Out-Null
        }
    }

    # Verificar carpeta trabajo
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

        if ($dryrun) {
            Write-Host "[DRYRUN] Se movería $($f.FullName) → $destino"
        } else {
            Move-Item $f.FullName $destino -Force
        }

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

    if ($lista.Count -eq 0) {
        Add-Content $logBajas -Value "Ningún archivo encontrado"
    } else {
        foreach ($l in $lista) { Add-Content $logBajas -Value $l }
    }

    Add-Content $logBajas -Value "TOTAL: $($lista.Count)"

    # Cambiar propietario
    if (-not $dryrun) {
        foreach ($f in Get-ChildItem $destino) {
            $acl = Get-Acl $f.FullName
            $acl.SetOwner([System.Security.Principal.NTAccount]"Administrador")
            Set-Acl $f.FullName $acl
        }
    }

    # Eliminar usuario
    if ($dryrun) {
        Write-Host "[DRYRUN] Se eliminaría el usuario $login de AD"
    } else {
        Remove-ADUser -Identity $login -Confirm:$false -ErrorAction SilentlyContinue
    }

    # Eliminar carpeta personal
    if (Test-Path $personal) {
        if ($dryrun) {
            Write-Host "[DRYRUN] Se eliminaría la carpeta $personal"
        } else {
            Remove-Item $personal -Recurse -Force
        }
    }
}
