resource "github_repository" "cool_revive" {
  name               = var.github_repository_name
  description        = var.github_repository_description
  visibility         = "public"
  #gitignore_template = "Terraform"
  license_template   = "mit"
  auto_init          = false
}

resource "github_branch" "develop" {
  repository = github_repository.cool_revive.name
  branch     = "develop"
}

resource "github_branch_default" "default"{
  repository = github_repository.cool_revive.name
  branch     = github_branch.develop.branch
}

output "github_repository_url" {
  value = github_repository.cool_revive.html_url
}

output "github_repository_full_name" {
  value = github_repository.cool_revive.full_name
}