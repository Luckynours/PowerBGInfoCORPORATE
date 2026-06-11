# ============================================================
# LOG
# ============================================================
$LogPath = Join-Path $PSScriptRoot "install.log"

Start-Transcript -Path $LogPath -Append

# ============================================================
# CONFIG
# ============================================================
$BaseUrl = "https://raw.githubusercontent.com/Luckynours/PowerBGInfoCORPORATE/main.ps1"

$DataPath = "C:\ProgramData\PowerBGInfo"
$WallpaperPath = "$DataPath\img19-resize.jpg"

# ============================================================
# DOSSIERS
# ============================================================
if (!(Test-Path $DataPath)) {
    New-Item -ItemType Directory -Path $DataPath -Force
}

# ============================================================
# DOWNLOAD
# ============================================================
Invoke-WebRequest "$BaseUrl/Set-WallpaperPowerBGInfoCORPORATE.ps1" -OutFile "$DataPath\Set-WallpaperPowerBGInfoCORPORATE.ps1"
Invoke-WebRequest "$BaseUrl/Set-ScheduledTaskPowerBGInfoCORPORATE.ps1" -OutFile "$DataPath\Set-ScheduledTaskPowerBGInfoCORPORATE.ps1"
Invoke-WebRequest "$BaseUrl/img19-resize.jpg" -OutFile $WallpaperPath

# ============================================================
# CREATE SCHEDULED TASK
# ============================================================
& "$DataPath\Set-ScheduledTaskPowerBGInfoCORPORATE.ps1"

# ============================================================
# FIRST RUN
# ============================================================
& "$DataPath\Set-WallpaperPowerBGInfoCORPORATE.ps1"

Stop-Transcript
