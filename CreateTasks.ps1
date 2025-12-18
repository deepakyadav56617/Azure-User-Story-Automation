$orgUrl = "https://dev.azure.com/deepak-devops"
$project = "User Story Automation"
$pat = "PAT_TOKEN"  

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Azure DevOps Task Creator (Idempotent)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$userStoryId = Read-Host "Enter the User Story ID (just the number, e.g., 5)"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    "Content-Type" = "application/json-patch+json"
}

$headersGet = @{
    Authorization = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

$taskTitles = @(
    "Requirements & Grooming",
    "Design & Approach",
    "Implementation",
    "Test & Validation",
    "Documentation & Handover"
)

Write-Host "Fetching User Story #$userStoryId details..." -ForegroundColor Yellow
Write-Host ""

try {
    $userStoryUrl = "$orgUrl/$project/_apis/wit/workitems/${userStoryId}?`$expand=relations&api-version=7.1"
    $userStory = Invoke-RestMethod -Uri $userStoryUrl -Headers $headersGet -Method Get
    
    $areaPath = $userStory.fields.'System.AreaPath'
    $iterationPath = $userStory.fields.'System.IterationPath'
    $storyTitle = $userStory.fields.'System.Title'
    
    Write-Host "SUCCESS: User Story found!" -ForegroundColor Green
    Write-Host "  Title: $storyTitle" -ForegroundColor White
    Write-Host "  Area Path: $areaPath" -ForegroundColor Cyan
    Write-Host "  Iteration Path: $iterationPath" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "ERROR: Could not find User Story #$userStoryId" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  1. User Story does not exist" -ForegroundColor White
    Write-Host "  2. Wrong User Story ID" -ForegroundColor White
    Write-Host "  3. PAT token does not have correct permissions" -ForegroundColor White
    Write-Host "  4. Organization or Project name is incorrect" -ForegroundColor White
    Write-Host ""
    Write-Host "Error details: $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "=====================================" -ForegroundColor Yellow
Write-Host "IDEMPOTENCY CHECK" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
Write-Host "Checking for existing child tasks..." -ForegroundColor Yellow
Write-Host ""

$existingTasks = @()
$idempotencyCheckPassed = $false

try {
    if ($userStory.relations) {
        Write-Host "Analyzing User Story relationships..." -ForegroundColor Cyan
        
        $childRelations = $userStory.relations | Where-Object { 
            $_.rel -eq "System.LinkTypes.Hierarchy-Forward" 
        }
        
        if ($childRelations) {
            Write-Host "Found $($childRelations.Count) child relationship(s)" -ForegroundColor Cyan
            Write-Host ""
            
            foreach ($relation in $childRelations) {
                $childId = $relation.url -replace '.*/', ''
                
                try {
                    $childUrl = "$orgUrl/$project/_apis/wit/workitems/${childId}?api-version=7.1"
                    $childItem = Invoke-RestMethod -Uri $childUrl -Headers $headersGet -Method Get
                    
                    $childType = $childItem.fields.'System.WorkItemType'
                    $childTitle = $childItem.fields.'System.Title'
                    
                    if ($childType -eq "Task") {
                        $existingTasks += @{
                            id = $childItem.id
                            title = $childTitle.Trim()
                        }
                        Write-Host "  Found Task #${childId}: $childTitle" -ForegroundColor Gray
                    }
                }
                catch {
                    Write-Host "  Warning: Could not fetch child #${childId}" -ForegroundColor Yellow
                }
            }
            
            Write-Host ""
        }
    }

    if ($existingTasks.Count -eq 0) {
        Write-Host "Trying alternative method (WIQL query)..." -ForegroundColor Cyan
        
        $queryBody = @{
            query = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.Parent] = $userStoryId AND [System.WorkItemType] = 'Task'"
        } | ConvertTo-Json

        $queryUrl = "$orgUrl/$project/_apis/wit/wiql?api-version=7.1"
        $queryResult = Invoke-RestMethod -Uri $queryUrl -Headers $headers -Method Post -Body $queryBody

        if ($queryResult.workItems -and $queryResult.workItems.Count -gt 0) {
            Write-Host "Found $($queryResult.workItems.Count) task(s) via query" -ForegroundColor Cyan
            Write-Host ""
            
            foreach ($workItem in $queryResult.workItems) {
                $taskUrl = "$orgUrl/$project/_apis/wit/workitems/$($workItem.id)?api-version=7.1"
                $task = Invoke-RestMethod -Uri $taskUrl -Headers $headersGet -Method Get
                
                $existingTasks += @{
                    id = $task.id
                    title = $task.fields.'System.Title'.Trim()
                }
                Write-Host "  Found Task #$($task.id): $($task.fields.'System.Title')" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
    
    if ($existingTasks.Count -eq 0) {
        Write-Host "No existing child tasks found." -ForegroundColor Cyan
        Write-Host "Will create all 5 tasks." -ForegroundColor Cyan
        Write-Host ""
    }
    else {
        Write-Host "Total existing Task children: $($existingTasks.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        $existingTitles = $existingTasks | ForEach-Object { $_.title }
        
        $missingTasks = @()
        foreach ($requiredTitle in $taskTitles) {
            $found = $false
            foreach ($existingTitle in $existingTitles) {
                if ($existingTitle.Trim().ToLower() -eq $requiredTitle.Trim().ToLower()) {
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                $missingTasks += $requiredTitle
            }
        }
        
        if ($missingTasks.Count -eq 0) {
            Write-Host "=====================================" -ForegroundColor Green
            Write-Host "✅ IDEMPOTENCY: All 5 tasks already exist!" -ForegroundColor Green
            Write-Host "=====================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "No new tasks will be created." -ForegroundColor Green
            Write-Host "This prevents duplicate task creation." -ForegroundColor Green
            Write-Host ""
            Write-Host "Existing tasks:" -ForegroundColor White
            foreach ($task in $existingTasks) {
                Write-Host "  ✓ Task #$($task.id): $($task.title)" -ForegroundColor Green
            }
            Write-Host ""
            Write-Host "View the User Story in Azure DevOps:" -ForegroundColor Green
            Write-Host "$orgUrl/$project/_workitems/edit/$userStoryId" -ForegroundColor Cyan
            Write-Host ""
            Read-Host "Press Enter to exit"
            exit
        }
        else {
            Write-Host "Missing tasks detected:" -ForegroundColor Yellow
            foreach ($missing in $missingTasks) {
                Write-Host "  - $missing" -ForegroundColor Yellow
            }
            Write-Host ""
            Write-Host "Will create only the missing tasks..." -ForegroundColor Yellow
            Write-Host ""
            $taskTitles = $missingTasks
        }
    }
}
catch {
    Write-Host "Warning: Could not check existing tasks reliably" -ForegroundColor Yellow
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Proceeding with caution..." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "=====================================" -ForegroundColor Yellow
Write-Host "Creating child tasks..." -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$taskIds = @()

foreach ($title in $taskTitles) {
    Write-Host "Creating: $title" -ForegroundColor Cyan
    
    $body = @(
        @{
            op = "add"
            path = "/fields/System.Title"
            value = $title
        },
        @{
            op = "add"
            path = "/fields/System.WorkItemType"
            value = "Task"
        },
        @{
            op = "add"
            path = "/fields/System.AreaPath"
            value = $areaPath
        },
        @{
            op = "add"
            path = "/fields/System.IterationPath"
            value = $iterationPath
        },
        @{
            op = "add"
            path = "/relations/-"
            value = @{
                rel = "System.LinkTypes.Hierarchy-Reverse"
                url = "$orgUrl/$project/_apis/wit/workitems/$userStoryId"
            }
        }
    ) | ConvertTo-Json -Depth 10
    
    $createUrl = "$orgUrl/$project/_apis/wit/workitems/`$Task?api-version=7.1"
    
    try {
        $result = Invoke-RestMethod -Uri $createUrl -Headers $headers -Method Post -Body $body
        Write-Host "  ✅ SUCCESS (ID: $($result.id))" -ForegroundColor Green
        $successCount++
        $taskIds += $result.id
        Start-Sleep -Milliseconds 200
    }
    catch {
        Write-Host "  ❌ ERROR: Failed to create task" -ForegroundColor Red
        Write-Host "     Details: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

if ($successCount -eq $taskTitles.Count) {
    Write-Host "SUCCESS: Created $successCount task(s)!" -ForegroundColor Green
    Write-Host ""
    if ($taskIds.Count -gt 0) {
        Write-Host "Newly created Task IDs: $($taskIds -join ', ')" -ForegroundColor White
    }
} else {
    Write-Host "WARNING: Created $successCount out of $($taskTitles.Count) required tasks" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "View the User Story in Azure DevOps:" -ForegroundColor Green
Write-Host "$orgUrl/$project/_workitems/edit/$userStoryId" -ForegroundColor Cyan
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "IDEMPOTENCY: Safe to run multiple times" -ForegroundColor Cyan
Write-Host "No duplicates will be created" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to exit"