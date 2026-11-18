# ==========================================
# INFRASTRUCTURE HEALTH CHECK TOOL
# ==========================================
# Runs a health check on a Windows machine and generates
# TXT, JSON and LOG reports in the output folder.
#
# Usage:
#   .\Infrastructure-HealthCheck.ps1
#   .\Infrastructure-HealthCheck.ps1 -OutputDir "C:\Temp\HealthCheck"
# ==========================================

param(
    [string]$OutputDir = (Join-Path $(if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }) "reports")
)

# Guardar todos los archivos en UTF-8 (en PowerShell 5.1 el default es UTF-16)
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Crear la carpeta de salida si no existe
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$rutaReporte = Join-Path $OutputDir "HealthCheckReport.txt"
$rutaJSON    = Join-Path $OutputDir "HealthCheckDiagnostic.json"
$rutaLog     = Join-Path $OutputDir "HealthCheckDiagnostic.log"


# ==========================================
# FUNCIONES GENERALES
# ==========================================

function Add-Reporte {

    param(
        [Parameter(Mandatory=$true)]
        [string]$Texto
    )

    $Texto | Out-File $rutaReporte -Append
}


function Write-Log {

    param(
        [Parameter(Mandatory=$true)]
        [string]$Mensaje,

        [string]$Nivel = "INFO"
    )

    $fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    "$fecha [$Nivel] $Mensaje" |
        Out-File $rutaLog -Append
}


# ==========================================
# SISTEMA
# ==========================================

function Test-Sistema {

    Write-Log -Mensaje "Iniciando diagnostico del sistema"

    try {

        $sistema = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop

        Add-Reporte " "
        Add-Reporte "=== SISTEMA ==="
        Add-Reporte "Windows: $($sistema.Caption)"
        Add-Reporte "Version: $($sistema.Version)"
        Add-Reporte "Ultimo inicio: $($sistema.LastBootUpTime)"

        Write-Log -Mensaje "Diagnostico del sistema completado"

        [PSCustomObject]@{
            Windows      = $sistema.Caption
            Version      = $sistema.Version
            UltimoInicio = $sistema.LastBootUpTime
        }
    }
    catch {

        $mensajeError = $_.Exception.Message

        Add-Reporte " "
        Add-Reporte "=== SISTEMA ==="
        Add-Reporte "ERROR: No se pudo consultar el sistema"

        Write-Log -Mensaje "Error consultando sistema: $mensajeError" -Nivel "ERROR"

        [PSCustomObject]@{
            Windows      = $null
            Version      = $null
            UltimoInicio = $null
            Estado       = "ERROR"
            Error        = $mensajeError
        }
    }
}


# ==========================================
# RAM
# ==========================================

function Test-RAM {

    Write-Log -Mensaje "Iniciando diagnostico de RAM"

    try {

        $sistema = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop

        $totalRAM = [math]::Round(
            $sistema.TotalVisibleMemorySize / 1MB, 2
        )

        $libreRAM = [math]::Round(
            $sistema.FreePhysicalMemory / 1MB, 2
        )

        $porcentajeLibre = [math]::Round(
            ($libreRAM / $totalRAM) * 100, 2
        )

        if ($porcentajeLibre -lt 10) {
            $estadoRAM = "CRITICO"

            Write-Log `
                -Mensaje "Memoria RAM critica: $porcentajeLibre% libre" `
                -Nivel "ERROR"
        }
        elseif ($porcentajeLibre -lt 20) {
            $estadoRAM = "ADVERTENCIA"

            Write-Log `
                -Mensaje "Memoria RAM baja: $porcentajeLibre% libre" `
                -Nivel "WARNING"
        }
        else {
            $estadoRAM = "OK"

            Write-Log `
                -Mensaje "Diagnostico de RAM completado. Estado: OK"
        }

        Add-Reporte " "
        Add-Reporte "=== RAM ==="
        Add-Reporte "RAM total: $totalRAM GB"
        Add-Reporte "RAM libre: $libreRAM GB ($porcentajeLibre%)"
        Add-Reporte "Estado: $estadoRAM"

        [PSCustomObject]@{
            TotalGB         = $totalRAM
            LibreGB         = $libreRAM
            PorcentajeLibre = $porcentajeLibre
            Estado          = $estadoRAM
        }
    }
    catch {

        $mensajeError = $_.Exception.Message

        Add-Reporte " "
        Add-Reporte "=== RAM ==="
        Add-Reporte "ERROR: No se pudo consultar la memoria RAM"

        Write-Log `
            -Mensaje "Error consultando RAM: $mensajeError" `
            -Nivel "ERROR"

        [PSCustomObject]@{
            TotalGB         = $null
            LibreGB         = $null
            PorcentajeLibre = $null
            Estado          = "ERROR"
            Error           = $mensajeError
        }
    }
}


# ==========================================
# DISCO
# ==========================================

function Test-Disco {

    Write-Log -Mensaje "Iniciando diagnostico de disco"

    try {

        $disco = Get-Volume -DriveLetter C -ErrorAction Stop

        $libreGB = [math]::Round(
            $disco.SizeRemaining / 1GB, 2
        )

        if ($libreGB -lt 10) {
            $estadoDisco = "ADVERTENCIA"

            Write-Log `
                -Mensaje "Poco espacio en disco C: $libreGB GB libres" `
                -Nivel "WARNING"
        }
        else {
            $estadoDisco = "OK"
        }

        Add-Reporte " "
        Add-Reporte "=== DISCO ==="
        Add-Reporte "Disco C libre: $libreGB GB"
        Add-Reporte "Estado: $estadoDisco"

        Write-Log `
            -Mensaje "Diagnostico de disco completado. Estado: $estadoDisco"

        [PSCustomObject]@{
            Unidad  = "C"
            LibreGB = $libreGB
            Estado  = $estadoDisco
        }
    }
    catch {

        $mensajeError = $_.Exception.Message

        Add-Reporte " "
        Add-Reporte "=== DISCO ==="
        Add-Reporte "ERROR: No se pudo consultar el disco"

        Write-Log `
            -Mensaje "Error consultando disco: $mensajeError" `
            -Nivel "ERROR"

        [PSCustomObject]@{
            Unidad  = "C"
            LibreGB = $null
            Estado  = "ERROR"
            Error   = $mensajeError
        }
    }
}


# ==========================================
# RED
# ==========================================

function Test-Red {

    Write-Log -Mensaje "Iniciando diagnostico de red"

    Add-Reporte " "
    Add-Reporte "=== RED ==="

    try {

        $red = Get-NetIPConfiguration -ErrorAction Stop |
            Where-Object IPv4Address
    }
    catch {

        $mensajeError = $_.Exception.Message

        Add-Reporte "ERROR: No se pudieron consultar los adaptadores"

        Write-Log `
            -Mensaje "Error consultando adaptadores: $mensajeError" `
            -Nivel "ERROR"

        return @()
    }

    $resultadoRed = foreach ($adaptador in $red) {

        try {

            $gateway = $null
            $gatewayResponde = "NO APLICA"

            if ($adaptador.IPv4DefaultGateway) {

                $gateway = $adaptador.IPv4DefaultGateway.NextHop

                try {

                    $responde = Test-Connection `
                        $gateway `
                        -Count 1 `
                        -Quiet `
                        -ErrorAction Stop

                    if ($responde) {
                        $gatewayResponde = "SI"
                    }
                    else {
                        $gatewayResponde = "NO"

                        Write-Log `
                            -Mensaje "Gateway $gateway no responde" `
                            -Nivel "WARNING"
                    }
                }
                catch {

                    $gatewayResponde = "ERROR"

                    Write-Log `
                        -Mensaje "Error comprobando gateway $gateway" `
                        -Nivel "ERROR"
                }
            }

            Add-Reporte "------------------------"
            Add-Reporte "Adaptador: $($adaptador.InterfaceAlias)"
            Add-Reporte "IPv4: $($adaptador.IPv4Address.IPAddress)"
            Add-Reporte "DNS: $($adaptador.DNSServer.ServerAddresses)"

            if ($gateway) {
                Add-Reporte "Gateway: $gateway"
                Add-Reporte "Gateway responde: $gatewayResponde"
            }
            else {
                Add-Reporte "Gateway: No configurado"
            }

            [PSCustomObject]@{
                Adaptador       = $adaptador.InterfaceAlias
                IPv4            = $adaptador.IPv4Address.IPAddress
                DNS             = $adaptador.DNSServer.ServerAddresses
                Gateway         = $gateway
                GatewayResponde = $gatewayResponde
                Estado          = "OK"
            }
        }
        catch {

            $mensajeError = $_.Exception.Message

            Write-Log `
                -Mensaje "Error procesando adaptador $($adaptador.InterfaceAlias): $mensajeError" `
                -Nivel "ERROR"

            [PSCustomObject]@{
                Adaptador       = $adaptador.InterfaceAlias
                IPv4            = $null
                DNS             = $null
                Gateway         = $null
                GatewayResponde = $null
                Estado          = "ERROR"
                Error           = $mensajeError
            }
        }
    }

    Write-Log -Mensaje "Diagnostico de red completado"

    return $resultadoRed
}


# ==========================================
# CONECTIVIDAD
# ==========================================

function Test-Conectividad {

    Write-Log -Mensaje "Iniciando diagnostico de conectividad"

    Add-Reporte " "
    Add-Reporte "=== CONECTIVIDAD ==="

    try {

        $conexion = Test-Connection `
            8.8.8.8 `
            -Count 1 `
            -Quiet `
            -ErrorAction Stop

        if ($conexion) {
            $estadoInternet = "OK"
        }
        else {
            $estadoInternet = "ERROR"
        }
    }
    catch {
        $estadoInternet = "ERROR"
    }

    try {

        Resolve-DnsName `
            microsoft.com `
            -ErrorAction Stop | Out-Null

        $estadoDNS = "OK"
    }
    catch {
        $estadoDNS = "ERROR"
    }

    Add-Reporte "Internet: $estadoInternet"
    Add-Reporte "DNS: $estadoDNS"

    if ($estadoInternet -eq "ERROR") {

        Write-Log `
            -Mensaje "La prueba de conectividad a Internet fallo" `
            -Nivel "ERROR"
    }
    else {

        Write-Log `
            -Mensaje "Conectividad a Internet correcta"
    }

    if ($estadoDNS -eq "ERROR") {

        Write-Log `
            -Mensaje "La resolucion DNS fallo" `
            -Nivel "ERROR"
    }
    else {

        Write-Log `
            -Mensaje "Resolucion DNS correcta"
    }

    [PSCustomObject]@{
        Internet = $estadoInternet
        DNS      = $estadoDNS
    }
}


# ==========================================
# SERVICIOS
# ==========================================

function Test-Servicios {

    Write-Log -Mensaje "Iniciando diagnostico de servicios"

    Add-Reporte " "
    Add-Reporte "=== SERVICIOS ==="

    $servicios = "Spooler", "WinRM", "W32Time"

    $resultadoServicios = foreach ($servicio in $servicios) {

        try {

            $estado = Get-Service $servicio -ErrorAction Stop

            if ($estado.Status -eq "Running") {

                $diagnosticoServicio = "OK"

                Write-Log `
                    -Mensaje "Servicio ${servicio}: Running"
            }
            else {

                $diagnosticoServicio = "ADVERTENCIA"

                Write-Log `
                    -Mensaje "Servicio ${servicio}: $($estado.Status)" `
                    -Nivel "WARNING"
            }

            Add-Reporte `
                "$servicio : $($estado.Status) [$diagnosticoServicio]"

            [PSCustomObject]@{
                Nombre      = $servicio
                Estado      = $estado.Status.ToString()
                Diagnostico = $diagnosticoServicio
                Error       = $null
            }
        }
        catch {

            $mensajeError = $_.Exception.Message

            Add-Reporte "$servicio : ERROR al consultar"

            Write-Log `
                -Mensaje "Error consultando servicio $servicio : $mensajeError" `
                -Nivel "ERROR"

            [PSCustomObject]@{
                Nombre      = $servicio
                Estado      = $null
                Diagnostico = "ERROR"
                Error       = $mensajeError
            }
        }
    }

    return $resultadoServicios
}


# ==========================================
# EVENT LOGS
# ==========================================

function Test-EventLogs {

    Write-Log -Mensaje "Iniciando consulta de Event Logs"

    Add-Reporte " "
    Add-Reporte "=== ERRORES RECIENTES DE WINDOWS ==="

    try {

        $errores = Get-WinEvent -FilterHashtable @{
            LogName = "System"
            Level   = 2
        } -MaxEvents 10 -ErrorAction Stop

        $resultadoEventos = foreach ($evento in $errores) {

            Add-Reporte "------------------------"
            Add-Reporte "Fecha: $($evento.TimeCreated)"
            Add-Reporte "Event ID: $($evento.Id)"
            Add-Reporte "Origen: $($evento.ProviderName)"

            [PSCustomObject]@{
                Fecha  = $evento.TimeCreated
                ID     = $evento.Id
                Origen = $evento.ProviderName
            }
        }

        Add-Reporte "Total mostrado: $($errores.Count)"

        Write-Log -Mensaje "Event Logs consultados. Eventos mostrados: $($errores.Count)"

        return $resultadoEventos
    }
    catch {

        $mensajeError = $_.Exception.Message

        Add-Reporte "ERROR consultando Event Logs: $mensajeError"

        Write-Log -Mensaje "Error consultando Event Logs: $mensajeError" -Nivel "ERROR"

        return @(
            [PSCustomObject]@{
                Fecha  = $null
                ID     = $null
                Origen = $null
                Error  = $mensajeError
            }
        )
    }
}


# ==========================================
# API ENDPOINTS
# ==========================================

function Test-ApiEndpoints {

    Write-Log -Mensaje "Iniciando verificacion de APIs"

    Add-Reporte " "
    Add-Reporte "=== API ENDPOINTS ==="

    $endpoints = @(
        "https://api.github.com",
        "https://www.microsoft.com",
        "https://www.google.com"
    )

    $resultadoAPIs = foreach ($api in $endpoints) {

        try {

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $respuesta = Invoke-WebRequest `
                -Uri $api `
                -Method Head `
                -UseBasicParsing `
                -TimeoutSec 10 `
                -ErrorAction Stop

            $stopwatch.Stop()

            $tiempo = $stopwatch.ElapsedMilliseconds
            $statusCode = $respuesta.StatusCode

            if ($tiempo -lt 1000) {
                $rendimiento = "OPTIMO"
            }
            elseif ($tiempo -lt 3000) {
                $rendimiento = "ACEPTABLE"
            }
            else {
                $rendimiento = "DEGRADADO"
            }

            Add-Reporte "------------------------"
            Add-Reporte "URL: $api"
            Add-Reporte "Estado: OK"
            Add-Reporte "Status Code: $statusCode"
            Add-Reporte "Tiempo: $tiempo ms"
            Add-Reporte "Rendimiento: $rendimiento"

            Write-Log `
                -Mensaje "API $api responde en $tiempo ms"

            [PSCustomObject]@{
                URL         = $api
                Estado      = "OK"
                StatusCode  = $statusCode
                TiempoMs    = $tiempo
                Rendimiento = $rendimiento
            }
        }
        catch {

            $mensajeError = $_.Exception.Message

            Add-Reporte "------------------------"
            Add-Reporte "URL: $api"
            Add-Reporte "Estado: ERROR"
            Add-Reporte "Error: $mensajeError"

            Write-Log `
                -Mensaje "Error consultando API $api : $mensajeError" `
                -Nivel "ERROR"

            [PSCustomObject]@{
                URL      = $api
                Estado   = "ERROR"
                TiempoMs = $null
                Error    = $mensajeError
            }
        }
    }

    Write-Log -Mensaje "Verificacion de APIs completada"

    return $resultadoAPIs
}


# ==========================================
# RESUMEN DEL DIAGNOSTICO
# ==========================================

function Get-ResumenDiagnostico {

    param(
        $RAM,
        $Disco,
        $Conectividad,
        $Servicios,
        $Eventos,
        $APIs
    )

    Write-Log -Mensaje "Generando resumen del diagnostico"

    $resumen = @()
    $problemas = @()
    $hayCritico = $false


    # ------------------------------------------
    # RAM
    # ------------------------------------------

    $resumen += "RAM: $($RAM.Estado) - $($RAM.PorcentajeLibre)% disponible"

    if ($RAM.Estado -ne "OK") {

        $problemas += "RAM: $($RAM.Estado) - $($RAM.PorcentajeLibre)% disponible"

        if ($RAM.Estado -eq "CRITICO") {
            $hayCritico = $true
        }
    }


    # ------------------------------------------
    # DISCO
    # ------------------------------------------

    $resumen += "Disco C: $($Disco.Estado) - $($Disco.LibreGB) GB disponibles"

    if ($Disco.Estado -ne "OK") {

        $problemas += "Disco C: $($Disco.Estado) - $($Disco.LibreGB) GB disponibles"

        if ($Disco.Estado -eq "CRITICO") {
            $hayCritico = $true
        }
    }


    # ------------------------------------------
    # CONECTIVIDAD
    # ------------------------------------------

    $resumen += "Internet: $($Conectividad.Internet)"
    $resumen += "DNS: $($Conectividad.DNS)"

    if ($Conectividad.Internet -ne "OK") {

        $problemas += "Internet: $($Conectividad.Internet)"

        # Sin Internet se considera problema critico
        $hayCritico = $true
    }

    if ($Conectividad.DNS -ne "OK") {

        $problemas += "DNS: $($Conectividad.DNS)"

        # Fallo DNS tambien se considera critico
        $hayCritico = $true
    }


    # ------------------------------------------
    # SERVICIOS
    # ------------------------------------------

    foreach ($servicio in $Servicios) {

        $resumen += "Servicio $($servicio.Nombre): $($servicio.Diagnostico)"

        if ($servicio.Diagnostico -ne "OK") {

            $problemas += "Servicio $($servicio.Nombre): $($servicio.Estado) [$($servicio.Diagnostico)]"
        }
    }


    # ------------------------------------------
    # EVENT LOGS
    # ------------------------------------------

    $resumen += "Errores recientes de Windows: $($Eventos.Count)"

    if ($Eventos.Count -gt 0) {

        $problemas += "Event Logs: se encontraron $($Eventos.Count) errores recientes"
    }


    # ------------------------------------------
    # API ENDPOINTS
    # ------------------------------------------

    $apisOK = ($APIs | Where-Object Estado -eq "OK").Count
    $apisError = ($APIs | Where-Object Estado -eq "ERROR").Count

    $resumen += "APIs disponibles: $apisOK"
    $resumen += "APIs con error: $apisError"

    if ($apisError -gt 0) {

        $problemas += "APIs con error: $apisError"
    }


    # ------------------------------------------
    # ESTADO GENERAL
    # ------------------------------------------

    if ($hayCritico) {

        $estadoGeneral = "CRITICO"
    }
    elseif ($problemas.Count -gt 0) {

        $estadoGeneral = "ADVERTENCIA"
    }
    else {

        $estadoGeneral = "OK"
    }


    # ------------------------------------------
    # GUARDAR RESUMEN EN TXT
    # ------------------------------------------

    Add-Reporte " "
    Add-Reporte "=== RESUMEN DEL DIAGNOSTICO ==="

    foreach ($linea in $resumen) {

        Add-Reporte $linea
    }


    Add-Reporte " "
    Add-Reporte "=== PROBLEMAS ENCONTRADOS ==="

    if ($problemas.Count -eq 0) {

        Add-Reporte "Ninguno"
    }
    else {

        foreach ($problema in $problemas) {

            Add-Reporte $problema
        }
    }


    Add-Reporte " "
    Add-Reporte "Estado general: $estadoGeneral"


    # ------------------------------------------
    # REGISTRAR EN LOG
    # ------------------------------------------

    if ($estadoGeneral -eq "CRITICO") {

        Write-Log `
            -Mensaje "Resumen generado. Estado general: CRITICO" `
            -Nivel "ERROR"
    }
    elseif ($estadoGeneral -eq "ADVERTENCIA") {

        Write-Log `
            -Mensaje "Resumen generado. Estado general: ADVERTENCIA" `
            -Nivel "WARNING"
    }
    else {

        Write-Log `
            -Mensaje "Resumen generado. Estado general: OK"
    }


    # ------------------------------------------
    # DEVOLVER OBJETO
    # ------------------------------------------

    [PSCustomObject]@{
        EstadoGeneral = $estadoGeneral
        Resumen       = $resumen
        Problemas     = $problemas
    }
}


# ==========================================
# EJECUTAR DIAGNOSTICO
# ==========================================

"=== INFRASTRUCTURE HEALTH CHECK REPORT ===" | Out-File $rutaReporte

Add-Reporte "Fecha: $(Get-Date)"
Add-Reporte "Equipo: $env:COMPUTERNAME"
Add-Reporte "Usuario: $env:USERNAME"

Write-Log -Mensaje "========================================"
Write-Log -Mensaje "Iniciando Infrastructure Health Check Tool"

$sistemaResultado      = Test-Sistema
$ramResultado          = Test-RAM
$discoResultado        = Test-Disco
$redResultado          = Test-Red
$conectividadResultado = Test-Conectividad
$serviciosResultado    = Test-Servicios
$eventosResultado      = Test-EventLogs
$apiResultado          = Test-ApiEndpoints

$resumenResultado = Get-ResumenDiagnostico `
    -RAM $ramResultado `
    -Disco $discoResultado `
    -Conectividad $conectividadResultado `
    -Servicios $serviciosResultado `
    -Eventos $eventosResultado `
    -APIs $apiResultado


# ==========================================
# DATOS ESTRUCTURADOS
# ==========================================

$diagnostico = @{
    Equipo       = $env:COMPUTERNAME
    Usuario      = $env:USERNAME
    Fecha        = Get-Date
    Sistema      = $sistemaResultado
    RAM          = $ramResultado
    Disco        = $discoResultado
    Red          = $redResultado
    APIs         = $apiResultado
    Conectividad = $conectividadResultado
    Servicios    = $serviciosResultado
    Eventos      = $eventosResultado
    Resumen      = $resumenResultado
}

$diagnostico |
    ConvertTo-Json -Depth 6 |
    Out-File $rutaJSON

Write-Log -Mensaje "Diagnostico completado"
Write-Log -Mensaje "Reporte generado: ${rutaReporte}"
Write-Log -Mensaje "JSON generado: ${rutaJSON}"

Write-Host "Health check completado. Estado general: $($resumenResultado.EstadoGeneral)"
Write-Host "Reportes guardados en: $OutputDir"
