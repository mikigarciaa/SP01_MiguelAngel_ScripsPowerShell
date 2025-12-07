

param(
    [switch]$G,      # Crear Grupo
    [switch]$U,      # Crear Usuario
    [switch]$M,      # Modificar Usuario
    [switch]$AG,     # Asignar Grupo
    [switch]$LIST,   # Listar Objetos
    
    [Parameter(Position=0)]
    [string]$Param1 = "",
    
    [Parameter(Position=1)]
    [string]$Param2 = "",
    
    [Parameter(Position=2)]
    [string]$Param3 = "",
    
    [switch]$DryRun
)

# Variables globales
$ErrorActionPreference = "Stop"
$LogPath = "$PSScriptRoot\logs"

# Crear directorio de logs si no existe
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath | Out-Null
}

#region Funciones Auxiliares

function Write-Log {
    param(
        [string]$Mensaje,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Tipo = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = "$LogPath\nombre02.log"
    $logEntry = "[$timestamp] [$Tipo] $Mensaje"
    
    # Escribir en archivo
    Add-Content -Path $logFile -Value $logEntry
    
    # Mostrar en consola con colores
    switch ($Tipo) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARN"    { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry -ForegroundColor White }
    }
}

function Show-Help {
    Write-Host "`n=== SCRIPT DE ADMINISTRACION DE ACTIVE DIRECTORY ===" -ForegroundColor Cyan
    Write-Host "`nUSO: .\nombre02.ps1 -Accion <ACCION> [parametros] [-DryRun]`n" -ForegroundColor Yellow
    
    Write-Host "ACCIONES DISPONIBLES:" -ForegroundColor Green
    Write-Host "`n  -G   Crear Grupo" -ForegroundColor White
    Write-Host "       Param2: Nombre del grupo"
    Write-Host "       Param3: Ambito (Global, Universal, Local)"
    Write-Host "       Param4: Tipo (Security, Distribution)"
    Write-Host "       Ejemplo: .\nombre02.ps1 -G Desarrolladores Global Security"
    
    Write-Host "`n  -U   Crear Usuario" -ForegroundColor White
    Write-Host "       Param2: Nombre del usuario"
    Write-Host "       Param3: Unidad Organizativa (OU)"
    Write-Host "       Ejemplo: .\nombre02.ps1 -U jperez 'OU=Usuarios,DC=empresa,DC=local'"
    
    Write-Host "`n  -M   Modificar Usuario" -ForegroundColor White
    Write-Host "       Param2: Nombre del usuario"
    Write-Host "       Param3: Nueva contraseña"
    Write-Host "       Param4: Estado (Enable/Disable)"
    Write-Host "       Ejemplo: .\nombre02.ps1 -M jperez 'P@ssw0rd123!' Enable"
    
    Write-Host "`n  -AG  Asignar Usuario a Grupo" -ForegroundColor White
    Write-Host "       Param2: Nombre del usuario"
    Write-Host "       Param3: Nombre del grupo"
    Write-Host "       Ejemplo: .\nombre02.ps1 -AG jperez Desarrolladores"
    
    Write-Host "`n  -LIST Listar Objetos" -ForegroundColor White
    Write-Host "       Param2: Tipo (Users, Groups, Both)"
    Write-Host "       Param3: Filtro OU (opcional)"
    Write-Host "       Ejemplo: .\nombre02.ps1 -LIST Both 'OU=Usuarios,DC=empresa,DC=local'"
    
    Write-Host "`nOPCIONES:" -ForegroundColor Green
    Write-Host "  -DryRun   Simula las acciones sin ejecutarlas`n" -ForegroundColor Cyan
}

function Test-PasswordComplexity {
    param([string]$Password)
    
    # BLOQUE GENERADO POR IA - Validacion de complejidad
    $hasUpperCase = $Password -cmatch '[A-Z]'
    $hasLowerCase = $Password -cmatch '[a-z]'
    $hasNumber = $Password -cmatch '\d'
    $hasSpecial = $Password -cmatch '[!@#$%^&*()_+\-=\[\]{};:''",.<>?/\\|`~]'
    $hasMinLength = $Password.Length -ge 8
    
    $errors = @()
    if (-not $hasMinLength) { $errors += "Debe tener al menos 8 caracteres" }
    if (-not $hasUpperCase) { $errors += "Debe contener al menos una mayuscula" }
    if (-not $hasLowerCase) { $errors += "Debe contener al menos una minuscula" }
    if (-not $hasNumber) { $errors += "Debe contener al menos un numero" }
    if (-not $hasSpecial) { $errors += "Debe contener al menos un caracter especial" }
    
    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
    }
}

function New-RandomPassword {
    param([int]$Length = 12)
    
    # BLOQUE GENERADO POR IA - Generacion de contraseña aleatoria
    $uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowercase = 'abcdefghijklmnopqrstuvwxyz'
    $numbers = '0123456789'
    $special = '!@#$%^&*()_+-='
    
    $allChars = $uppercase + $lowercase + $numbers + $special
    
    # Asegurar al menos un caracter de cada tipo
    $password = @(
        $uppercase[(Get-Random -Maximum $uppercase.Length)]
        $lowercase[(Get-Random -Maximum $lowercase.Length)]
        $numbers[(Get-Random -Maximum $numbers.Length)]
        $special[(Get-Random -Maximum $special.Length)]
    )
    
    # Completar con caracteres aleatorios
    for ($i = $password.Count; $i -lt $Length; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }
    
    # Mezclar el array
    $password = $password | Get-Random -Count $password.Count
    
    return -join $password
}

#endregion

#region Funciones Principales

function New-ADGroupCustom {
    param(
        [string]$GroupName,
        [string]$GroupScope,
        [string]$GroupCategory
    )
    
    Write-Log "Iniciando creacion de grupo: $GroupName" -Tipo INFO
    
    # Validar parametros
    if ([string]::IsNullOrEmpty($GroupName)) {
        Write-Log "Error: Nombre de grupo vacio" -Tipo ERROR
        return $false
    }
    
    $validScopes = @("Global", "Universal", "Local", "DomainLocal")
    if ($GroupScope -notin $validScopes) {
        Write-Log "Error: Ambito invalido. Use: Global, Universal o Local" -Tipo ERROR
        return $false
    }
    
    $validCategories = @("Security", "Distribution")
    if ($GroupCategory -notin $validCategories) {
        Write-Log "Error: Tipo invalido. Use: Security o Distribution" -Tipo ERROR
        return $false
    }
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Se crearia el grupo '$GroupName' con Ambito=$GroupScope y Tipo=$GroupCategory" -Tipo WARN
        return $true
    }
    
    # Verificar si el grupo existe (simulado sin AD)
    $groupFile = "$LogPath\grupos.txt"
    if (Test-Path $groupFile) {
        $existingGroups = Get-Content $groupFile
        if ($existingGroups -contains $GroupName) {
            Write-Log "El grupo '$GroupName' ya existe en el sistema" -Tipo WARN
            return $false
        }
    }
    
    # Crear grupo (simulado)
    Add-Content -Path $groupFile -Value "$GroupName|$GroupScope|$GroupCategory|$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "Grupo '$GroupName' creado exitosamente" -Tipo SUCCESS
    
    return $true
}

function New-ADUserCustom {
    param(
        [string]$UserName,
        [string]$OrganizationalUnit
    )
    
    Write-Log "Iniciando creacion de usuario: $UserName" -Tipo INFO
    
    if ([string]::IsNullOrEmpty($UserName)) {
        Write-Log "Error: Nombre de usuario vacio" -Tipo ERROR
        return $false
    }
    
    # Generar contraseña aleatoria
    $password = New-RandomPassword
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Se crearia el usuario '$UserName' en '$OrganizationalUnit' con contraseña: $password" -Tipo WARN
        return $true
    }
    
    # Verificar si el usuario existe (simulado)
    $userFile = "$LogPath\usuarios.txt"
    if (Test-Path $userFile) {
        $existingUsers = Get-Content $userFile
        if ($existingUsers -match "^$UserName\|") {
            Write-Log "El usuario '$UserName' ya existe en el sistema" -Tipo WARN
            return $false
        }
    }
    
    # Crear usuario (simulado)
    Add-Content -Path $userFile -Value "$UserName|$OrganizationalUnit|$password|$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "Usuario '$UserName' creado exitosamente" -Tipo SUCCESS
    Write-Log "Contraseña generada: $password" -Tipo INFO
    
    return $true
}

function Set-ADUserCustom {
    param(
        [string]$UserName,
        [string]$NewPassword,
        [string]$AccountStatus
    )
    
    Write-Log "Modificando usuario: $UserName" -Tipo INFO
    
    # Validar contraseña
    $validation = Test-PasswordComplexity -Password $NewPassword
    if (-not $validation.IsValid) {
        Write-Log "Error: La contraseña no cumple los requisitos de complejidad:" -Tipo ERROR
        foreach ($error in $validation.Errors) {
            Write-Log "  - $error" -Tipo ERROR
        }
        return $false
    }
    
    # Validar estado
    if ($AccountStatus -notin @("Enable", "Disable")) {
        Write-Log "Error: Estado invalido. Use: Enable o Disable" -Tipo ERROR
        return $false
    }
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Se modificaria el usuario '$UserName': contraseña actualizada, estado=$AccountStatus" -Tipo WARN
        return $true
    }
    
    # Verificar usuario existe
    $userFile = "$LogPath\usuarios.txt"
    if (-not (Test-Path $userFile)) {
        Write-Log "Error: El usuario '$UserName' no existe" -Tipo ERROR
        return $false
    }
    
    $users = Get-Content $userFile
    $userExists = $false
    $updatedUsers = @()
    
    foreach ($line in $users) {
        if ($line -match "^$UserName\|") {
            $userExists = $true
            $parts = $line -split '\|'
            $updatedUsers += "$($parts[0])|$($parts[1])|$NewPassword|$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')|$AccountStatus"
        } else {
            $updatedUsers += $line
        }
    }
    
    if (-not $userExists) {
        Write-Log "Error: El usuario '$UserName' no existe" -Tipo ERROR
        return $false
    }
    
    Set-Content -Path $userFile -Value $updatedUsers
    Write-Log "Usuario '$UserName' modificado exitosamente" -Tipo SUCCESS
    Write-Log "Estado de cuenta: $AccountStatus" -Tipo INFO
    
    return $true
}

function Add-ADGroupMemberCustom {
    param(
        [string]$UserName,
        [string]$GroupName
    )
    
    Write-Log "Asignando usuario '$UserName' al grupo '$GroupName'" -Tipo INFO
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Se añadiria '$UserName' al grupo '$GroupName'" -Tipo WARN
        return $true
    }
    
    # Verificar usuario existe
    $userFile = "$LogPath\usuarios.txt"
    $groupFile = "$LogPath\grupos.txt"
    
    $userExists = $false
    $groupExists = $false
    
    if (Test-Path $userFile) {
        $users = Get-Content $userFile
        $userExists = $users -match "^$UserName\|"
    }
    
    if (Test-Path $groupFile) {
        $groups = Get-Content $groupFile
        $groupExists = $groups -contains $GroupName -or $groups -match "^$GroupName\|"
    }
    
    if (-not $userExists) {
        Write-Log "Error: El usuario '$UserName' no existe" -Tipo ERROR
        return $false
    }
    
    if (-not $groupExists) {
        Write-Log "Error: El grupo '$GroupName' no existe" -Tipo ERROR
        return $false
    }
    
    # Asignar (simulado)
    $memberFile = "$LogPath\miembros.txt"
    Add-Content -Path $memberFile -Value "$UserName|$GroupName|$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "Usuario '$UserName' añadido al grupo '$GroupName' exitosamente" -Tipo SUCCESS
    
    return $true
}

function Get-ADObjectsCustom {
    param(
        [string]$ObjectType,
        [string]$OUFilter = ""
    )
    
    Write-Log "Listando objetos: Tipo=$ObjectType, Filtro=$OUFilter" -Tipo INFO
    
    $validTypes = @("Users", "Groups", "Both")
    if ($ObjectType -notin $validTypes) {
        Write-Log "Error: Tipo invalido. Use: Users, Groups o Both" -Tipo ERROR
        return
    }
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] Se listarian objetos de tipo '$ObjectType'" -Tipo WARN
        return
    }
    
    Write-Host "`n=== LISTADO DE OBJETOS ===" -ForegroundColor Cyan
    Write-Host "Tipo: $ObjectType" -ForegroundColor Yellow
    if ($OUFilter) {
        Write-Host "Filtro OU: $OUFilter`n" -ForegroundColor Yellow
    }
    
    # Listar usuarios
    if ($ObjectType -in @("Users", "Both")) {
        Write-Host "`n--- USUARIOS ---" -ForegroundColor Green
        $userFile = "$LogPath\usuarios.txt"
        if (Test-Path $userFile) {
            $users = Get-Content $userFile
            foreach ($user in $users) {
                $parts = $user -split '\|'
                if ([string]::IsNullOrEmpty($OUFilter) -or $parts[1] -like "*$OUFilter*") {
                    Write-Host "  Usuario: $($parts[0])" -ForegroundColor White
                    Write-Host "  OU: $($parts[1])" -ForegroundColor Gray
                    Write-Host "  Creado: $($parts[3])" -ForegroundColor Gray
                    if ($parts.Count -ge 5) {
                        Write-Host "  Estado: $($parts[4])" -ForegroundColor Gray
                    }
                    Write-Host ""
                }
            }
        } else {
            Write-Host "  No hay usuarios registrados" -ForegroundColor Yellow
        }
    }
    
    # Listar grupos
    if ($ObjectType -in @("Groups", "Both")) {
        Write-Host "`n--- GRUPOS ---" -ForegroundColor Green
        $groupFile = "$LogPath\grupos.txt"
        if (Test-Path $groupFile) {
            $groups = Get-Content $groupFile
            foreach ($group in $groups) {
                $parts = $group -split '\|'
                Write-Host "  Grupo: $($parts[0])" -ForegroundColor White
                Write-Host "  Ambito: $($parts[1])" -ForegroundColor Gray
                Write-Host "  Tipo: $($parts[2])" -ForegroundColor Gray
                Write-Host "  Creado: $($parts[3])" -ForegroundColor Gray
                Write-Host ""
            }
        } else {
            Write-Host "  No hay grupos registrados" -ForegroundColor Yellow
        }
    }
}

#endregion

#region Main Logic

Write-Host "`n======================================================================================" -ForegroundColor Cyan
Write-Host "  SCRIPT DE ADMINISTRACION AD - Alexander Santana Santana y Miguel Ángel Garrido García" -ForegroundColor Cyan
Write-Host "======================================================================================`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[MODO DRY-RUN ACTIVADO]" -ForegroundColor Yellow
    Write-Host "Las acciones se simularan sin ejecutarse`n" -ForegroundColor Yellow
}

# Determinar que accion se solicito
$accionSeleccionada = ""
if ($G) { $accionSeleccionada = "-G" }
elseif ($U) { $accionSeleccionada = "-U" }
elseif ($M) { $accionSeleccionada = "-M" }
elseif ($AG) { $accionSeleccionada = "-AG" }
elseif ($LIST) { $accionSeleccionada = "-LIST" }

# Procesar accion
switch ($accionSeleccionada) {
    "" {
        Write-Log "No se especifico ninguna accion" -Tipo WARN
        Show-Help
    }
    
    "-G" {
        $result = New-ADGroupCustom -GroupName $Param1 -GroupScope $Param2 -GroupCategory $Param3
        if ($result) {
            Write-Host "`nOPERACION COMPLETADA EXITOSAMENTE" -ForegroundColor Green
        }
    }
    
    "-U" {
        $result = New-ADUserCustom -UserName $Param1 -OrganizationalUnit $Param2
        if ($result) {
            Write-Host "`nOPERACION COMPLETADA EXITOSAMENTE" -ForegroundColor Green
        }
    }
    
    "-M" {
        $result = Set-ADUserCustom -UserName $Param1 -NewPassword $Param2 -AccountStatus $Param3
        if ($result) {
            Write-Host "`nOPERACION COMPLETADA EXITOSAMENTE" -ForegroundColor Green
        }
    }
    
    "-AG" {
        $result = Add-ADGroupMemberCustom -UserName $Param1 -GroupName $Param2
        if ($result) {
            Write-Host "`nOPERACION COMPLETADA EXITOSAMENTE" -ForegroundColor Green
        }
    }
    
    "-LIST" {
        Get-ADObjectsCustom -ObjectType $Param1 -OUFilter $Param2
    }
    
    default {
        Write-Log "Accion no reconocida: $accionSeleccionada" -Tipo ERROR
        Show-Help
    }
}

Write-Host "`n========================================`n" -ForegroundColor Cyan

#endregion