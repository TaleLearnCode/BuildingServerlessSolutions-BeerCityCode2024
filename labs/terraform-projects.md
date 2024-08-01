[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# Initialize Environment Script Details

To build out the resources for the **Build Serverless Solutions** workshop labs, ten Terraform projects are specific to categories of resources for the solution. These Terraform projects are described below.

- [GitHub Repository](#github-repository)
- [Terraform Remote State](#terraform-remote-state)
- [Service Principal](#service-principal)
- [API Management](#api-management)
- [Remanufacturing Core](#remanufacturing-core)

## GitHub Repository

The *GitHub Repository* Terraform project manages the GitHub repository you will use for the workshop labs. This project can be found in the `infra\github` folder of the repository.  The project manages the following resources:

- The `cool-revive` GitHub repository (the name of the repository can be overridden).
- The `develop` branch from the `main` branch in the `cool-revive` GitHub repository.
- Assigning the `develop` branch as the default branch for the `cool-revive` GitHub repository.

> [!CAUTION]
>
> This is designed as a one-time-run Terraform configuration. Running it again using the same variables (parameters) could cause unintended changes to your GitHub repository.

## Terraform Remote State

The *Terraform Remote State* project manages the Azure resources necessary for maintaining the remote state for your Terraform projects that are a part of this workshop (except the [GitHub Repository](#github-repository) project.) The project is located in the `infra\remote-state` repository folder and manages the following resources:

- **rg-CoolReviveTerraform-{env}-{region}**: Azure Resource Group to house the Terraform Remote State resources.
- **stterraform{suffix}{env}{region}**: Azure Storage Account to house the Terraform state files. A SAS token is also created for the Terraform projects to read, write, delete, list, add, and create blobs in the storage account.

The project also creates an {env}.tfconfig (e.g. `dev-tfconfig`) containing the details a Terraform project needs to connect to the remote state. Files with the the `tfconfig` extension are not pushed to the remote GitHub repository per the `.gitignore` file.

## Service Principal

The *Service Principal* project manages the Azure Service Principal and the GitHub Action secrets related to that service principal. The project is located in the `infra\service-principal` repository folder and manages the following resources:

#### Azure Resources

The *Service Principal* project manages the following Azure resources to give GitHub Actions pipelines the permissions they need to manage Azure resources:

- **Terraform Manage Role Assignments**: This custom role definition for your Azure subscription allows Azure resources to read, write, and delete Azure role assignments.
- **Terraform Service Principal** (application): The Azure AD application associated with the **Terraform Service Principal** service principal.
- **Terraform Service Principal** (service principal): The Azure service principal that the GitHub Actions pipelines will use.

#### GitHub Resources

The *Service Principal* project manages the following GitHub Action Secrets:

- **AZURE_CREDENTIALS**: The credentials needed to log in as the *Terraform Service Principal* service principal.
- **AZURE_AD_CLIENT_ID**: The client identifier for the *Terraform Service Principal* service principal.
- **AZURE_AD_CLIENT_SECRET**: The secret (password) for the *Terraform Service Principal* service principal.
- **AZURE_SUBSCRIPTION_ID**: The identifier of the Azure subscription being used by the Cool Revive solution.
- **AZURE_AD_TENANT_ID**: The identifier of the Azure tenant where the Azure resources are being created.
- **TERRAFORM_STORAGE_ACCOUNT_NAME**: Name of the `stterraform{suffix}{env}{region}` Azure Storage account used for the Terraform remote state. The [Terraform Remote State](#terraform-remote-state) Terraform project manages this account.
- **TERRAFORM_RESOURCE_GROUP**: Name of the `rg-CoolRevive-{env}-{region}` Azure Resource Group where the Terraform remote state storage account is housed. The [Terraform Remote State](#terraform-remote-state) Terraform project manages this account.

## API Management

The *API Management* project manages the resources for Cool Revive Technologies' API Management instance. This project is located in the `solution\apim` repository folder and manages the following resources:

- **rg-CoolRevive_APIManagement-{env}-{region}** (Resource Group): The resource group where the APIM Management resources are grouped.
- **apim-CoolRevive{suffix}-{env}-{region}** (API Management): The Azure API Management instance used by the Cool Revive Technologies organization.

## Remanufacturing Core

The *Remanufacturing Core* project manages the core resources for the Cool Revive Remanufacturing system. This project is located in the `solution\remanufacturing\core` folder and manages the following resources:

- **rg-CoolRevive_Remanufacturing-{env}-{region}** (Resource Group): The resource group where the Remanufacturing core resources are grouped.
- **kv-crreman{suffix}-{env}-{region}** (Key Vault): Secret store used by the Remanufacturing system.
- **appcs-CoolRevive_Remanufacturing{suffix}-{env}-{region}** (App Configuration Store): App configuration store used by the Remanufacturing system.
- **log-CoolRevive_Remanufacturing{suffix}-{env}-{region}** (Log Analytics Workspace): The Log Analytics Workspace used by the Remanufacturing system.
- **appcs-CoolRevive_Remanufacturing{suffix}-{env}-{region}** (Application Insights): Provides telemetry data for the Remanufacturing system.
- **sbns-CoolRevive-Remanufacturing{suffix}-{env}-{region}** (Service Bus Namespace): The Service Bus namespace is used for the event-drive architecture messaging used by the Remanufacturing system.

## Remanufacturing Order Next Core

The *Remanufacturing Order Next Core* project manages primary resources for the **Order Next Core** service. This project is located in the `solution\remanufacturing\ordernextcore` folder and manages the following resources:

- **rg-CoolRevive_Remanufacutring_OrderNextCore-{env}-{region}** (Resource Group): The resource group where the Order Next Core resources are grouped.
- **sbt-CoolRevive_GetNextCore{suffix}-{env}-{region}** (Service Bus Topic): The topic used to retrieve the next core from the Production Schedule.
- **sbts-CoolRevive-GetNextCore{suffix}-{env}-{region}** (Service Bus Topic Subscription): The topic subscription that is used to retrieve the next core from the Production Schedule.
- **sbt-CoolRevive_OrderNextCore{suffix}-{env}-{region}** (Service Bus Topic): The topic used to start the process of ordering the next core from the warehouse.
- **sbts-CoolRevive_OrderNextCore{suffix}-{env}-{region}** (Service Bus Topic Subscription): The subscription that is used to start the process of ordering the next core from the warehouse.
- **stcronc{suffix}{env}{region}** (Storage Account): The storage account that the func-CoolRevive_OrderNextCore Azure Function App uses.
- **asp-CoolRevive_OrderNextCore{suffix}-{env}-{region}** (App Service Plan): The application service plan hosting the func-CoolRevive-OrderNextCore Azure Function App.
- **func-CoolRevive_OrderNextCore{suffix}-{env}-{region}** (Function App): The Azure Function App hosts the serverless functions for the Order Next Core service.