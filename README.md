# Yelb AWS Mentorship

# AWS Tagging Standard

All resources created in this project MUST include the following standard tags. 
These tags are managed globally via Terraform `default_tags`.

| Tag Key       | Description                                                                 | Example Values               |
|---------------|-----------------------------------------------------------------------------|------------------------------|
| `Environment` | The environment the resource belongs to. Matches the Terraform workspace.   | `dev`, `prod`                |
| `Project`     | The name of the project or product.                                         | `yelb-mentorship`            |
| `Owner`       | The email address or team name responsible for the resource.                | `your.email@example.com`     |
| `ManagedBy`   | The tool used to provision the resource. DO NOT edit these resources via UI.| `terraform`                  |

**Tagging Rules:**
- Tag Keys must use **PascalCase**.
- Tag Values should generally use **lowercase** (except for specific names/emails).
- Manual creation of resources without these tags is prohibited.