# Installer PowerBGInfo si absent
if (-not (Get-Module -ListAvailable -Name PowerBGInfo)) {

    Write-Output "Installation du module PowerBGInfo..."

    Install-PackageProvider -Name NuGet -Force -Scope AllUsers
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module PowerBGInfo -Force -Scope AllUsers
}

Import-Module PowerBGInfo

# ====================================================================
# 1. COLLECTE DYNAMIQUE DES MÉTRIQUES
# ====================================================================

# --- DISQUES (DYNAMIQUE) ---
$DiskTiles = @()
$Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Sort-Object DeviceID

foreach ($Disk in $Disks) {
    if ($Disk.Size -gt 0) {

        $PctFree = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 0)
        $Progress = [math]::Round(($Disk.FreeSpace / $Disk.Size), 2)
        $TotalGB = [math]::Round($Disk.Size / 1GB, 0)

        if ($PctFree -lt 10) { $Color = '#DC2626FF' }
        elseif ($PctFree -lt 25) { $Color = '#F59E0BFF' }
        else { $Color = '#16A34AFF' }

        $DiskTiles += New-BGInfoVisualCanvasTile `
            -Side Right `
            -IconKind Storage `
            -SurfaceStyle Raised `
            -Label "DRIVE $($Disk.DeviceID)" `
            -Value "$PctFree% free" `
            -Detail "$TotalGB GB total" `
            -Progress $Progress `
            -Accent $Color
    }
}

# --- CPU ---
$CpuInstances = Get-CimInstance Win32_Processor
$CpuLoad = [math]::Round(($CpuInstances | Measure-Object LoadPercentage -Average).Average, 0)
$TotalCores = ($CpuInstances | Measure-Object NumberOfLogicalProcessors -Sum).Sum

# --- RAM & OS ---
$OS = Get-CimInstance Win32_OperatingSystem

$PhysicalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure Capacity -Sum).Sum
$TotalRamGB = [math]::Round($PhysicalRAM / 1GB, 0)

$UsedRAM_KB = $OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory
$RamUsedGB = [math]::Round(($UsedRAM_KB * 1024) / 1GB, 1)

# --- OS CLEAN ---
$RawOS = $OS.Caption -replace '^Microsoft\s+', ''
if ($RawOS -match "(.*)\s+(Standard|Datacenter|Professional|Pro|Enterprise|Home|Education|Evaluation)(.*)") {
    $OSName = $matches[1].Trim()
    $OSEdition = $matches[2].Trim()
} else {
    $OSName = $RawOS
    $OSEdition = "Edition inconnue"
}
$OSDetail = "$OSEdition - Build $($OS.BuildNumber)"

# ====================================================================
# DÉTECTION DES RÔLES
# ====================================================================

$Roles = @()

# AD DS
if (Get-Service NTDS -ErrorAction SilentlyContinue) {
    $Roles += "AD"
}

# DNS
if (Get-Service DNS -ErrorAction SilentlyContinue) {
    $Roles += "DNS"
}

# DHCP
if (Get-Service DHCPServer -ErrorAction SilentlyContinue) {
    $Roles += "DHCP"
}

# AD CS
if (Get-Service CertSvc -ErrorAction SilentlyContinue) {
    $Roles += "CS"
}

# IIS
if (Get-Service W3SVC -ErrorAction SilentlyContinue) {
    $Roles += "IIS"
}

# SQL
if (Get-Service -Name "MSSQL*" -ErrorAction SilentlyContinue) {
    $Roles += "SQL"
}

# File Server (clean)
$SmbShares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -notmatch '^(ADMIN\$|IPC\$|C\$|PRINT\$)'
}

if ($SmbShares) {
    $Roles += "FS"
}

# Nettoyage
$Roles = $Roles | Select-Object -Unique

# Defaut
if ($Roles.Count -eq 0) {
    $Roles = @("Generic Server")
}

$RoleValue = ($Roles -join " / ")
$RoleDetail = "Detected roles"


# ====================================================================
# PATCH STATUS
# ====================================================================

$RebootRequired = $false
$UpdatesAvailable = 0

# A. Vérification des redémarrages
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") { $RebootRequired = $true }
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { $RebootRequired = $true }

# B. Vérification des mises à jour en attente
try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $Searcher = $UpdateSession.CreateUpdateSearcher()
    $Searcher.Online = $false
    $Result = $Searcher.Search("IsInstalled=0 and IsHidden=0")
    $UpdatesAvailable = $Result.Updates.Count
} catch {
    $UpdatesAvailable = 0
}

# C. Définir les propriétés de la tuile
if ($RebootRequired) {
    $PatchValue = "KO - Reboot pending"
    $PatchDetail = "Restart required"
    $PatchProgress = 0.0
    $PatchColor = '#DC2626FF'
}
elseif ($UpdatesAvailable -gt 0) {
    $PatchValue = "WARNING - Updates ready"
    $PatchDetail = "$UpdatesAvailable pending install"
    $PatchProgress = 0.5
    $PatchColor = '#F59E0BFF'
}
else {
    $PatchValue = "OK - Compliant"
    $PatchDetail = "Windows is up to date"
    $PatchProgress = 1.0
    $PatchColor = '#16A34AFF'
}

# ====================================================================
# DESIGN & TUILES
# ====================================================================

$palette = @{
    Accent                 = '#49b1d7FF' 
    SecondaryAccent        = '#ffa340FF' 
    TitleColor             = '#F8FAFCFF'
    TitleAccentColor       = '#ffa340FF' 
    SubtitleColor          = '#E2E8F0FF'
    TileLabelColor         = '#475569FF'
    TileValueColor         = '#0F172AFF'
    TileDetailColor        = '#334155FF'
    TileGlassTop           = '#FFF7EDD9'
    TileGlassBottom        = '#DBEAFECC'
    TileProgressTrackColor = '#94A3B8A6'
    HeroBadgeTop           = '#00698eFF' 
    HeroBadgeBottom        = '#49b1d7FF' 
    HeroBadgeTextColor     = '#FFF7EDFF'
}

$tiles = @(
    # --- GAUCHE ---
    New-BGInfoVisualCanvasTile -Side Left -IconKind Computer -SurfaceStyle Raised -Label HOSTNAME -Value '{{HostName}}' -Detail 'Hypervisor' -Accent '#49b1d7FF'
	New-BGInfoVisualCanvasTile -Side Left -IconKind Computer -SurfaceStyle Raised -Label 'SERVER ROLE' -Value $RoleValue -Detail $RoleDetail -Accent '#ffa340FF'
    New-BGInfoVisualCanvasTile -Side Left -IconKind OperatingSystem -SurfaceStyle Raised -Label 'OPERATING SYSTEM' -Value $OSName -Detail $OSDetail -Accent '#00698eFF'
    New-BGInfoVisualCanvasTile -Side Left -IconKind Network -SurfaceStyle Raised -Label 'IP ADDRESS' -Value '{{IPv4Address}}' -Detail 'Management IP Address' -Accent '#49b1d7FF'
    New-BGInfoVisualCanvasTile -Side Left -IconKind User -SurfaceStyle Raised -Label 'LOGGED USER' -Value '{{UserName}}' -Detail 'Active Session' -Accent '#16A34AFF'

    # --- DROITE ---
    New-BGInfoVisualCanvasTile -Side Right -IconKind Cpu -SurfaceStyle Raised -Label 'CPU LOAD' -Value "$CpuLoad% active" -Detail "$TotalCores logical cores" -Accent '#49b1d7FF'
    New-BGInfoVisualCanvasTile -Side Right -IconKind Memory -SurfaceStyle Raised -Label 'MEMORY USE' -Value "$RamUsedGB GB used" -Detail "$TotalRamGB GB installed" -Accent '#49b1d7FF'
) + $DiskTiles + @(
    New-BGInfoVisualCanvasTile -Side Right -IconKind Shield -SurfaceStyle Raised -Label 'PATCH STATUS' -Value $PatchValue -Detail $PatchDetail -Progress $PatchProgress -Accent $PatchColor
)

# ====================================================================
# GÉNÉRATION
# ====================================================================

New-BGInfo -MonitorIndex 0 {

    New-BGInfoVisualCanvas `
        -Title 'CORPORATE' `
        -Subtitle 'corpo.up-alios.fr' `
        -FeatureAnchor BottomRight `
        -FeatureWidth 180 `
        -FeatureOffsetX 60 `
        -FeatureOffsetY 60 `
        -Tile $tiles @palette

} -FilePath "C:\Windows\Web\Wallpaper\Windows\img19-resize.jpg" `
  -WallpaperFit Fill `
  -ConfigurationDirectory "C:\ProgramData\PowerBGInfo"
