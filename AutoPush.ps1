$folder = "C:\Users\HARRISH C\OneDrive\Documents\Antigravity projects\New Jenkins pipeline\jenkins_testing"
$remoteUrl = "https://github.com/HarrishC/jenkins_testing.git"

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $folder
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

Write-Host "Watching for file savings in $folder..." -ForegroundColor Cyan
Write-Host "Target repository: $remoteUrl" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop watching." -ForegroundColor Yellow

while ($true) {
    # Wait for changes (times out after 1 second so the loop isn't infinitely blocked)
    $result = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)
    
    if ($result.TimedOut) { 
        continue 
    }
    
    $path = $result.Name
    
    # Ignore changes inside the .git folder to prevent infinite git loops
    if ($path -match "^\.git[/\\]?") {
        continue
    }

    Write-Host "Detected $($result.ChangeType) on $path" -ForegroundColor Green
    
    # Debounce: Wait for 2 seconds to ensure the file finishes saving
    Start-Sleep -Seconds 2
    
    # Flush any other rapid events from the queue for 200ms
    while ($true) {
        $flush = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 200)
        if ($flush.TimedOut) { break }
    }

    # Execute git commands
    Push-Location $folder
    try {
        $gitStatus = git status --porcelain
        if ($gitStatus) {
            Write-Host "Changes detected by git. Committing and pushing..." -ForegroundColor Yellow
            
            # Use git add . to stage changes
            git add .
            
            # Get just the file name/path for the commit message
            $message = "Auto-commit after save: $($result.ChangeType) on $path"
            git commit -m $message
            
            # Push to the remote url
            # Pushing to HEAD means the current branch to the same remote branch
            git push $remoteUrl HEAD
            
            Write-Host "Successfully pushed changes to $remoteUrl" -ForegroundColor Green
        } else {
            Write-Host "No trackable changes detected by git." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "Error occurred during git operations: $_" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}
