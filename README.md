# Azure DevOps - Automatic Task Creation for User Stories

## 📋 Problem Statement

**Objective:** When a new User Story is created in Azure DevOps, automatically create five Tasks and link them as child work items under that story.

**Requirements:**
- Create exactly **5 child Tasks** with the following titles:
  1. Requirements & Grooming
  2. Design & Approach
  3. Implementation
  4. Test & Validation
  5. Documentation & Handover
- Each Task should be properly linked as a **child** of the User Story
- Tasks should inherit relevant metadata such as **Area Path** and **Iteration Path**
- The process should be **idempotent** — no duplicate Tasks if retried or triggered multiple times
- All corner/edge cases in architecture and coding should be handled properly

---

## 🚀 Solution Overview

This repository provides **two approaches** to solve the problem:

### **Approach 1: PowerShell Script** (Manual Trigger)
A standalone PowerShell script that creates tasks on-demand using Azure DevOps REST API.

### **Approach 2: Azure Pipeline** (CI/CD Integration)
A YAML pipeline that can be triggered manually or integrated into your workflow.

Both approaches implement **idempotency** to prevent duplicate task creation.

---

## 📁 Repository Structure

```
azure-devops-task-automation/
│
├── CreateTasks.ps1           # PowerShell script (Approach 1)
├── azure-pipelines.yml       # Azure Pipeline YAML (Approach 2)
├── README.md                 # This file
└── .gitignore               # Excludes sensitive data
```

---

## ⚙️ Prerequisites

1. **Azure DevOps Account**
   - Organization and Project created
   - Project using "Agile" process template

2. **Personal Access Token (PAT)**
   - Go to Azure DevOps → User Settings → Personal Access Tokens
   - Click "New Token"
   - Scopes required: **Work Items (Read, write, & manage)**
   - Copy and save the token securely

3. **PowerShell** (for Approach 1)
   - Windows PowerShell 5.1+ or PowerShell Core 7+

4. **Azure Pipeline** (for Approach 2)
   - Access to create and run pipelines in your project

---

## 🔧 Approach 1: PowerShell Script

### Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd azure-devops-task-automation
   ```

2. **Configure the script:**
   
   Open `CreateTasks.ps1` and update these variables:
   ```powershell
   $orgUrl = "https://dev.azure.com/YOUR_ORG_NAME"
   $project = "YOUR_PROJECT_NAME"
   $pat = "YOUR_PERSONAL_ACCESS_TOKEN"
   ```

### Usage

1. **Open PowerShell**

2. **Navigate to the script directory:**
   ```powershell
   cd path\to\azure-devops-task-automation
   ```

3. **Run the script:**
   ```powershell
   .\CreateTasks.ps1
   ```

4. **Enter the User Story ID when prompted:**
   ```
   Enter the User Story ID (just the number, e.g., 5): 23
   ```

### Expected Output

```
=====================================
Azure DevOps Task Creator (Idempotent)
=====================================

Fetching User Story #23 details...
✅ SUCCESS: User Story found!
  Title: Implement User Login
  Area Path: MyProject
  Iteration Path: MyProject\Sprint 1

=====================================
IDEMPOTENCY CHECK
=====================================
Checking for existing child tasks...
✓ No existing child tasks found.
  Will create all 5 tasks.

=====================================
Creating child tasks...
=====================================
Creating: Requirements & Grooming
  ✅ SUCCESS - Created Task #24
Creating: Design & Approach
  ✅ SUCCESS - Created Task #25
Creating: Implementation
  ✅ SUCCESS - Created Task #26
Creating: Test & Validation
  ✅ SUCCESS - Created Task #27
Creating: Documentation & Handover
  ✅ SUCCESS - Created Task #28

=====================================
SUMMARY
=====================================
✅ SUCCESS: Created all 5 task(s)!

Newly created Task IDs:
  - Task #24
  - Task #25
  - Task #26
  - Task #27
  - Task #28

View the User Story in Azure DevOps:
https://dev.azure.com/your-org/your-project/_workitems/edit/23
```

---

## 🔄 Approach 2: Azure Pipeline

### Setup

1. **Create a new pipeline in Azure DevOps:**
   - Go to **Pipelines** → **New Pipeline**
   - Select **Azure Repos Git**
   - Select your repository
   - Choose **Existing Azure Pipelines YAML file**
   - Select `/azure-pipelines.yml`

2. **Configure pipeline variables:**
   
   Update these variables in `azure-pipelines.yml`:
   ```yaml
   variables:
     organizationUrl: 'https://dev.azure.com/YOUR_ORG_NAME'
     projectName: 'YOUR_PROJECT_NAME'
   ```

3. **Add PAT token as pipeline variable:**
   - In the pipeline editor, click **Variables**
   - Click **+ New variable**
   - Name: `AZURE_DEVOPS_PAT`
   - Value: Your PAT token
   - ✅ Check **"Keep this value secret"**
   - Click **OK** and **Save**

### Usage

1. **Run the pipeline:**
   - Go to **Pipelines** → Select your pipeline
   - Click **Run pipeline**

2. **Enter the User Story ID:**
   - In the parameters, enter the User Story ID
   - Click **Run**

3. **Monitor execution:**
   - View the pipeline logs to see task creation progress

### Expected Pipeline Output

```
=====================================
Azure DevOps Task Creator Pipeline
=====================================
Organization: https://dev.azure.com/your-org
Project: Your Project Name
User Story ID: 23

Fetching User Story #23 details...
✅ User Story found!
   Title: Implement User Login
   Area Path: MyProject
   Iteration Path: MyProject\Sprint 1

=====================================
IDEMPOTENCY CHECK
=====================================
Checking for existing child tasks...
No existing child tasks found.
Will create all 5 tasks.

Creating child tasks...
   ✅ Created: Requirements & Grooming (ID: 24)
   ✅ Created: Design & Approach (ID: 25)
   ✅ Created: Implementation (ID: 26)
   ✅ Created: Test & Validation (ID: 27)
   ✅ Created: Documentation & Handover (ID: 28)

=====================================
SUMMARY
=====================================
✅ SUCCESS: All 5 tasks created!

Created Task IDs: 24, 25, 26, 27, 28
```

---

## 🔄 Idempotency Implementation

### How It Works

Both approaches implement idempotency to prevent duplicate task creation:

1. **Query Existing Tasks**
   - Before creating tasks, the script queries Azure DevOps for existing child tasks
   - Uses two methods:
     - **Primary:** Checks User Story's `relations` property
     - **Fallback:** WIQL query to find tasks by parent ID

2. **Compare Existing vs Required**
   - Compares existing task titles with the 5 required task titles
   - Identifies which tasks are missing (case-insensitive comparison)

3. **Smart Task Creation**
   - **All 5 tasks exist:** Exits without creating duplicates
   - **Some tasks missing:** Creates only the missing ones
   - **No tasks exist:** Creates all 5 tasks

### Idempotency Test Scenarios

#### Scenario 1: First Run (No Tasks Exist)
```bash
Run 1: User Story #23 has 0 tasks
Result: Creates 5 tasks (IDs: 24, 25, 26, 27, 28)
```

#### Scenario 2: Second Run (All Tasks Exist)
```bash
Run 2: User Story #23 has 5 tasks
Result: "✅ ALL 5 TASKS ALREADY EXIST! No new tasks will be created."
Exit Code: 0 (Success)
Tasks Created: 0
```

#### Scenario 3: Partial Tasks (Recovery)
```bash
Existing: 3 tasks (Requirements, Design, Implementation)
Missing: 2 tasks (Test & Validation, Documentation)
Result: Creates only 2 missing tasks
```

### Technical Implementation

**PowerShell/Pipeline Query:**
```powershell
# Check User Story relations
$childRelations = $userStory.relations | Where-Object { 
    $_.rel -eq "System.LinkTypes.Hierarchy-Forward" 
}

# Fallback: WIQL Query
$query = "SELECT [System.Id], [System.Title] 
          FROM WorkItems 
          WHERE [System.Parent] = $userStoryId 
          AND [System.WorkItemType] = 'Task'"
```

**Comparison Logic:**
```powershell
# Case-insensitive title comparison
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
```

---

## 🧪 Testing & Verification

### Manual Testing Steps

1. **Create a User Story in Azure DevOps:**
   - Go to **Boards** → **Work Items**
   - Click **+ New Work Item** → **User Story**
   - Title: "Test Automation"
   - Click **Save & Close**
   - Note the User Story ID (e.g., #23)

2. **Run the script/pipeline** with the User Story ID

3. **Verify in Azure DevOps:**
   - Open the User Story
   - Check **Related Work** or **Child** section
   - Should see 5 tasks linked as children

4. **Test Idempotency:**
   - Run the script/pipeline again with the same User Story ID
   - Should output: "ALL 5 TASKS ALREADY EXIST"
   - Verify no duplicate tasks were created

### Verification Checklist

- ✅ All 5 tasks created with correct titles
- ✅ Tasks are linked as children to the User Story
- ✅ Tasks inherit Area Path from parent
- ✅ Tasks inherit Iteration Path from parent
- ✅ Running twice doesn't create duplicates
- ✅ Deleting 2 tasks and re-running creates only missing 2

---

## 🔐 Security Best Practices

### PAT Token Security

**⚠️ NEVER commit PAT tokens to Git!**

1. **Use placeholders in code:**
   ```powershell
   $pat = "YOUR_PERSONAL_ACCESS_TOKEN"  # Replace before running
   ```

2. **Add to `.gitignore`:**
   ```
   # Sensitive files
   config.ps1
   *token*
   .env
   ```

3. **Use Azure Pipeline Variables:**
   - Store PAT as a secret pipeline variable
   - Never hardcode in YAML

4. **Rotate tokens regularly:**
   - Set expiration dates (30-90 days)
   - Revoke old tokens when creating new ones

5. **Use minimum required scopes:**
   - Only grant "Work Items (Read, write, & manage)"
   - Don't use full access tokens

### If PAT Token is Compromised

1. **Immediately revoke** in Azure DevOps
2. **Create a new token** with same permissions
3. **Update all scripts/pipelines** with new token
4. **Review access logs** for suspicious activity

---

## 🛠️ Troubleshooting

### Issue: "PAT token does not have correct permissions"

**Solution:**
- Go to Azure DevOps → Personal Access Tokens
- Edit your token
- Ensure **Work Items (Read, write, & manage)** is checked
- Save and regenerate token if needed

### Issue: "User Story not found"

**Solution:**
- Verify the User Story ID is correct
- Check you're using the right project name
- Ensure the work item hasn't been deleted

### Issue: Pipeline shows "No hosted parallelism"

**Solution:**
- Request free parallelism: https://aka.ms/azpipelines-parallelism-request
- OR use the PowerShell script approach instead

### Issue: Tasks created but not linked to User Story

**Solution:**
- Check the relation URL in the script:
  ```powershell
  url = "$orgUrl/$project/_apis/wit/workitems/$userStoryId"
  ```
- Verify project name doesn't need URL encoding

### Issue: Empty task IDs or failed creation

**Solution:**
- Check PAT has Write permissions (not just Read)
- Verify Content-Type header: `application/json-patch+json`
- Ensure Area Path and Iteration Path are valid


---

## 📚 API Reference

### Azure DevOps REST API Endpoints Used

#### Get Work Item with Relations
```http
GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?$expand=relations&api-version=7.1
```

#### Create Work Item (Task)
```http
POST https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/$Task?api-version=7.1
Content-Type: application/json-patch+json

[
  {
    "op": "add",
    "path": "/fields/System.Title",
    "value": "Task Title"
  },
  {
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "System.LinkTypes.Hierarchy-Reverse",
      "url": "https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{parentId}"
    }
  }
]
```

#### WIQL Query (Find Child Tasks)
```http
POST https://dev.azure.com/{organization}/{project}/_apis/wit/wiql?api-version=7.1
Content-Type: application/json

{
  "query": "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.Parent] = {parentId} AND [System.WorkItemType] = 'Task'"
}
```

### Authentication

Both approaches use **Basic Authentication** with PAT:
```
Authorization: Basic {base64(":PAT_TOKEN")}
```
