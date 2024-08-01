[Building Serverless Solutions with Azure and .NET](https://github.com/TaleLearnCode/BuildingServerlessSolutions) \ [Beer City Code 2024](..\README.md) \ [Labs](README.md) \

# GitHub Actions

The **Build Serverless Solutions** workshop labs use two GitHub Actions, which are built as part of [Lab 1](01-initialize-environment.md):

- **Continuous Integration** (`ci.yml`): Integrates code changes into the shared repository, running tests and builds to ensure code quality and functionality.
- **Continuous Deployment** (`cd.yml`): This process takes validated code changes from a repository and deploys them directly to the appropriate environment without manual intervention.

## Continuous Integration Actions

- If there are changes to the `infra\solutions\apim` directory:
  - Checkout the repository
  - Setup Terraform
  - Initialize the `infra\solutions\apim` Terraform project (`terraform init`).
  - Validate the `infra\solutions\apim` Terraform project (`terraform validate`).
  - Plan the `infra\solutions\apim` Terraform project (`terraform plan`).
- If there are changes to the `infra\solutions\remanufacturing\core` directory:
  - Checkout the repository
  - Setup Terraform
  - Initialize the `infra\solutions\remanufacturing\core` Terraform project (`terraform init`).
  - Validate the `infra\solutions\remanufacturing\core` Terraform project (`terraform validate`).
  - Plan the `infra\solutions\remanufacturing\core` Terraform project (`terraform plan`).
- If there are changes to the `infra\solutions\remanufacturing\ordernextcore` directory:
  - Checkout the repository
  - Setup Terraform
  - Initialize the `infra\solutions\remanufacturing\ordernextcore` Terraform project (`terraform init`).
  - Validate the `infra\solutions\remanufacturing\ordernextcore` Terraform project (`terraform validate`).
  - Plan the `infra\solutions\remanufacturing\ordernextcore` Terraform project (`terraform plan`).

## Continuous Deployment Actions

- If there are changes to the `infra\solutions\apim` directory:
  - Checkout the repository
  - Setup Terraform
  - Initialize the `infra\solutions\apim` Terraform project (`terraform init`).
  - Validate the `infra\solutions\apim` Terraform project (`terraform validate`).
  - Plan the `infra\solutions\apim` Terraform project (`terraform plan`).
  - Apply the `infra\solutions\apim` Terraform project (`terraform apply`)
- If there are changes to the `infra\solutions\remanufacturing\core` directory:
  - Checkout the repository
  - Setup Terraform
  - Initialize the `infra\solutions\remanufacturing\core` Terraform project (`terraform init`).
  - Validate the `infra\solutions\remanufacturing\core` Terraform project (`terraform validate`).
  - Plan the `infra\solutions\remanufacturing\core` Terraform project (`terraform plan`).
  - Apply the `infra\solutions\remanufacturing\core` Terraform project (`terraform apply`)
- If there are changes to the `infra\solutions\remanufacturing\ordernextcore` directory:
  - Checkout the repository
  - Setup Terraform
  - Initialize the `infra\solutions\remanufacturing\ordernextcore` Terraform project (`terraform init`).
  - Validate the `infra\solutions\remanufacturing\ordernextcore` Terraform project (`terraform validate`).
  - Plan the `infra\solutions\remanufacturing\ordernextcore` Terraform project (`terraform plan`).
  - Apply the `infra\solutions\remanufacturing\ordernextcore` Terraform project (`terraform apply`)