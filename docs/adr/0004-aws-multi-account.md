# ADR 0004: Multi-account AWS with a Cape Town-only guardrail

**Status:** Accepted · **Date:** 2026-10-22

## Context
The platform needs AWS for backups (S3) and disaster recovery drills. The personal AWS account had become the management account of an AWS Organization when IAM Identity Center was enabled. A region guardrail was planned as a Service Control Policy (SCP), but SCPs never apply to the management account, by design, so the owner cannot lock themselves out.

## Decision
- The **management account** holds only billing, AWS Organizations and IAM Identity Center. Nothing is built in it.
- Workloads (S3 backups, DR drills, Terraform-managed resources) live in a **member account**, `ikhaya-workloads`, inside an OU named `Workloads`.
- An SCP, `DenyOutsideCapeTown`, is attached to the OU: it denies every action outside `af-south-1`, except global services (IAM, billing, Organizations, Route 53, CloudFront, support and similar) that the console needs everywhere. The policy is kept in `terraform/aws-organization/policies/` so Terraform can manage it later.
- Access to both accounts is through IAM Identity Center **groups** (`Admins`), never direct user assignments.

## Alternatives considered
| Option | Why not |
|---|---|
| SCP on the single account | No effect: SCPs don't apply to the management account |
| IAM policy with a region condition on the permission set | Works only for identities using that permission set; an SCP is a ceiling for every identity in the account |
| Everything in one account | One compromised workload credential sits next to billing and identity control |

## Consequences
- **Positive:** workloads are separated from the account that controls identity and billing; nothing can be created outside South Africa, even by an administrator (proved on 2026-10-22: `s3:CreateBucket` in eu-north-1 refused "with an explicit deny in a service control policy"); costs still roll up to one bill and one budget.
- **Negative:** a new account starts with opt-in regions disabled. Cape Town had to be enabled in `ikhaya-workloads` (`aws account enable-region`, with trusted access for AWS Account Management) before Identity Center could provision access. The console showed "In progress" for over 10 minutes while the API already reported `FAILED`.
- **Follow-ups:** centralized root access to remove the member account's root credentials; manage the OU, SCP and account with Terraform.