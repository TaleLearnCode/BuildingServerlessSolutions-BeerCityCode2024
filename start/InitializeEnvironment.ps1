param (
    [string]$TargetPath,
    [string]$GitHubToken,
    [string]$APIMPublisherEmail,
    [string]$APIMPublisherName = "Cool Revive Technologies",
    [string]$GitHubRepoName = "cool-revive",
    [string]$AzureRegion = "eastus2"
)

function Write-SectionHeader {
    param (
        [string]$Message
    )

    Write-Host ""
    Write-Host ""
    Write-Host ""
    $Host.UI.RawUI.ForegroundColor = "Cyan"
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host $Message
    Write-Host "-------------------------------------------------------------------------------"
    $Host.UI.RawUI.ForegroundColor = $originalForegroundColor
}

function Write-Command {
    param (
        [string]$CommandText
    )
    #$Host.UI.RawUI.ForegroundColor = "White"
    #$Host.UI.RawUI.BackgroundColor = "Green"
    $Host.UI.RawUI.ForegroundColor = "DarkGray"
    Write-Output $CommandText
    $Host.UI.RawUI.ForegroundColor = $originalForegroundColor
    $Host.UI.RawUI.BackgroundColor = $originalBackgroundColor
    Write-Output ""
}

# Get the console colors
$originalForegroundColor = $Host.UI.RawUI.ForegroundColor
$originalBackgroundColor = $Host.UI.RawUI.BackgroundColor


# Get the current directory
$originalPath = Get-Location

# Prompt for missing input parameters
if (-not $TargetPath) {
    $TargetPath = Read-Host "Target Path"
}
if (-not $GitHubToken) {
    $GitHubToken = Read-Host "Github Token:"
}
if (-not $APIMPublisherEmail) {
    $APIMPublisherEmail = Read-Host "Your Email Address:"
  }

# Delete the target directory if it exists
if (Test-Path -Path $TargetPath) {
    Remove-Item -Path $TargetPath -Recurse -Force
}

# Create the target directory
New-Item -Path $TargetPath -ItemType Directory

# Get the current script's folder
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path

# #############################################################################
# Generate a random suffix for Azure resources
# #############################################################################

$randomNumber = Get-Random -Minimum 1 -Maximum 1000
$RandomNameSuffix = $randomNumber.ToString("D3")

# #############################################################################
# Build local repository
# #############################################################################

Write-SectionHeader -Message "Building the local repository..."

# Build the local repository directory structure
$folderStructure = @(
    "infra",
    "infra\github",
    "infra\remote-state",
    "infra\service-principal",
    "infra\solution",
    "src"
    "src\core",
    "src\getnextcore",
    "src\getnextcorehandler",
    "src\inventorymanager"
)
foreach ($folder in $folderStructure) {
    $fullPath = Join-Path -Path $TargetPath -ChildPath $folder
    if (-not (Test-Path -Path $fullPath)) {
        New-Item -Path $fullPath -ItemType Directory
    }
}

# Construct the source folder path (assuming the "repo" folder is in the same directory as the script)
$SourceFolder = Join-Path -Path $ScriptFolder -ChildPath "repo"

# Copy all files from the source folder to the target folder (including subfolders)
Get-ChildItem -Path $SourceFolder -File -Recurse | ForEach-Object {
    $RelativePath = $_.FullName.Replace($SourceFolder, "")
    $DestinationPath = Join-Path -Path $TargetPath -ChildPath $RelativePath.TrimStart("\")
    Copy-Item -Path $_.FullName -Destination $DestinationPath -Force
}

# #############################################################################
# Create the GitHub repository
# #############################################################################

Write-SectionHeader -Message "Creating the GitHub repository..."

# Create the github.tfconfig file
$destinationPath = Join-Path -Path $TargetPath -ChildPath "infra\github"
$tfconfigPath = Join-Path -Path $destinationPath -ChildPath "github.tfconfig"
"gitHub_token = $GitHubToken" | Out-File -FilePath $tfconfigPath -Force

# Execute Terraform commands
Set-Location -Path $destinationPath
$commands = @(
    "terraform init",
    "terraform validate",
    "terraform apply -var=`"github_token=$GitHubToken`" -var=`"github_repository_name=$GitHubRepoName`" -auto-approve"
)
foreach ($command in $commands) {
    Write-Command -CommandText $command
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# Capture the output of the terraform apply command
$terraformOutput = & terraform output -json
$GitHubRepositoryUrl = ($terraformOutput | ConvertFrom-Json).github_repository_url.value
$GitHubRepositoryFullName = ($terraformOutput | ConvertFrom-Json).github_repository_full_name.value

# #############################################################################
# Initialize the Terraform remote state
# #############################################################################

Write-SectionHeader -Message "Initializing the Terraform remote state..."

# Execute Terraform commands
$destinationPath = Join-Path -Path $TargetPath -ChildPath "infra\remote-state"
Set-Location -Path $destinationPath
$commands = @(
    "terraform init",
    "terraform validate",
    "terraform apply -var=`"azure_environment=dev`" -var=`"azure_region=$AzureRegion`" -var=`"resource_name_suffix=$RandomNameSuffix`" -auto-approve"
)
foreach ($command in $commands) {
    Write-Command -CommandText $command
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# Migrate state to the remote state
$filePath = Join-Path -Path $destinationPath -ChildPath "backend.tf"
$fileContent = @'
terraform {
  backend "azurerm" {
  }
}
'@
Set-Content -Path $filePath -Value $fileContent

# Execute the Terraform init command to migrate the state
$CommandToExecute = "terraform init --backend-config=dev.tfconfig -migrate-state -force-copy"
Write-Command -CommandText $CommandToExecute
$process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $CommandToExecute" -NoNewWindow -PassThru -Wait
if ($process.ExitCode -ne 0) {
    Write-Error "Command '$CommandToExecute' failed with exit code $($process.ExitCode)."
    exit 1
}

# #############################################################################
# Create the Azure Service Principal
# #############################################################################

Write-SectionHeader -Message "Creating the Azure Service Principal..."

$destinationPath = Join-Path -Path $TargetPath -ChildPath "infra\service-principal"

# Copy the dev.tfconfig file from the remote state folder to the GitHub folder
$sourcePath = Join-Path -Path $TargetPath -ChildPath "infra\remote-state"
Copy-Item -Path $sourcePath\dev.tfconfig -Destination $destinationPath -Recurse -Force

Set-Location -Path $destinationPath

# Update the key in the dev.tfconfig file
$filePath = Join-Path -Path $destinationPath -ChildPath "dev.tfconfig"
$fileContent = Get-Content -Path $filePath
$fileContent = $fileContent -replace 'key = "iac.tfstate"', 'key = "service-principal.tfstate"'
Set-Content -Path $filePath -Value $fileContent

# Execute Terraform commands
$commands = @(
    "terraform init --backend-config=dev.tfconfig",
    "terraform validate",
    "terraform apply -var=`"azure_environment=dev`" -var=`"azure_region=$AzureRegion`" -var=`"resource_name_suffix=$RandomNameSuffix`" -var=`"github_token=$GitHubToken`" -var=`"github_repository_full_name=$GitHubRepositoryFullName`" -auto-approve"
)

foreach ($command in $commands) {
    Write-Command -CommandText $command
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# #############################################################################
# Build the Remanufacturing Azure resources
# #############################################################################

Write-SectionHeader -Message "Create the Azure resources..."

$destinationPath = Join-Path -Path $TargetPath -ChildPath "infra\solution"

# Copy the dev.tfconfig file from the remote state folder to the GitHub folder
$sourcePath = Join-Path -Path $TargetPath -ChildPath "infra\remote-state"
Copy-Item -Path $sourcePath\dev.tfconfig -Destination $destinationPath -Recurse -Force

# Update the key in the dev.tfconfig file
Set-Location -Path $destinationPath
$filePath = Join-Path -Path $destinationPath -ChildPath "dev.tfconfig"
$fileContent = Get-Content -Path $filePath
$fileContent = $fileContent -replace 'key = "remanufacturing.tfstate"', 'key = "apim.tfstate"'
Set-Content -Path $filePath -Value $fileContent

# Build the tfvars file
$filePath = Join-Path -Path $destinationPath -ChildPath "dev.tfvars"
$fileContent = @"
azure_region         = "$AzureRegion"
azure_environment    = "dev"
resource_name_suffix = "$RandomNameSuffix"
apim_publisher_name  = "$APIMPublisherName"
apim_publisher_email = "$APIMPublisherEmail"
apim_sku_name        = "Developer_1"
"@
Set-Content -Path $filePath -Value $fileContent

# Execute Terraform commands
$commands = @(
    "terraform init --backend-config=dev.tfconfig",
    "terraform validate",
    "terraform apply --var-file=dev.tfvars -auto-approve"
)
foreach ($command in $commands) {
    Write-Command -CommandText $command
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# #############################################################################
# Synchronize local and remote repositories
# #############################################################################

Write-SectionHeader -Message "Synchronizing the local and remote repositories..."

# Navigate to the $TargetPath\cool-revive folder
Set-Location $TargetPath

# Initialize a new Git repository and switch to the develop branch
git init -b develop

# Add the root files to the repository tracking
Set-Location $TargetPath
git add .gitignore
git add README.md

# Add the infra\github files to the repository tracking
Set-Location (Join-Path -Path $TargetPath -ChildPath "infra\github")
git add variables.tf
git add providers.tf
git add main.tf

# Add the infra\remote-state files to the repository tracking
Set-Location (Join-Path -Path $TargetPath -ChildPath "infra\remote-state")
git add backend.tf
git add main.tf

# Add the infra\service-principal files to the repository tracking
Set-Location (Join-Path -Path $TargetPath -ChildPath "infra\service-principal")
git add main.tf

# Add the infra\solution files to the repository tracking
Set-Location (Join-Path -Path $TargetPath -ChildPath "infra\solution")
git add dev.tfvars
git add main-apim.tf
git add main-core.tf
git add main-inventorymanager.tf
git add main-ordernextcore.tf
git add modules.tf
git add providers.tf
git add tags.tf
git add variables.tf

# Commit the changes
git commit -m "Synchronizing the local and remote repositories."

# Add the remote repository and push the changes
git remote add origin $GitHubRepositoryUrl

# Pull the changes from the remote repository, allowing unrelated histories
git pull origin develop --allow-unrelated-histories

# Push the changes again to ensure everything is up to date
git push -u origin develop

# #############################################################################
# Wrap up
# #############################################################################

# Return to the original directory
Set-Location -Path $originalPath

Write-Output "Environment initialization completed successfully."