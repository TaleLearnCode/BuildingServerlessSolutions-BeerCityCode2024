[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# Initialize Environment Script Details

In [Lab 1](01-initialize-environment.md), you will execute the InitializeEnvironment.ps1 PowerShell script. This script is specifically designed to initialize your development environment for the **Build Serverless Solutions** workshop labs. Below is a detailed description of the script's actions and what is created in the included Terraform projects.

## InitializeEnvironment.ps1 Actions

The `InitializeEnvironment.ps1` PowerShell script is divided into ten parts, as described below.

1. [Script Initialization](#script-initialization)
2. [Random Suffix Generation](#random-suffix-generation)
3. [Build Local Repository Directory Structure](#build-local-repository-directory-structure)
4. [Initialize Local Repository](#initialize-local-repository)
5. [Copy Root Files to the Repository](#copy-root-files-to-the-repository)
6. [Initialize Terraform Remote State](#initialize-terraform-remote-state)
7. [Create Azure Service Principal](#create-azure-service-principal)
8. [Build GitHub Actions Pipelines](#build-github-actions-pipelines)
9. [Add API Management Terraform Project](#add-api-management-terraform-project)
10. [Add Remanufacturing Core Terraform Project](#add-remanufacturing-core-terraform-project)
11. [Add Remanufacturing Order Next Core Terraform Project](#add-remanufacturing-order-next-core-terraform-project)

### Script Initialization

Everything is set up to execute the other script parts during the *Script Initialization* part. This part does the following:

1. Defines the parameters for the script (`TargetPath`, `GitHubToken`, `GitHubRepoName`, and `AzureRegion`).
2. Prompts the user for missing required input parameters (`TargetPath` and `GtiHubToken`).
3. Validates that `TargetPath` points to a valid path.

### Random Suffix Generation

Many Azure resources must be globally unique. To help ensure that the Azure resources Terraform projects associated with the script are managed, the Random Suffix Generation part generates a random value between 1 and 1000 to build a `$RandomNameSuffix` variable used in other parts of the script.

### Build Local Repository Directory Structure

During the *Build Local Repository Directory Structure* part of the script, the directory structure for the local repository is created. This will create the following folder structure:

- $TargetPath\cool-revive
- $TargetPath\cool-revive\\.github
- $TargetPath\cool-revive\\.github\workflows
- $TargetPath\cool-revive\infra
- $TargetPath\cool-revive\infra\github
- $TargetPath\cool-revive\infra\remote-state
- $TargetPath\cool-revive\infra\service-principal
- $TargetPath\cool-revive\infra\solution\apim

### Initialize GitHub Repository

The **Building Serverless Solutions** labs depend on a GitHub repository, and the *Initialize GitHub Repository* script part is responsible for creating that GitHub repository. This part of the script will perform the following actions:

1. Copying the files from the initialize-github folder to the `$TargetPath\cool-revive\infra\github` folder. This folder makes up the [GitHub Repository](#github-repository) Terraform project.
2. Create a `github.tfconfig` file containing the GitHub personal access token. This file will not be pushed to the centralized repository.
3. Applies the GitHub Terraform project in the `$TargetPath\cool-revive\infra\github` folder by executing the following commands:
   - `terraform init`
   - `terraform validate`
   - `terraform apply -var=github_token=$GitHubToken -var=github_repository_name=$GitHubRepoName`
4. Captures the following from the terraform apply output:
   - The URL of the created GitHub repository (`$GitHubRepositoryUrl`)
   - The full name of the created GitHub repository (`$GitHubRepositoryFullName`)

### Initialize Local Repository

Now that the remote GitHub repository has been created, we can initialize the local repository and connect it to the remote repository.

1. Initializing the Git repository (`git init -b develop`).
2. Add the files to the repository tracking:
   - `cool-revive\infra\github\variables.tf` (`git add variables.tf`)
   - `cool-revive\infra\github\providers.tf` (`git add providers.tf`)
   - `cool-revive\infra\github\main.tf`  (`git add main.tf`)
3. Commits the changes (`git commit -m "Initial commit with Terraform configuration for GitHub repository."`)
4. Adds the remote repository and pushes the changes (`git remote add origin $GitHubRepositoryUrl`)
5. Pulls the changes from the remote repository (`git pull origin develop --allow-unrelated-histories`)
6. Pushes the changes to the remote repository (`git push -u origin develop`)

### Copy Root Files to the Repository

The GitHub provider does create the README.md and .gitignore files when it creates the repository, but the *Copy Root Files to the Repository* replaces those with more robust versions of the files. This is done by performing the following actions:

1. Copying the files from the `root-files` directory to the `$TargetPath\cool-revive` directory.
2. Adding the copied files to the GitHub tracking.
3. Committing the changes locally.
4. Pushing the commit to the remote repository.

### Initialize Terraform Remote State

By default, Terraform stores the state information locally. But a better option is to store that state in a remote source which can then be used by other users and (more importantly for our purposes) CI/CD pipelines. To initialize the remote state, this part of the script performs the following actions:

1. Copies the files from `initialize-remote-state` folder to the target remote-state folder (`$TargetPath\cool-revive\infra\remote-state`). These files represent the [Terraform Remote State](#terraform-remote-state) Terraform project.
2. Perform the following Terraform actions:
   - Initialize the Terraform project (`terraform init`)
   - Validates the Terraform project (`terraform validate`)
   - Applies the Terraform configuration (`terraform apply -var="azure_environment=dev" -var="azure_region=$AzureRegion" -var="resource_name_suffix=$RandomNameSuffix" -auto-approve`)
3. Migrates the remote state Terraform project's state to the remote state by doing the following:
   - Creating the `backend.tf` file instructing Terraform to use the `azurerm` backend for its state.
   - Reinitializing the Terraform project (`terraform init --backend-config=dev.tfconfig -migrate-state -force-copy`)
4. Updates the GitHub remote repository by:
   - Adding the new files (main.tf and backend.tf) to the repository tracking.
   - Commit the changes to the local repository.
   - Pushing the changes to the remote repository.

### Create Azure Service Principal

An Azure Service Principal is needed to enable the GitHub Action pipelines to manage Azure resources. The *Create Azure Service Principal* part of the script performs the following actions:

1. Copy the files from the `create-service-principal\service-principal` folder to the target service principal folder (`$TargetPath\cool-revive\infra\service-principal`). This represents the [Service Principal](#service-principal) Terraform project.
2. Copying the `dev.tfconfig` file from the `$TargetPath\cool-revive\infra\remote-state` folder to the `$TargetPath\cool-revive\infra\service-principal` folder.
3. Update the key in the copied `dev.tfconfig` file to `service-principal.tfstate`.
4. Perform the following Terraform actions:
   - Initialize the Terraform project (`terraform init`)
   - Validates the Terraform project (`terraform validate`)
   - Applies the Terraform configuration (`terraform apply -auto-approve`)
5. Updates the GitHub Repository by:
   - Adding the `main.tf` file to the local repository tracking (`git add main.tf`)
   - Committing the changes locally (`git commit -m "Creating the Azure Service Principal"`)
   - Pushing the commit to the remote repository (`git push -u origin features/initialize-setup`)

### Build GitHub Actions Pipelines

We will use GitHub Actions to perform our continuous integration (CI) and continuous deployment (CD) operations. The *Build GitHub Actions Pipelines* part of the PowerShell script will create pipelines and add them to the central repository by performing the following actions:

1. Copy the files from the `workflows` folder to the target workflows folder (`$TargetPath\cool-revive\.github\workflows`). This folder contains the [GitHub Actions pipelines](github-actions.md).
2. Adds the new files to the repository tracking:
   - `git add ci.yml`
   - `git add cd.yml`
3. Commits the local changes (`git commit -m "Adding the GitHub Actions pipelines"`).
4. Pushes the local commit to the central repository (`git push -u origin features/initial-setup`)

### Add API Management Terraform Project

This part of the PowerShell script will copy the Terraform project files into the repository and push those to the central repository by performing the following actions:

1. Copying the files from the `solution-api-management` folder to the target APIM solutions folder (`$TargetPath\cool-revive\infra\solution\apim`). This represents the [APIM Terraform project](terraform-projects.md#api-management).
2. Copying the `dev.tfconfig` file from the `$TargetPath\cool-revive\infra\remote-state` folder to the `$TargetPath\cool-revive\infra\soltuion\apim` folder.
3. Update the key in the copied `dev.tfconfig` file to `apim.tfstate`.
4. Builds the tfvars file, adding the following variable definitions:
   - azure_region
   - azure_environment
   - resource_name_suffix
   - apim_publisher_name
   - apm_publisher_email
   - apim_sku_name
5. Adds the new files to the repository tracking:
   - `git add main-apim.tf`
   - `git add main-rg.tf`
   - `git add modules.tf`
   - `git add providers.tf`
   - `git add tags.tf`
   - `git add variables.tf`
   - `git add dev.tfvars`
6. Commits the local changes (`git commit -m "Adding the APIM Terraform project"`).
7. Pushes the local commit to the central repository (`git push -u origin features/initial-setup`)

### Add Remanufacturing Core Terraform Project

This part of the PowerShell script will copy the Terraform project files into the repository and push those to the current repository by performing the following actions:

1. Copying the files from the `solution-remanufacturing-core` folder to the target APIM solutions folder (`$TargetPath\cool-revive\infra\solution\remanufacturing\core`). This represents the [Remanufacturing Core Terraform project](terraform-projects.md##remanufacturing-core).
2. Copying the `dev.tfconfig` file from the `$TargetPath\cool-revive\infra\remote-state` folder to the `$TargetPath\cool-revive\infra\soltuion\remanufacuring\core` folder.
3. Update the key in the copied `dev.tfconfig` file to `remanufacturing-core.tfstate`.
4. Builds the tfvars file, adding the following variable definitions:
   - azure_region
   - azure_environment
   - resource_name_suffix
5. Adds the new files to the repository tracking:
   - `git add main-appcs.tf`
   - `git add main-kv.tf`
   - `git add main-rg.tf`
   - `git add main-sbns.tf`
   - `git add modules.tf`
   - `git add providers.tf`
   - `git add tags.tf`
   - `git add variables.tf`
   - `git add dev.tfvars`
6. Commits the local changes (`git commit -m "Adding the Remanufacturing Core Terraform project"`).
7. Pushes the local commit to the central repository (`git push -u origin features/initial-setup`)

### Add Remanufacturing Order Next Core Terraform Project

This part of the PowerShell script will copy the Terraform project files into the repository and push those to the current repository by performing the following actions:

1. Copying the files from the `solution-remanufacturing-ordernextcore` folder to the target APIM solutions folder (`$TargetPath\cool-revive\infra\solution\remanufacturing\ordernextcore`). This represents the [Remanufacturing Order Next Core Terraform project](terraform-projects.md##remanufacturing-ordernextcore).
2. Copying the `dev.tfconfig` file from the `$TargetPath\cool-revive\infra\remote-state` folder to the `$TargetPath\cool-revive\infra\soltuion\remanufacuring\ordernextcore` folder.
3. Update the key in the copied `dev.tfconfig` file to `remanufacturing-ordernextcore.tfstate`.
4. Builds the tfvars file, adding the following variable definitions:
   - azure_region
   - azure_environment
   - resource_name_suffix
5. Adds the new files to the repository tracking:
   - `git add main-func.tf`
   - `git add main-rg.tf`
   - `git add main-sbt-getnextcore.tf`
   - `git add main-sbt-ordernextcore.tf`
   - `git add modules.tf`
   - `git add providers.tf`
   - `git add tags.tf`
   - `git add variables.tf`
   - `git add dev.tfvars`
6. Commits the local changes (`git commit -m "Adding the Remanufacturing Order Next Core Terraform project"`).
7. Pushes the local commit to the central repository (`git push -u origin features/initial-setup`)

### Create the Visual Studio Solution

Finally, we create the Visual Studio solution that we will use throughout the project. This is done by performing the following actions:

1. Copying the files from the `src` folder to the target APIM solutions folder (`$TargetPath\cool-revive\s`rc).
2. Adds the new files to the repository tracking:
   - `git add Remanufacturing.sln`
3. Commits the local changes (`git commit -m "Adding the Remanufacturing solution"`).
4. Pushes the local commit to the central repository (`git push -u origin features/initial-setup`)