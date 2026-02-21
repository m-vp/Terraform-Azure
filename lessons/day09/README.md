# Day 09 — Terraform Lifecycle Rules: `create_before_destroy`, `prevent_destroy`, `ignore_changes`, and Custom Conditions

> **Goal:** Understand and apply Terraform's `lifecycle` meta-argument to control exactly how resources are created, updated, and destroyed in Azure. We build on the Storage Accounts and Resource Groups from Day 08.

---

## Table of Contents

1. [What is the `lifecycle` Meta-Argument?](#1-what-is-the-lifecycle-meta-argument)
2. [The Four Lifecycle Features](#2-the-four-lifecycle-features)
3. [Lab 1 — `create_before_destroy` on Storage Account](#3-lab-1--create_before_destroy-on-storage-account)
4. [Lab 2 — `prevent_destroy` on Storage Account](#4-lab-2--prevent_destroy-on-storage-account)
5. [Lab 3 — `ignore_changes` on Resource Group](#5-lab-3--ignore_changes-on-resource-group)
6. [Lab 4 — Custom Condition (precondition) blocking Canada Central](#6-lab-4--custom-condition-precondition-blocking-canada-central)
7. [Complete Working Example](#7-complete-working-example)
8. [Lifecycle Rules Quick Reference](#8-lifecycle-rules-quick-reference)
9. [Common Mistakes and How to Avoid Them](#9-common-mistakes-and-how-to-avoid-them)

---

## 1. What is the `lifecycle` Meta-Argument?

Every Terraform resource block can optionally include a `lifecycle` block. This block instructs Terraform on **how to manage the resource's life** — specifically, what to do when the resource needs to be replaced, updated, or destroyed.

```hcl
resource "azurerm_storage_account" "example" {
  name                     = "mystorageaccount"
  resource_group_name      = "my-rg"
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    # lifecycle rules go here
    create_before_destroy = true
  }
}
```

The `lifecycle` block is a **meta-argument** — meaning it's not a configuration option for the Azure resource itself, but rather an instruction to Terraform's internal engine about how to handle this resource during plan and apply operations.

### Default Terraform Behavior (without lifecycle)

By default, when Terraform needs to replace a resource (for example, when you change a property that cannot be updated in-place like a storage account name):

```
STEP 1: Destroy the existing resource   ← old one is deleted first
STEP 2: Create the new resource         ← new one is created after
```

This is called **destroy before create**. For many production resources, this causes downtime because the old resource disappears before the new one is ready. Lifecycle rules let you change this behavior.

---

## 2. The Four Lifecycle Features

| Feature | What It Does |
|---|---|
| `create_before_destroy` | Creates the replacement resource first, then destroys the old one |
| `prevent_destroy` | Blocks `terraform destroy` and any plan that would delete the resource |
| `ignore_changes` | Tells Terraform to ignore specific attribute changes in future plans |
| `precondition` / `postcondition` | Validates custom conditions before/after resource operations |

---

## 3. Lab 1 — `create_before_destroy` on Storage Account

### The Problem It Solves

Without `create_before_destroy`, renaming a storage account causes this sequence:

```
terraform apply (rename storageacctdev01 → storageacctdevnew01)

DEFAULT sequence:
  1. Destroy storageacctdev01  ← Storage account is GONE. Any app reading from it breaks!
  2. Create  storageacctdevnew01  ← New one comes up. Downtime occurred.
```

With `create_before_destroy`, the sequence becomes:

```
terraform apply (rename storageacctdev01 → storageacctdevnew01)

create_before_destroy sequence:
  1. Create  storageacctdevnew01  ← New one is ready FIRST. Zero downtime!
  2. Destroy storageacctdev01     ← Old one removed only after new one exists.
```

### Why Does Renaming Force Replacement?

Azure Storage Account names are **immutable** — once created, they cannot be changed in-place. If you change the `name` argument, Terraform knows it must destroy and recreate the resource. This is called a **forced replacement**.

You can always see this in `terraform plan` — it shows `# forces replacement` next to the changed attribute.

### Implementation

**`variables.tf`**
```hcl
variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-terraform-day09"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "storage_account_names" {
  description = "List of storage account names (used with count)"
  type        = list(string)
  default     = ["storageacctdev01", "storageacctdev02"]
}
```

**`main.tf` — Storage Account with `create_before_destroy`**
```hcl
resource "azurerm_storage_account" "cbd_sa" {
  count = length(var.storage_account_names)

  name                     = var.storage_account_names[count.index]
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    create_before_destroy = true
    # Terraform will now:
    #   1. Create the new storage account (with the new name)
    #   2. Destroy the old storage account (with the old name)
    # Instead of the default destroy-first approach.
  }
}
```

### Step-by-Step Test

**Step 1:** Apply with the original names.

```bash
terraform apply
# Creates:
#   storageacctdev01
#   storageacctdev02
```

**Step 2:** Change the variable to rename one account.

```hcl
# In variables.tf, change:
default = ["storageacctdev01", "storageacctdev02"]

# To:
default = ["storageacctdevnew01", "storageacctdev02"]
```

**Step 3:** Run `terraform plan` and observe the output.

```bash
terraform plan
```

You will see output similar to:

```
  # azurerm_storage_account.cbd_sa[0] must be replaced
+/- resource "azurerm_storage_account" "cbd_sa" {
      ~ name = "storageacctdev01" -> "storageacctdevnew01" # forces replacement

      Plan: 1 to add, 0 to change, 1 to destroy.
```

The `+/-` symbol (instead of just `-` then `+`) tells you Terraform is using `create_before_destroy`.

**Step 4:** Apply and watch the order in the output.

```bash
terraform apply
```

**Observed output:**

```
azurerm_storage_account.cbd_sa[0]: Creating...          ← NEW one created FIRST
azurerm_storage_account.cbd_sa[0]: Creation complete after 30s [id=.../storageacctdevnew01]

azurerm_storage_account.cbd_sa[0] (deposed): Destroying...   ← OLD one destroyed AFTER
azurerm_storage_account.cbd_sa[0] (deposed): Destruction complete after 15s
```

The word `(deposed)` in Terraform's output means "the old instance that is being replaced." This confirms the new resource was created before the old one was destroyed.

### Important Limitation

`create_before_destroy` requires that **both** the old and new resource can exist simultaneously. For some Azure resources (like storage accounts with globally unique names), both names are different so this is fine. But if you tried to keep the same name, Azure would reject the second creation since the name is already taken.

---

## 4. Lab 2 — `prevent_destroy` on Storage Account

### The Problem It Solves

Imagine you have a production storage account containing critical data. Without `prevent_destroy`, someone on your team could accidentally run `terraform destroy` and permanently delete it. `prevent_destroy = true` acts as a **safety lock** that makes Terraform refuse to destroy the resource, even when explicitly told to.

### How It Works

When `prevent_destroy = true` is set:

- `terraform destroy` on that resource → **Error, operation blocked**
- `terraform apply` with a change that requires replacement → **Error, operation blocked**
- `terraform apply` with in-place updates (no replacement) → **Works fine**

The protection only triggers when **destruction is required**. Normal updates are unaffected.

### Implementation

**`main.tf` — Storage Account with `prevent_destroy`**
```hcl
resource "azurerm_storage_account" "protected_sa" {
  name                     = "storageacctprotected01"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    prevent_destroy = true
    # This storage account CANNOT be destroyed by Terraform.
    # Any plan that would destroy it will fail with an error.
  }
}
```

### Step-by-Step Test

**Step 1:** Apply to create the protected storage account.

```bash
terraform apply
```

**Step 2:** Change the storage account name (which forces replacement = destroy + create).

```hcl
# Change:
name = "storageacctprotected01"
# To:
name = "storageacctprotectednew"
```

**Step 3:** Run `terraform plan`.

```bash
terraform plan
```

**Observed error:**

```
╷
│ Error: Instance cannot be destroyed
│
│   on main.tf line 25, in resource "azurerm_storage_account" "protected_sa":
│   25:   lifecycle {
│
│ Resource azurerm_storage_account.protected_sa has lifecycle.prevent_destroy
│ set, but the plan calls for this resource to be destroyed. To avoid this
│ error and continue with the plan, either disable lifecycle.prevent_destroy or
│ reduce the scope of the plan using the -target flag.
╵
```

Terraform refuses to even create a plan. It stops at the planning stage and tells you exactly which resource is protected and which line the `lifecycle` block is on.

**Step 4:** Try `terraform destroy`.

```bash
terraform destroy
```

**Observed error:**

```
╷
│ Error: Instance cannot be destroyed
│
│ Resource azurerm_storage_account.protected_sa has lifecycle.prevent_destroy
│ set, but the plan calls for this resource to be destroyed.
╵
```

Same error. The resource cannot be destroyed via Terraform at all while `prevent_destroy = true` is in the configuration.

**Step 5 (when you genuinely want to delete it):** Remove `prevent_destroy = true` from the config first, then destroy.

```hcl
# Remove or change to:
lifecycle {
  prevent_destroy = false
}
```

Then run:
```bash
terraform destroy
```

> **Key Insight:** `prevent_destroy` is a guardrail in your Terraform code — not in Azure itself. If someone deletes the resource via the Azure Portal or Azure CLI, Terraform won't stop them. The protection only applies to Terraform operations.

### What You Observed — Summary

| Action | With `prevent_destroy = true` |
|---|---|
| `terraform apply` (in-place update) | ✅ Works |
| `terraform apply` (rename = forced replacement) | ❌ Error |
| `terraform destroy` | ❌ Error |
| Delete via Azure Portal | ⚠️ Works (Terraform has no control over this) |

---

## 5. Lab 3 — `ignore_changes` on Resource Group

### The Problem It Solves

Sometimes a resource's attributes are changed **outside of Terraform** — by someone using the Azure Portal, an Azure Policy, a script, or another tool. By default, Terraform would detect this drift during the next `terraform plan` and try to "fix" it by reverting the change. This is often undesirable.

`ignore_changes` tells Terraform: **"I know this attribute might change outside of Terraform — don't try to revert it."**

A common real-world scenario: Azure Policies automatically add mandatory tags to all resources. Terraform doesn't know about these tags, so every `terraform plan` would say "I need to remove these tags" — causing a constant battle between Terraform and Azure Policy. `ignore_changes = [tags]` stops this.

### How It Works

```hcl
lifecycle {
  ignore_changes = [tags]
  # Terraform will never try to revert changes to the tags attribute
  # Even if tags were modified outside of Terraform
}
```

You can ignore multiple attributes:

```hcl
lifecycle {
  ignore_changes = [tags, name, location]
}
```

Or ignore ALL attributes (use sparingly — this means Terraform never manages the resource after initial creation):

```hcl
lifecycle {
  ignore_changes = all
}
```

### Implementation

**`main.tf` — Resource Group with `ignore_changes`**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }

  lifecycle {
    ignore_changes = [
      tags,
      # Add 'name' here if you also want to ignore name changes
      # (useful if the RG was renamed outside Terraform)
    ]
    # Terraform will:
    # - Create the resource group with the tags above (on first apply)
    # - NEVER try to update or revert the tags after that, even if they change
  }
}
```

### Step-by-Step Test

**Step 1:** Apply to create the resource group.

```bash
terraform apply
# Resource group created with tags: { environment = "dev", managed_by = "terraform" }
```

**Step 2:** Simulate an external change — go to the Azure Portal and add/modify a tag on the resource group (e.g., add `team = "platform-engineering"`).

Alternatively, simulate this by changing the `tags` block in your Terraform code:

```hcl
tags = {
  environment = "dev"
  managed_by  = "terraform"
  team        = "platform-engineering"   # Added externally
}
```

**Step 3:** Run `terraform plan`.

```bash
terraform plan
```

**Observed output (with `ignore_changes = [tags]`):**

```
No changes. Your infrastructure matches the configuration.
```

Terraform sees the tag difference but **ignores it** because `tags` is in the `ignore_changes` list. Without `ignore_changes`, the plan would show:

```
~ resource "azurerm_resource_group" "rg" {
    ~ tags = {
        + "team" = "platform-engineering"
      }
}
```

### Testing `ignore_changes` on the `name` Attribute

> ⚠️ **Important Note for Resource Groups:** The `name` attribute of an Azure Resource Group **forces replacement** (destroy + recreate) if changed. This means `ignore_changes = [name]` cannot prevent the replacement since ignore_changes only prevents drift correction — it does not stop you from changing the value in your own Terraform code. Here's what actually happens:

**Change the name in your Terraform config:**
```hcl
variable "resource_group_name" {
  default = "rg-terraform-day09-updated"  # Changed from "rg-terraform-day09"
}
```

**Run `terraform plan`:**

```
# azurerm_resource_group.rg must be replaced
-/+ resource "azurerm_resource_group" "rg" {
      ~ name = "rg-terraform-day09" -> "rg-terraform-day09-updated" # forces replacement
    }
```

**What you observe:** Even with `ignore_changes = [name]` in the lifecycle block, Terraform still plans a replacement. This is because `ignore_changes` prevents Terraform from reacting to changes made **outside** Terraform — it doesn't prevent Terraform from applying changes you explicitly make **inside** Terraform.

> **The real use case for `ignore_changes = [name]`** would be: if the name was changed in Azure outside of Terraform, and you don't want Terraform to "fix" it back. But since you're the one changing it in your .tf file, Terraform always acts on your code.

### Correct Interpretation of `ignore_changes` Behavior

| Scenario | With `ignore_changes = [attr]` | Without `ignore_changes` |
|---|---|---|
| Attribute changed in Azure Portal/CLI | ✅ Terraform ignores it | ⚠️ Terraform reverts it on next apply |
| Attribute changed in your .tf code | Terraform still applies it | Terraform applies it |
| Attribute forced replacement (immutable) | Terraform still replaces it | Terraform replaces it |

---

## 6. Lab 4 — Custom Condition (`precondition`) Blocking Canada Central

### What is a `precondition`?

A `precondition` is a custom validation that Terraform evaluates **before** creating or modifying a resource. If the condition is `false`, Terraform stops with a custom error message. It's your way of encoding business rules or infrastructure policies directly in your Terraform code.

There is also a `postcondition` that runs **after** the resource is created, useful for validating that the actual deployed resource meets expectations.

### Syntax

```hcl
resource "azurerm_resource_group" "example" {
  name     = "my-rg"
  location = var.location

  lifecycle {
    precondition {
      condition     = <boolean expression>
      error_message = "Human-readable message shown when condition is false."
    }
  }
}
```

- `condition` must be a boolean expression that returns `true` (proceed) or `false` (block and error)
- `error_message` is shown to the user when the condition fails
- You can have **multiple** `precondition` blocks on a single resource

### Implementation — Block Canada Central

**`variables.tf`**
```hcl
variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "East US"
  # Try changing this to "Canada Central" to trigger the precondition error
}
```

**`main.tf` — Resource Group with custom precondition**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  lifecycle {
    precondition {
      condition = lower(var.location) != "canada central"
      # lower() normalizes the string so "Canada Central", "CANADA CENTRAL",
      # and "canada central" are all caught by this condition.
      #
      # The condition is TRUE  when location is anything OTHER than "canada central" → proceed
      # The condition is FALSE when location is "canada central"                    → error

      error_message = "ERROR: Deployment to 'Canada Central' is not permitted by policy. Please choose a different Azure region (e.g., 'East US', 'West Europe', 'Southeast Asia')."
    }
  }
}
```

**`main.tf` — Storage Account with the same precondition**
```hcl
resource "azurerm_storage_account" "sa" {
  count = length(var.storage_account_names)

  name                     = var.storage_account_names[count.index]
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    precondition {
      condition     = lower(var.location) != "canada central"
      error_message = "ERROR: Storage accounts cannot be deployed to 'Canada Central'. This region is restricted by organizational policy."
    }
  }
}
```

### Step-by-Step Test

**Step 1:** Apply with a valid location (`East US`).

```bash
terraform apply
# Works fine — condition is met (East US != Canada Central)
```

**Step 2:** Change the location variable to `Canada Central`.

```hcl
variable "location" {
  default = "Canada Central"   # ← Triggering the restriction
}
```

**Step 3:** Run `terraform plan`.

```bash
terraform plan
```

**Observed error:**

```
╷
│ Error: Resource precondition failed
│
│   on main.tf line 14, in resource "azurerm_resource_group" "rg":
│   14:       condition = lower(var.location) != "canada central"
│     ├────────────────
│     │ var.location is "Canada Central"
│
│ ERROR: Deployment to 'Canada Central' is not permitted by policy.
│ Please choose a different Azure region (e.g., 'East US', 'West Europe', 'Southeast Asia').
╵
```

Terraform stops at plan time — **before any Azure resource is touched** — and shows your exact custom error message. This is the power of `precondition`: it acts as a policy gate at the Terraform level.

### Making It More Robust — Blocking Multiple Regions

You can extend the condition to block multiple regions:

```hcl
lifecycle {
  precondition {
    condition = !contains(
      ["canada central", "canada east", "brazil south"],
      lower(var.location)
    )
    error_message = "ERROR: Deployment to Canada Central, Canada East, and Brazil South is restricted by data residency policy. Approved regions: East US, West Europe, Southeast Asia."
  }
}
```

### Using a `postcondition` — Validate After Creation

A `postcondition` validates the resource **after** it has been created. You reference the resource's actual attributes using `self`:

```hcl
resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_names[count.index]
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    postcondition {
      condition     = self.account_replication_type == "LRS"
      error_message = "Storage account must use LRS replication for cost compliance."
      # 'self' refers to the actual created resource — not the config values
    }
  }
}
```

---

## 7. Complete Working Example

### File Structure

```
day09/
├── provider.tf
├── variables.tf
├── main.tf
└── outputs.tf
```

---

### `provider.tf`

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}
```

---

### `variables.tf`

```hcl
variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-terraform-day09"
}

variable "location" {
  description = "Azure region. Note: Canada Central is blocked by precondition."
  type        = string
  default     = "East US"
  # To test the precondition, change this to "Canada Central"
}

variable "storage_account_names" {
  description = "List of storage account names for the create_before_destroy demo"
  type        = list(string)
  default     = ["storageacctday09a", "storageacctday09b"]
}

variable "protected_sa_name" {
  description = "Name of the prevent_destroy protected storage account"
  type        = string
  default     = "storageacctprotected9"
}
```

---

### `main.tf`

```hcl
# ─── Resource Group with ignore_changes and precondition ──────────────────────

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "dev"
    managed_by  = "terraform"
    day         = "09"
  }

  lifecycle {
    # LAB 3: ignore_changes
    # Terraform will not revert tag changes made outside of Terraform (e.g., Azure Portal).
    ignore_changes = [tags]

    # LAB 4: precondition — blocks deployment to Canada Central
    precondition {
      condition     = lower(var.location) != "canada central"
      error_message = "ERROR: Deployment to 'Canada Central' is not permitted. Please use an approved region (East US, West Europe, Southeast Asia)."
    }
  }
}

# ─── LAB 1: Storage Accounts with create_before_destroy ───────────────────────
#
# HOW TO TEST:
#   1. Apply with default names: ["storageacctday09a", "storageacctday09b"]
#   2. Change names to:          ["storageacctday09new", "storageacctday09b"]
#   3. Run terraform plan  → see the +/- replacement symbol
#   4. Run terraform apply → observe "Creating..." appears BEFORE "Destroying..."

resource "azurerm_storage_account" "cbd_sa" {
  count = length(var.storage_account_names)

  name                     = var.storage_account_names[count.index]
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    lifecycle_demo = "create_before_destroy"
  }

  lifecycle {
    # LAB 1: create_before_destroy
    create_before_destroy = true
    # When the name changes (forced replacement):
    #   STEP 1: New storage account is created first
    #   STEP 2: Old storage account is destroyed after
    # Without this, the old one would be destroyed first → temporary outage

    # LAB 4: precondition — also block Canada Central on storage accounts
    precondition {
      condition     = lower(var.location) != "canada central"
      error_message = "ERROR: Storage accounts cannot be deployed to 'Canada Central'. This region is restricted."
    }
  }
}

# ─── LAB 2: Storage Account with prevent_destroy ──────────────────────────────
#
# HOW TO TEST:
#   1. Apply to create the protected storage account
#   2. Try changing its name → terraform plan will FAIL with error
#   3. Try terraform destroy  → will FAIL with error
#   4. To actually destroy it, remove prevent_destroy = true first

resource "azurerm_storage_account" "protected_sa" {
  name                     = var.protected_sa_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    lifecycle_demo = "prevent_destroy"
    critical       = "true"
  }

  lifecycle {
    # LAB 2: prevent_destroy
    prevent_destroy = true
    # Any terraform plan or apply that would DESTROY this resource will fail.
    # This is a safety net for critical production resources.
    # To remove this resource, you MUST set prevent_destroy = false first.
  }
}
```

---

### `outputs.tf`

```hcl
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Location of the created resource group"
  value       = azurerm_resource_group.rg.location
}

output "cbd_storage_account_names" {
  description = "Names of the create_before_destroy storage accounts"
  value       = [for sa in azurerm_storage_account.cbd_sa : sa.name]
}

output "cbd_storage_account_ids" {
  description = "Resource IDs of the create_before_destroy storage accounts"
  value       = [for sa in azurerm_storage_account.cbd_sa : sa.id]
}

output "protected_storage_account_name" {
  description = "Name of the prevent_destroy protected storage account"
  value       = azurerm_storage_account.protected_sa.name
}

output "protected_storage_account_id" {
  description = "Resource ID of the prevent_destroy protected storage account"
  value       = azurerm_storage_account.protected_sa.id
}
```

---

## 8. Lifecycle Rules Quick Reference

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   TERRAFORM LIFECYCLE CHEAT SHEET                           │
├──────────────────────────┬──────────────────────────────────────────────────┤
│  create_before_destroy   │ When replacement is needed:                      │
│                          │   DEFAULT:  destroy old → create new             │
│                          │   WITH CBG: create new → destroy old             │
│                          │ Use for: zero-downtime replacements               │
├──────────────────────────┼──────────────────────────────────────────────────┤
│  prevent_destroy         │ Blocks all terraform destroy and plans that      │
│                          │ would destroy the resource.                      │
│                          │ Use for: critical production resources            │
│                          │ Note: must set = false before destroying         │
├──────────────────────────┼──────────────────────────────────────────────────┤
│  ignore_changes          │ Ignores specified attribute changes in future     │
│                          │ plans (changes made OUTSIDE Terraform).          │
│                          │ Use for: tags, attributes managed by Azure Policy │
│                          │ Syntax:  ignore_changes = [tags, name]           │
│                          │ All:     ignore_changes = all                    │
├──────────────────────────┼──────────────────────────────────────────────────┤
│  precondition            │ Validates BEFORE resource create/update.         │
│                          │ Fails at plan time if condition is false.        │
│                          │ Use for: policy enforcement, region restrictions  │
│                          │ Syntax:  condition + error_message               │
├──────────────────────────┼──────────────────────────────────────────────────┤
│  postcondition           │ Validates AFTER resource is created.             │
│                          │ Uses 'self' to reference actual resource values. │
│                          │ Use for: verifying created resource meets SLAs   │
└──────────────────────────┴──────────────────────────────────────────────────┘
```

### Combining Multiple Lifecycle Rules

All lifecycle rules can be combined in a single `lifecycle` block:

```hcl
lifecycle {
  create_before_destroy = true
  prevent_destroy       = true
  ignore_changes        = [tags]

  precondition {
    condition     = lower(var.location) != "canada central"
    error_message = "Canada Central is not permitted."
  }

  postcondition {
    condition     = self.account_replication_type == "LRS"
    error_message = "Must use LRS replication."
  }
}
```

---

## 9. Common Mistakes and How to Avoid Them

### Mistake 1: Expecting `prevent_destroy` to survive config removal

```hcl
# ❌ MISCONCEPTION:
# "I'll remove prevent_destroy from the code and Terraform will warn me before destroying"

# Reality: Once prevent_destroy is removed from the code, the resource
# is no longer protected. terraform destroy will work immediately.

# ✅ CORRECT WORKFLOW:
# Step 1: Remove prevent_destroy = true
# Step 2: terraform apply (update the state)
# Step 3: terraform destroy (now works)
# Never skip Step 2!
```

### Mistake 2: Thinking `ignore_changes` prevents your own code changes from applying

```hcl
# ❌ MISCONCEPTION:
lifecycle {
  ignore_changes = [name]
}
# "If I change the name in my .tf file, Terraform will ignore it"

# Reality: ignore_changes only ignores changes detected as DRIFT
# (changes made OUTSIDE Terraform). Your own code changes always apply.

# ✅ CORRECT UNDERSTANDING:
# ignore_changes = [name] means:
# "If the name was changed in Azure Portal/CLI outside of Terraform, don't try to revert it"
# It does NOT mean "ignore changes I make in my .tf files"
```

### Mistake 3: `create_before_destroy` doesn't help with same-name resources

```hcl
# ❌ PROBLEM:
# If old and new resource must have the same name (unique constraint),
# create_before_destroy will FAIL because:
# Step 1: Try to create new with same name → Azure rejects (name taken)

# ✅ SOLUTION:
# create_before_destroy only helps when the new resource has a DIFFERENT
# name/identifier than the old one. For same-name replacements, you
# must destroy first (default behavior) or use blue-green deployment strategies.
```

### Mistake 4: Using `ignore_changes = all` carelessly

```hcl
# ❌ DANGEROUS:
lifecycle {
  ignore_changes = all
  # Terraform will NEVER update this resource after creation.
  # Any drift, security misconfig, or policy violation is silently ignored.
}

# ✅ BETTER: Be specific about what to ignore
lifecycle {
  ignore_changes = [tags]  # Only ignore tag drift
}
```

### Mistake 5: Forgetting that `precondition` evaluates at plan time, not at variable definition

```hcl
# The precondition runs during terraform plan/apply, not when you define the variable.
# So you won't see the error until you actually run terraform plan.

# ✅ Always test your preconditions explicitly:
# 1. Set the variable to the forbidden value
# 2. Run terraform plan
# 3. Confirm the error message appears as expected
# 4. Reset the variable to a valid value
```

---

## Running Day 09 Labs

```bash
# Initialize
terraform init

# ── LAB 1: create_before_destroy ───────────────────────────────────────────
terraform apply                          # Initial creation
# Edit variables.tf → change storage_account_names[0]
terraform plan                           # Observe +/- replacement symbol
terraform apply                          # Watch "Creating..." before "Destroying..."

# ── LAB 2: prevent_destroy ─────────────────────────────────────────────────
# Edit variables.tf → change protected_sa_name
terraform plan                           # Observe the "cannot be destroyed" error
# Edit main.tf → set prevent_destroy = false
terraform plan                           # Now succeeds
terraform apply

# ── LAB 3: ignore_changes ──────────────────────────────────────────────────
terraform apply                          # Create resource group
# Add a tag in Azure Portal manually, then:
terraform plan                           # Should show "No changes" — tags ignored

# ── LAB 4: precondition ────────────────────────────────────────────────────
# Edit variables.tf → set location = "Canada Central"
terraform plan                           # Observe the custom error message
# Reset location to "East US"
terraform plan                           # Now succeeds

# ── Cleanup ────────────────────────────────────────────────────────────────
# First: set prevent_destroy = false in main.tf
terraform destroy                        # Remove all resources
```

---

*End of Day 09 — Terraform Lifecycle Rules with Azure Resources*