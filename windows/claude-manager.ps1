# Claude Manager for Windows
# A system tray app to manage Claude CLI instances
# Run with: powershell -ExecutionPolicy Bypass -File claude-manager.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global variables
$script:instances = @()
$script:claudeDir = "$env:USERPROFILE\.claude\projects"

# Function to get Claude instances
function Get-ClaudeInstances {
    $instances = @()

    # Get all node processes that are running claude
    $procs = Get-Process -Name "node", "claude" -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowTitle -match "claude" -or $_.ProcessName -eq "claude"
    }

    # Also check for claude.exe directly
    $claudeProcs = Get-Process -Name "claude" -ErrorAction SilentlyContinue

    $allProcs = @($procs) + @($claudeProcs) | Sort-Object -Unique -Property Id

    foreach ($proc in $allProcs) {
        if ($null -eq $proc) { continue }

        $elapsed = (Get-Date) - $proc.StartTime
        $elapsedStr = "{0:d2}:{1:d2}:{2:d2}" -f $elapsed.Hours, $elapsed.Minutes, $elapsed.Seconds
        if ($elapsed.Days -gt 0) {
            $elapsedStr = "$($elapsed.Days)-$elapsedStr"
        }

        # Try to determine type
        $type = "terminal"
        try {
            $parent = Get-Process -Id $proc.Parent.Id -ErrorAction SilentlyContinue
            if ($parent.ProcessName -match "happy") {
                $type = "happy"
            } elseif ($parent.ProcessName -eq "node") {
                $type = "node"
            }
        } catch {}

        # Try to find session info
        $folder = $null
        $prompt = $null

        $recentFiles = Get-ChildItem -Path $script:claudeDir -Filter "*.jsonl" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10

        foreach ($file in $recentFiles) {
            $diff = [math]::Abs(($file.LastWriteTime - $proc.StartTime).TotalSeconds)
            if ($diff -lt 600) {
                $folder = $file.DirectoryName -replace [regex]::Escape($script:claudeDir), "" -replace "-", "/"

                # Try to get first prompt
                $firstLine = Get-Content $file.FullName -TotalCount 100 | Where-Object { $_ -match '"type":"user"' } | Select-Object -First 1
                if ($firstLine) {
                    try {
                        $json = $firstLine | ConvertFrom-Json
                        $prompt = $json.message.content.Substring(0, [math]::Min(50, $json.message.content.Length))
                        $prompt = $prompt -replace "`n", " "
                    } catch {}
                }
                break
            }
        }

        $instances += [PSCustomObject]@{
            PID = $proc.Id
            StartTime = $proc.StartTime
            Elapsed = $elapsedStr
            Type = $type
            Folder = $folder
            Prompt = $prompt
            Process = $proc
        }
    }

    return $instances
}

# Function to create the context menu
function Update-ContextMenu {
    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    # Header
    $header = New-Object System.Windows.Forms.ToolStripMenuItem
    $header.Text = "Claude Manager"
    $header.Enabled = $false
    $menu.Items.Add($header)
    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    # Get instances
    $script:instances = Get-ClaudeInstances

    if ($script:instances.Count -eq 0) {
        $noInstances = New-Object System.Windows.Forms.ToolStripMenuItem
        $noInstances.Text = "No Claude instances running"
        $noInstances.Enabled = $false
        $menu.Items.Add($noInstances)
    } else {
        foreach ($inst in $script:instances) {
            $item = New-Object System.Windows.Forms.ToolStripMenuItem
            $item.Text = "[$($inst.Type)] PID $($inst.PID) - $($inst.Elapsed)"

            # Submenu for each instance
            $subMenu = New-Object System.Windows.Forms.ToolStripMenuItem

            if ($inst.Folder) {
                $folderItem = New-Object System.Windows.Forms.ToolStripMenuItem
                $folderItem.Text = "Folder: $($inst.Folder)"
                $folderItem.Enabled = $false
                $item.DropDownItems.Add($folderItem)
            }

            if ($inst.Prompt) {
                $promptItem = New-Object System.Windows.Forms.ToolStripMenuItem
                $promptItem.Text = "Prompt: `"$($inst.Prompt)`""
                $promptItem.Enabled = $false
                $item.DropDownItems.Add($promptItem)
            }

            $item.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))

            # Kill option
            $killItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $killItem.Text = "Stop (SIGTERM)"
            $pid = $inst.PID
            $killItem.Add_Click({
                Stop-Process -Id $pid -ErrorAction SilentlyContinue
            }.GetNewClosure())
            $item.DropDownItems.Add($killItem)

            # Force kill option
            $forceKillItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $forceKillItem.Text = "Force Stop (SIGKILL)"
            $forceKillItem.Add_Click({
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            }.GetNewClosure())
            $item.DropDownItems.Add($forceKillItem)

            $menu.Items.Add($item)
        }

        $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

        # Kill all option
        $killAllItem = New-Object System.Windows.Forms.ToolStripMenuItem
        $killAllItem.Text = "Kill All ($($script:instances.Count))"
        $killAllItem.Add_Click({
            foreach ($inst in $script:instances) {
                Stop-Process -Id $inst.PID -ErrorAction SilentlyContinue
            }
        })
        $menu.Items.Add($killAllItem)
    }

    $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    # Refresh option
    $refreshItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $refreshItem.Text = "Refresh"
    $refreshItem.Add_Click({ Update-ContextMenu })
    $menu.Items.Add($refreshItem)

    # Exit option
    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = "Exit"
    $exitItem.Add_Click({
        $script:notifyIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    })
    $menu.Items.Add($exitItem)

    $script:notifyIcon.ContextMenuStrip = $menu
}

# Create the notify icon
$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:notifyIcon.Text = "Claude Manager"
$script:notifyIcon.Visible = $true

# Initial menu setup
Update-ContextMenu

# Handle click events
$script:notifyIcon.Add_Click({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Update-ContextMenu
    }
})

# Refresh every 30 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000
$timer.Add_Tick({ Update-ContextMenu })
$timer.Start()

# Run the application
[System.Windows.Forms.Application]::Run()
