$depth = 0
$classFound = $false
$lines = Get-Content "lib/logic/game_engine.dart"
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Trim().StartsWith("//")) { continue }
    if ($line -match "class GameEngine") { $classFound = $true; Write-Host "Starts at $($i+1)" }
    $chars = $line.ToCharArray()
    foreach ($char in $chars) {
        if ($char -eq '{') { $depth++ }
        elseif ($char -eq '}') { 
            $depth-- 
            if ($classFound -and $depth -eq 0) {
                Write-Host "Closes at $($i+1)"
                Write-Host "Line: $line"
                exit
            }
        }
    }
}