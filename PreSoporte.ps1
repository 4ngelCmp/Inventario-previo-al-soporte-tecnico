# =====================================================
# INVENTARIO PREVIO AL SOPORTE TECNICO
# FASE 1 + FASE 2 (LAPS) + FASE 3 (ADMIN)
# =====================================================

$ErrorActionPreference = "Stop"

# -----------------------------------------------------
# COMPROBAR SI SE EJECUTA COMO ADMINISTRADOR
# -----------------------------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# -----------------------------------------------------
# CABECERA
# -----------------------------------------------------
function Get-ReportHeader {
    $d = Get-Date
@"
=====================================================
INVENTARIO PREVIO AL SOPORTE TECNICO
=====================================================

Fecha: $($d.ToString("dd/MM/yyyy"))
Hora:  $($d.ToString("HH:mm:ss"))
Equipo: $env:COMPUTERNAME
Usuario ejecutor: $env:USERDOMAIN\$env:USERNAME

"@
}

# -----------------------------------------------------
# FASE 1 - SISTEMA
# -----------------------------------------------------

function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $up = (Get-Date) - $os.LastBootUpTime

    if ($cs.PartOfDomain) {
        $domainInfo = $cs.Domain
    } else {
        $domainInfo = "WORKGROUP"
    }

@"
-----------------------------------------------------
FASE 1 - RECOLECCION SIN PERMISOS DE ADMINISTRADOR
-----------------------------------------------------

[SISTEMA]
Nombre del equipo: $env:COMPUTERNAME
Dominio / Workgroup: $domainInfo
Sistema operativo: $($os.Caption)
Version: $($os.Version)
Uptime: $([int]$up.TotalHours) horas

-----------------------------------------------------
"@
}

# -----------------------------------------------------
# RED
# -----------------------------------------------------
function Get-NetworkInfo {
    $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4Address }
    $out = "[RED]`n"
    foreach ($n in $cfg) {
        $out += "Adaptador: $($n.InterfaceAlias)`n"
        $out += "IP: $($n.IPv4Address.IPAddress -join ', ')`n"
        $out += "Gateway: $($n.IPv4DefaultGateway.NextHop -join ', ')`n"
        $out += "DNS: $($n.DnsServer.ServerAddresses -join ', ')`n"
        $out += "MAC: $((Get-NetAdapter -Name $n.InterfaceAlias).MacAddress)`n"
        $out += "----`n"
    }
    return $out + "`n-----------------------------------------------------`n"
}

# -----------------------------------------------------
# UNIDADES DE RED
# -----------------------------------------------------
function Get-NetworkDrives {
    $out = "[UNIDADES DE RED]`n"
    $lines = net use 2>$null
    $found = $false

    foreach ($l in $lines) {
        if ($l -match '^\s*(?:\S+\s+)?([A-Z]:)\s+(\\\\\S+)') {
            $out += "Unidad $($Matches[1]) -> $($Matches[2])`n"
            $found = $true
        }
    }

    if (-not $found) {
        $out += "No se detectaron unidades mapeadas`n"
    }

    return $out + "`n-----------------------------------------------------`n"
}

# -----------------------------------------------------
# IMPRESORAS
# -----------------------------------------------------
function Get-Printers {
    $p = Get-CimInstance Win32_Printer
    $d = $p | Where-Object Default
    $out = "[IMPRESORAS]`n"
    if ($d) { $out += "Predeterminada: $($d.Name)`n" }
    foreach ($i in $p) { $out += "- $($i.Name)`n" }
    return $out + "`n-----------------------------------------------------`n"
}

# -----------------------------------------------------
# USUARIOS
# -----------------------------------------------------
function Get-UsersInfo {
    $profiles = Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special }
    $out = "[USUARIOS]`n"
    foreach ($p in $profiles) {
        $estado = if ($p.Loaded) { "ACTIVO" } else { "INACTIVO" }
        $out += "- $($p.LocalPath) [$estado]`n"
    }
    return $out + "`n-----------------------------------------------------`n"
}

# -----------------------------------------------------
# DATOS USUARIO ACTUAL
# -----------------------------------------------------
function Get-UserDataSummary {
    $base = "C:\Users\$env:USERNAME"
    $folders = @{ Escritorio="Desktop"; Documentos="Documents"; Descargas="Downloads" }

    $out = "[DATOS DEL USUARIO ACTUAL]`n"
    foreach ($k in $folders.Keys) {
        $path = Join-Path $base $folders[$k]
        if (Test-Path $path) {
            $files = Get-ChildItem $path -Recurse -File -EA SilentlyContinue
            $size  = ($files | Measure-Object Length -Sum).Sum
            $out += "${k}:`n"
            $out += "  Archivos: $($files.Count)`n"
            $out += "  Tamano total: $([Math]::Round($size/1GB,2)) GB`n"
        } else {
            $out += "${k}: No existe`n"
        }
    }
    return $out + "`n-----------------------------------------------------`n"
}

# -----------------------------------------------------
# FASE 2 - LAPS
# -----------------------------------------------------
function Get-LAPSInfo {
    $out = "-----------------------------------------------------`nFASE 2 - LAPS`n-----------------------------------------------------`n"
    try {
        $laps = Get-LapsADPassword -Identity $env:COMPUTERNAME -AsPlainText -ErrorAction Stop
        $out += "Cuenta admin local: $($laps.Account)`n"
        $out += "Password: $($laps.Password)`n"
        $out += "Expira: $($laps.ExpirationTimestamp)`n"
    } catch {
        $out += "ERROR: No se pudo obtener LAPS`n"
    }
    return $out + "`n"
}

# -----------------------------------------------------
# ABRIR POWERSHELL COMO ADMIN LOCAL (LAPS)
# -----------------------------------------------------
function Open-AdminShell-WithLAPS {
    try {
        $laps = Get-LapsADPassword -Identity $env:COMPUTERNAME -AsPlainText -ErrorAction Stop
        $user = ".\$($laps.Account)"
        $sec  = ConvertTo-SecureString $laps.Password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($user, $sec)
        Start-Process powershell.exe -Credential $cred -ArgumentList "-NoExit"
        return "[OK] PowerShell abierta como $user`n"
    } catch {
        return "[ERROR] No se pudo abrir PowerShell como admin con LAPS`n"
    }
}

# -----------------------------------------------------
# FASE 3 - SOLO ADMIN
# -----------------------------------------------------
function Execute-Fase3 {
    $out = @"
-----------------------------------------------------
FASE 3 - RECOLECCION CON PERMISOS DE ADMINISTRADOR
-----------------------------------------------------

"@

    Checkpoint-Computer -Description "PreSoporte $(Get-Date -Format 'yyyyMMdd_HHmm')" -RestorePointType MODIFY_SETTINGS
    $out += "[RESTORE POINT] Creado correctamente`n"

    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($d in $disks) {
        $out += "Disco $($d.DeviceID) Libre: $([Math]::Round($d.FreeSpace/1GB,2)) GB`n"
    }

    return $out
}

# =====================================================
# EJECUCION PRINCIPAL
# =====================================================
$report  = Get-ReportHeader
$report += Get-SystemInfo
$report += Get-NetworkInfo
$report += Get-NetworkDrives
$report += Get-Printers
$report += Get-UsersInfo
$report += Get-UserDataSummary
$report += Get-LAPSInfo

if (Test-IsAdmin) {
    $report += Execute-Fase3
} else {
    $report += "FASE 3 NO EJECUTADA: requiere administrador.`n"
    $report += Open-AdminShell-WithLAPS
}

$path = "$env:USERPROFILE\Desktop\Inventario_PreSoporte_$($env:COMPUTERNAME).txt"
$report | Out-File -FilePath $path -Encoding UTF8

Write-Host "Informe generado en:`n$path" -ForegroundColor Green
Read-Host "Pulsa ENTER para salir"