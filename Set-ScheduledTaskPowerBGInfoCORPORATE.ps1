$TaskName = "PowerBGInfoGlobal_Refresh"

# 0. La tâche existe-t-elle déjà ?
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($ExistingTask) {
    Write-Host "La tâche '$TaskName' existe déjà : aucune modification (historique préservé)." -ForegroundColor Yellow
    return   
}

# 1. Action - Exécuter le script PowerShell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"C:\ProgramData\PowerBGInfo\Set-WallpaperPowerBGInfoCORPORATE.ps1`""

# 2. Déclencheur : à l'ouverture de session + répétition toutes les minutes, indéfiniment
$TriggerLogon = New-ScheduledTaskTrigger -AtLogOn

$Repetition = New-CimInstance -ClassName MSFT_TaskRepetitionPattern `
    -Namespace Root/Microsoft/Windows/TaskScheduler `
    -Property @{
        Interval = "PT5M"
        Duration = "P1D"
    } -ClientOnly

$TriggerLogon.Repetition = $Repetition

# 3. Paramètres
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

# 4. Contexte utilisateur (groupe "Utilisateurs" via le SID)
$Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited

# 5. Enregistrement la tâche planifiée (pour la créer)
try {
    Register-ScheduledTask -TaskName $TaskName `
        -Description "Actualise le fond d'écran dynamique toutes les 5 minutes" `
        -Action $Action `
        -Trigger $TriggerLogon `
        -Settings $Settings `
        -Principal $Principal `
        -ErrorAction Stop | Out-Null

    Write-Host "Tâche '$TaskName' créée avec succès." -ForegroundColor Green
}
catch {
    Write-Error "Échec de la création de la tâche : $($_.Exception.Message)"
}