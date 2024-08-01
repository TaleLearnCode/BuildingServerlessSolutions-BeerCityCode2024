[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# Lab 0: Initialize Environment

## Objective

In this lab, you will use Terraform and PowerShell to set up your GitHub repository. Clone the repository to your local machine and deploy the necessary Azure resources to prepare for the upcoming labs.

> [!note]
>
> The Cool Revive Technologies solution implements a microservice-based architecture with the microservices composed of multiple modules. Generally, you will have different repositories and solutions for these, but for expediency, in this workshop, everything resides in one repository and one Visual Studio solution.

## Prerequisites

- Git is installed on your machine.
- A GitHub account.
- Visual Studio or Visual Studio Code installed on your local machine.

## Steps

### Section 1: Clone the Building Serverless Solutions Repo

1. Open a terminal window.

2. Navigate to the file location where you want to clone the repository.

3. Clone the repository:

   ```sh
   git clone <repository-url>
   ```

   

### Section 2: Create a GitHub Token

You will need a GitHub Token to allow the Terraform project to manage your GitHub resources.

1. Go to [GitHub](https://github.com) and log in to your account.
2. Click your profile photo in the upper-right corner of any GitHub page, then click **Settings**.
3. In the left sidebar, click **Developer settings**.
4. Click **Personal access tokens** > **Tokens (classic)** in the left sidebar.
5. Click **Generate new token** > **Generate new token (classic)**.
6. Configure the token:
   - Give your token a descriptive name in the **Note** field (e.g., `Terraform GitHub Token`).
   - Set an expiration date for the token. Choose a duration that matches your security policies.
   - Select the scopes (permissions) that your token needs. For managing repositories with Terraform, you will need
     - `repo` (Full control of private repositories)
     - `workflow` (Update GitHub Actions workflows)
     - `admin:repo_hook` (Full control of repository hooks)
     - `delete_repo` (Delete repositories)
7. Scroll to the bottom of the page and click **Generate token**.
8. Copy the generated token now. Once you leave the page, you will not be able to see it again.

### Section 3: Run Environment Initialization Script

We have built a PowerShell script to handle all the necessary tasks. Because of this, you do not need to follow many tedious steps to create your local folder structure, the GitHub repository, and the Azure resources we will use in this workshop.

1. Download the initialize-environment folder to your local machine.

2. Open a PowerShell terminal window.

3. From the Terminal window, connect to your Azure account:

   ```sh
   az login
   ```

   Follow the prompts to log into your Azure Account and select the appropriate subscription (if you have multiple subscriptions).

4. From the PowerShell terminal window, navigate to the directory where you downloaded `initialize-environment`.

5. Execute the `InitializeEnvironment.ps1` script from the initialize-environment folder:

   ```sh
   .\InitializeEnvironment.ps1 -TargetPath "<<TARGET-PATH>>" -GitHubToken "<<GITHUB_TOKEN>>" -APIMPublisherEmail "<<YOUR-EMAIL-ADDRESS>>"
   ```

   The script takes in the following parameters:

   | Parameter          | Required | Description                                                  |
   | ------------------ | -------- | ------------------------------------------------------------ |
   | APIMPublisherEmail | Yes      | The email address to be associated with the Azure API Management instance. Enter your email address. |
   | APIMPublisherName  | No       | The name of the organization associated with the Azure API Management instance. If not specified, then the publisher name will be `Cool Revive Technologies`. |
   | AzureRegion        | No       | The Azure region where to create the resources for the workshop. If not specified, then the resources will be created in the East US 2 Azure Region (`eastus2`). |
   | GitHubRepoName     | No       | The name of the GitHub repository to create. If not specified, then the repository will be named `cool-revive`. |
   | GitHubToken        | Yes      | The token from [Section 2](#section-2-create-a-github-token). |
   | TargetPath         | Yes      | The target path for your local repository. For example, `C:\Repos`. |

   > [!NOTE]
   >
   > The `TargetPath` parameter needs to point to an existing directory.

   > [!CAUTION]
   >
   > If you need to restart the `InitializeEnvironment.ps1` script, be sure to first delete the `$TargetPath\cool-revive` folder.

6. Inspect GitHub

7. Inspect Azure

> Check out the [Initialize Environment Script Details](initialize-environment-script-details.md) for details on what the InitializeEnvironment.ps1 script does.

