# Repository containing Terraform/OpenTofu modules for provisioning infrastructure on Proxmox

Current list of modules:
- [k3s](modules/k3s/)
  - [example deployment using this modules](examples/k3s-example-deployment/)

Additional modules and examples will be added over time.

## How to get started using these modules

- Install terraform or opentofu
- Create a git repo to house your IaC deployments. Can be in github, gitlab, your own private git server, etc
- Copy example deployment for module you want to use into your new deployment repo
- Update example input variables for your environment specific settings. proxmox creds, node names, IP addresses, etc
- Set `source` for copied configuration to reference a tag from the public git repo instead of the local reference used for testing. example: `source = git::https://github.com/jbmay/proxmox-tf-modules.git//modules/k3s?ref=v0.1.1`
- Run `terraform/tofu init` to init your backend and download modules
- Run `terraform/tofu apply` to apply the configuration
- Run `terraform/tofu destroy` to destroy the deployed infrastructure
- Read the README and variables.tf for the module for configuration notes, limitations, known issues, and additional variables not set in the example deployment
- Push your working deployment to your remote repo and consider setting up cicd to handle your infrastructure deployments for you. Be sure to not store anything sensitive in git. It is recommended to add state and auto.tfvars files to .gitignore so they aren't accidentally committed with sensitive values
