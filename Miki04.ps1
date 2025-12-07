param(
    [bool]$dryrun = $false
)

# Definir ruta del script a evaluar
$scriptBajas = "C:\scripts\yadey03.ps1"

# Crear carpeta logs de pruebas
$logPruebas = "C:\logs\calificacion.log"
if (-not (Test-Path "C:\logs")) { New-Item -ItemType Directory -Path "C:\logs" | Out-Null }
if (Test-Path $logPruebas) { Remove-Item $logPruebas }

# Crear función para registrar errores
function Registrar-Error {
    param([string]$mensaje)
    Add-Content $logPruebas -Value "ERROR: $mensaje"
}

# Inicializar puntuación
$puntuacion = 0
$prueba = 1

# Crear Carpeta base de pruebas
$base = "C:\Users"
$proyecto = "$base\proyecto"
if (-not (Test-Path $proyecto)) { New-Item -ItemType Directory -Path $proyecto | Out-Null }

# Crear función Crear Usuario de prueba
function Crear-Usuario {
    param($login)
    New-ADUser -Name $login -SamAccountName $login -AccountPassword (ConvertTo-SecureString "Passw0rd!" -AsPlainText -Force) -Enabled $true -Path "OU=Users,DC=empresa,DC=local"
}

# Crear función Crear Entorno personal
function Crear-Entorno {
    param($login)

    $personal = "$base\$login"
    $trabajo  = "$personal\trabajo"

    if (-not (Test-Path $personal)) { New-Item -ItemType Directory -Path $personal | Out-Null }
    if (-not (Test-Path $trabajo))  { New-Item -ItemType Directory -Path $trabajo  | Out-Null }

    # Crear ficheros de trabajo
    1..3 | ForEach-Object {
        New-Item -ItemType File -Path "$trabajo\archivo$_.txt" | Out-Null
    }
}

# Crear fichero de bajas
$ficheroBajas = "C:\bajas.txt"
if (Test-Path $ficheroBajas) { Remove-Item $ficheroBajas }
New-Item -ItemType File -Path $ficheroBajas | Out-Null

# Escribir usuarios en el fichero
Add-Content $ficheroBajas "Carlos:Gonzalez:Soto:cgon"
Add-Content $ficheroBajas "Ana:Perez:Lopez:aplo"
Add-Content $ficheroBajas "Mario:Ruiz:Lara:mrlr"
Add-Content $ficheroBajas "Lucia:Diaz:Mora:usuarioNoExiste"

# Crear usuarios reales para pruebas
Crear-Usuario "cgon"
Crear-Usuario "aplo"
Crear-Usuario "mrlr"

# Crear entornos
Crear-Entorno "cgon"
Crear-Entorno "aplo"
Crear-Entorno "mrlr"

# Ejecutar Script de bajas
Write-Host "Ejecutando script yadey03.ps..."
powershell -ExecutionPolicy Bypass -File $scriptBajas -archivo $ficheroBajas -dryrun:$dryrun

Start-Sleep -Seconds 2

### =======================
### PRUEBAS (10 en total)
### =======================


# Prueba 1: Usuario eliminado
if (-not (Get-ADUser -Filter "SamAccountName -eq 'cgon'")) {
    $puntuacion++
} else {
    Registrar-Error "Prueba 1 - El usuario cgon no fue eliminado"
}

# Prueba 2: Carpeta personal eliminada
if (-not (Test-Path "C:\Users\cgon")) {
    $puntuacion++
} else {
    Registrar-Error "Prueba 2 - Carpeta personal de cgon no eliminada"
}

# Prueba 3: Archivos movidos al destino
if (Test-Path "$proyecto\cgon\archivo1.txt") {
    $puntuacion++
} else {
    Registrar-Error "Prueba 3 - Archivos no movidos correctamente"
}

# Prueba 4: Log de bajas creado
if (Test-Path "C:\logs\bajas.log") {
    $puntuacion++
} else {
    Registrar-Error "Prueba 4 - No se creó bajas.log"
}

# Prueba 5: Log de errores creado
if (Test-Path "C:\logs\bajaserror.log") {
    $puntuacion++
} else {
    Registrar-Error "Prueba 5 - No se creó bajaserror.log"
}

# Prueba 6: Usuario inexistente registrado en bajaserror.log
$contenidoErrores = Get-Content "C:\logs\bajaserror.log"
if ($contenidoErrores -match "usuarioNoExiste") {
    $puntuacion++
} else {
    Registrar-Error "Prueba 6 - No se registró usuario inexistente en el log"
}

# Prueba 7: Cambios de propietario realizados
$destFile = Get-ChildItem "$proyecto\cgon" | Select-Object -First 1
if ($destFile) {
    $owner = (Get-Acl $destFile.FullName).Owner
    if ($owner -match "Administrador") { $puntuacion++ }
    else { Registrar-Error "Prueba 7 - Propietario incorrecto" }
}

# Prueba 8: Ficheros numerados en log
if ($contenidoErrores.Length -gt 0) { $puntuacion++ }
else { Registrar-Error "Prueba 8 - No hay numeración en el log" }

# Prueba 9: Script no falla durante ejecución
if ($LASTEXITCODE -eq 0) { $puntuacion++ }
else { Registrar-Error "Prueba 9 - El script terminó con error" }

# Prueba 10: Estructura proyecto existente
if (Test-Path $proyecto) { $puntuacion++ }
else { Registrar-Error "Prueba 10 - No existe C:\Users\proyecto" }


### =======================
### RESULTADO FINAL
### =======================

Write-Host ""
Write-Host "====================================="
Write-Host " CALIFICACIÓN FINAL: $puntuacion / 10"
Write-Host "====================================="

Add-Content $logPruebas -Value "Puntuación final: $puntuacion / 10"
