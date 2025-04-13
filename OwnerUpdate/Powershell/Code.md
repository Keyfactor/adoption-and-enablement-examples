# PowerShell Script: Update Keyfactor Command Certificate Owners

## Purpose
This script updates certificate owners in **Keyfactor Command** by:
- Processing a **CSV file** containing serial numbers and roles.
- Sending HTTP requests to update owners via API.
- Using **multithreading (runspaces)** to improve performance.
- Logging results for each operation.

---

## Features
1. **Input Parameters**
   - `csvPath`: Path to the CSV file.
   - `maxThreads`: Number of threads for multithreading.
   - `variableFile`: File containing credentials and necessary variables.

2. **Logging**
   - Logs stored in `RunspaceLogs` folder.
   - Each processed certificate's log is separately recorded.

3. **Multithreading**
   - Runspace pool enables concurrent processing based on the number of threads specified.

4. **Validation**
   - Validates **API credentials** loaded from the variable file.

5. **Execution Time**
   - Stopwatch measures script execution time.

---

## Key Components
### 1. Import CSV
```powershell
$csvData = Import-Csv -Path $csvPath
```

### 2. Setup Logging
```powershell
$logPath = Join-Path -Path $scriptPath -ChildPath "RunspaceLogs"
CreateLogDirectory -logPath $logPath
```

### 3. Load Variable File
```powershell
. .\$variableFile
write-host "Loaded variables from $variableFile"
```

### 4. Create Runspace Pool
```powershell
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
$runspacePool.Open()
```

### 5. Process Each Certificate in CSV
```powershell
foreach ($line in $csvData) 
{
    $runspace = [powershell]::Create().AddScript({
        param ($line, $variables, $logPath)

        # Logic for updating certificate owner
    }).AddArgument($line).AddArgument($Variables).AddArgument($logPath)

    $runspaces += [PSCustomObject]@{
        Pipe      = $runspace
        Status    = $runspace.BeginInvoke()
    }
}
```

### 6. Wait for All Threads to Complete
```powershell
foreach ($run in $runspaces) {
    $run.Pipe.EndInvoke($run.Status)
}
```

### 7. Measure Execution Time
```powershell
$stopwatch.Stop()
Write-Host "Total execution time: $($stopwatch.Elapsed)"
```
---

### **Script Output**
- **Logs**: Created for each certificate in the `RunspaceLogs` directory.
- **Execution Time**: Displayed when the script completes.