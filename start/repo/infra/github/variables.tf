variable "github_token" {
  type        = string
  sensitive   = true
  description = "The GitHub token with repo, admin:repo_hook, workflow, and delete_repo permissions"
}

variable "github_repository_name" {
  type        = string
  description = "The name of the GitHub repository."
 }

 variable "github_repository_description" {
  type        = string
  default     = "Serverless event-driven microservice-based solution to handle the Cool Revive Technologies remanufacturing processes."
  description = "Description of the GitHub repository."
 }