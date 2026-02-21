# Day 08 — Terraform Loops: `count`, `for_each`, and `for` Expressions

> **Goal:** Learn how to use `count`, `for_each`, and `for` loops in Terraform to create multiple Azure Storage Accounts from a single resource block, and how to output their names/IDs using `for` expressions.

---

## Table of Contents

1. [Why Do We Need Loops in Terraform?](#1-why-do-we-need-loops-in-terraform)
2. [The Three Loop Mechanisms](#2-the-three-loop-mechanisms)
3. [Variable Types: list vs set](#3-variable-types-list-vs-set)
4. [Using `count` with a `list` Variable](#4-using-count-with-a-list-variable)
5. [Using `for_each` with a `set` Variable](#5-using-foreach-with-a-set-variable)
6. [Using `for` Loops in Output Variables](#6-using-for-loops-in-output-variables)
7. [Complete Working Example](#7-complete-working-example)
8. [count vs for_each — When to Use Which?](#8-count-vs-for_each--when-to-use-which)
9. [Common Mistakes and How to Avoid Them](#9-common-mistakes-and-how-to-avoid-them)

---

## 1. Why Do We Need Loops in Terraform?

Imagine you need to create 5 Azure Storage Accounts. Without loops, you'd write the same `resource` block 5 times — just with a different name each time. That's repetitive, hard to maintain, and violates the DRY (**D**on't **R**epeat **Y**ourself) principle.

**Without loops (bad approach):**
```hcl
resource "azurerm_storage_account" "sa1" {
  name                     = "mystorageaccount01"
  resource_group_name      = "my-rg"
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "sa2" {
  name                     = "mystorageaccount02"
  resource_group_name      = "my-rg"
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
# ... and so on for every single account
```

**With loops (good approach):**
```hcl
resource "azurerm_storage_account" "sa" {
  count                    = 2
  name                     = var.storage_account_names[count.index]
  resource_group_name      = "my-rg"
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

One block. Two (or more) resources. Clean, scalable, and maintainable.

---

## 2. The Three Loop Mechanisms

Terraform provides three distinct loop tools, and each serves a different purpose:

| Tool | Used In | Purpose |
|---|---|---|
| `count` | `resource`, `module` | Repeat a resource N times, indexed by integer |
| `for_each` | `resource`, `module` | Repeat a resource for each item in a map or set |
| `for` expression | `output`, `local`, `variable` | Transform or filter collections (like a list comprehension) |

Think of them this way:
- **`count`** = "create this resource **N** times"
- **`for_each`** = "create this resource **once for each item** in this collection"
- **`for`** = "transform this collection into a new collection" (not for creating resources)

---

## 3. Variable Types: list vs set

Before diving into `count` and `for_each`, you need to understand the variable types they work with.

### `list` Type

- An **ordered** sequence of values
- Allows **duplicate** values
- Elements are accessed by **index** (0, 1, 2, ...)
- Works with `count`

```hcl
variable "storage_account_names" {
  type    = list(string)
  default = ["storageacctdev01", "storageacctdev02"]
}
# Access: var.storage_account_names[0] => "storageacctdev01"
#         var.storage_account_names[1] => "storageacctdev02"
```

### `set` Type

- An **unordered** collection of **unique** values
- Does **not** allow duplicates (duplicates are automatically removed)
- Elements are **not** accessible by index
- Works with `for_each`

```hcl
variable "storage_account_names_set" {
  type    = set(string)
  default = ["storageacctprod01", "storageacctprod02"]
}
# No index access — you iterate with for_each
```

> **Key Insight:** Because a `set` is unordered and has no index, you cannot use `count` (which relies on index) with it. You must use `for_each`. Conversely, `for_each` requires a map or set — it will not accept a plain list directly (you'd have to convert it with `toset()`).

---

## 4. Using `count` with a `list` Variable

### How `count` Works

When you add `count = N` to a resource block, Terraform creates `N` instances of that resource. Each instance gets an automatically available meta-argument called `count.index`, which holds the current iteration number starting from **0**.

```
count = 2

Iteration 0 → count.index = 0
Iteration 1 → count.index = 1
```

You use `count.index` to pull the correct item out of your list variable:

```hcl
var.storage_account_names[count.index]
# When count.index = 0 → "storageacctdev01"
# When count.index = 1 → "storageacctdev02"
```

### Implementation

**`variables.tf`**
```hcl
variable "storage_account_names" {
  description = "List of storage account names to create using count"
  type        = list(string)
  default     = ["storageacctdev01", "storageacctdev02"]
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-terraform-day08"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}
```

**`main.tf` — Storage Accounts using `count`**
```hcl
resource "azurerm_storage_account" "count_sa" {
  count = length(var.storage_account_names)
  # length() returns the number of items in the list
  # So count = 2 for a list with 2 items

  name                     = var.storage_account_names[count.index]
  # count.index = 0 → "storageacctdev01"
  # count.index = 1 → "storageacctdev02"

  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

### What Terraform Creates Internally

Terraform tracks these as two separate state objects:

```
azurerm_storage_account.count_sa[0]  → name: "storageacctdev01"
azurerm_storage_account.count_sa[1]  → name: "storageacctdev02"
```

The bracket notation `[0]` and `[1]` is the count index. This is important to understand when referencing these resources elsewhere or when destroying them.

### Referencing count Resources

```hcl
# Reference a specific instance
azurerm_storage_account.count_sa[0].name  # "storageacctdev01"

# Reference all instances (returns a list)
azurerm_storage_account.count_sa[*].name  # ["storageacctdev01", "storageacctdev02"]
```

---

## 5. Using `for_each` with a `set` Variable

### How `for_each` Works

`for_each` iterates over a **map** or **set** and creates one resource instance per item. Instead of `count.index`, it provides two special values:

- `each.key` — the key of the current item (for a set, this is the same as the value)
- `each.value` — the value of the current item (for a set, same as the key)

```
for_each = toset(["storageacctprod01", "storageacctprod02"])

Iteration 1 → each.key = "storageacctprod01", each.value = "storageacctprod01"
Iteration 2 → each.key = "storageacctprod02", each.value = "storageacctprod02"
```

When iterating over a **set of strings**, `each.key` and `each.value` are always the same — they both equal the string itself.

### Implementation

**`variables.tf` addition**
```hcl
variable "storage_account_names_set" {
  description = "Set of storage account names to create using for_each"
  type        = set(string)
  default     = ["storageacctprod01", "storageacctprod02"]
}
```

**`main.tf` — Storage Accounts using `for_each`**
```hcl
resource "azurerm_storage_account" "foreach_sa" {
  for_each = var.storage_account_names_set
  # for_each accepts a set(string) directly
  # No need for toset() since the variable is already type = set(string)

  name                     = each.value
  # each.value = "storageacctprod01" (first iteration)
  # each.value = "storageacctprod02" (second iteration)

  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

> **Note:** If your variable is a `list(string)` and you want to use `for_each`, you must convert it: `for_each = toset(var.my_list)`. The `toset()` function converts a list to a set (removing duplicates and ordering).

### What Terraform Creates Internally

Terraform tracks these using the **value** as the key:

```
azurerm_storage_account.foreach_sa["storageacctprod01"]  → name: "storageacctprod01"
azurerm_storage_account.foreach_sa["storageacctprod02"]  → name: "storageacctprod02"
```

The bracket notation uses the actual string value — not a number. This is a major advantage over `count`: if you remove an item from the middle of your list with `count`, all the index numbers shift and Terraform may destroy and recreate resources unexpectedly. With `for_each`, each resource is identified by its **name**, so removing one item only removes that specific resource.

### Referencing for_each Resources

```hcl
# Reference a specific instance by key
azurerm_storage_account.foreach_sa["storageacctprod01"].name

# Reference all instance IDs (returns a map)
{ for k, v in azurerm_storage_account.foreach_sa : k => v.id }
```

---

## 6. Using `for` Loops in Output Variables

### What is a `for` Expression?

A `for` expression is not for creating resources — it's for **transforming collections**. It works like Python's list comprehensions or JavaScript's `.map()`. You use it inside `output` blocks, `locals`, and variable assignments.

### Basic `for` Syntax

```hcl
# List comprehension
[for item in collection : transform(item)]

# Map comprehension
{for key, value in collection : new_key => new_value}

# With a filter (if condition)
[for item in collection : transform(item) if condition]
```

### Output: Storage Account Names from `count` Resources

```hcl
output "count_sa_names" {
  description = "Names of all storage accounts created with count"
  value       = [for sa in azurerm_storage_account.count_sa : sa.name]
  # Iterates over each instance of count_sa and builds a list of names
  # Result: ["storageacctdev01", "storageacctdev02"]
}
```

### Output: Storage Account IDs from `count` Resources

```hcl
output "count_sa_ids" {
  description = "IDs of all storage accounts created with count"
  value       = [for sa in azurerm_storage_account.count_sa : sa.id]
  # Result: ["/subscriptions/.../storageacctdev01", "/subscriptions/.../storageacctdev02"]
}
```

### Output: Storage Account Names from `for_each` Resources

```hcl
output "foreach_sa_names" {
  description = "Names of all storage accounts created with for_each"
  value       = [for sa in azurerm_storage_account.foreach_sa : sa.name]
  # Iterates over the map of for_each instances and extracts names
  # Result: ["storageacctprod01", "storageacctprod02"] (order not guaranteed — it's a set)
}
```

### Output: A Map of Name → ID

```hcl
output "foreach_sa_name_to_id" {
  description = "Map of storage account name to its Azure resource ID"
  value       = { for key, sa in azurerm_storage_account.foreach_sa : key => sa.id }
  # Result:
  # {
  #   "storageacctprod01" = "/subscriptions/.../storageacctprod01"
  #   "storageacctprod02" = "/subscriptions/.../storageacctprod02"
  # }
}
```

### Output: Using the Splat Operator (`[*]`) — Alternative to `for`

For `count`-based resources, Terraform also offers a shorthand called the **splat operator**:

```hcl
output "count_sa_names_splat" {
  description = "Names using splat operator (shorthand for for loop)"
  value       = azurerm_storage_account.count_sa[*].name
  # Equivalent to: [for sa in azurerm_storage_account.count_sa : sa.name]
}
```

> **Note:** The splat operator `[*]` only works with `count`-based resources. For `for_each` resources, you must use the `for` expression.

---

## 7. Complete Working Example

Here is the full, working set of Terraform files for Day 08.

### File Structure

```
day08/
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
# ─── Resource Group & Location ─────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-terraform-day08"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

# ─── For count: list type ──────────────────────────────────────────────────────
# list(string): ordered, allows duplicates, accessed by index
# Used with count meta-argument

variable "storage_account_names" {
  description = "List of storage account names — used with count"
  type        = list(string)
  default     = ["storageacctdev01", "storageacctdev02"]

  validation {
    condition = alltrue([
      for name in var.storage_account_names :
      length(name) >= 3 && length(name) <= 24 && can(regex("^[a-z0-9]+$", name))
    ])
    error_message = "Storage account names must be 3-24 characters, lowercase letters and numbers only."
  }
}

# ─── For for_each: set type ────────────────────────────────────────────────────
# set(string): unordered, unique values only, no index access
# Used with for_each meta-argument

variable "storage_account_names_set" {
  description = "Set of storage account names — used with for_each"
  type        = set(string)
  default     = ["storageacctprod01", "storageacctprod02"]
}
```

---

### `main.tf`

```hcl
# ─── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# ─── Storage Accounts using COUNT ─────────────────────────────────────────────
#
# HOW IT WORKS:
#   count = length(var.storage_account_names) → count = 2
#
#   Terraform creates:
#     azurerm_storage_account.count_sa[0]  (name = "storageacctdev01")
#     azurerm_storage_account.count_sa[1]  (name = "storageacctdev02")
#
#   count.index gives us 0, then 1
#   We use it to index into the list: var.storage_account_names[count.index]

resource "azurerm_storage_account" "count_sa" {
  count = length(var.storage_account_names)

  name                     = var.storage_account_names[count.index]
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "dev"
    created_by  = "count-loop"
    index       = count.index
  }
}

# ─── Storage Accounts using FOR_EACH ──────────────────────────────────────────
#
# HOW IT WORKS:
#   for_each = var.storage_account_names_set
#   (var type is set(string), so for_each accepts it directly)
#
#   Terraform creates:
#     azurerm_storage_account.foreach_sa["storageacctprod01"]
#     azurerm_storage_account.foreach_sa["storageacctprod02"]
#
#   each.key   = the set element (e.g., "storageacctprod01")
#   each.value = same as each.key for a set of strings

resource "azurerm_storage_account" "foreach_sa" {
  for_each = var.storage_account_names_set

  name                     = each.value
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "prod"
    created_by  = "for-each-loop"
    sa_key      = each.key
  }
}
```

---

### `outputs.tf`

```hcl
# ─── Outputs for COUNT-based Storage Accounts ─────────────────────────────────

# Output: List of names using for expression
output "count_sa_names" {
  description = "Names of storage accounts created via count (using for expression)"
  value       = [for sa in azurerm_storage_account.count_sa : sa.name]
  # for expression syntax: [for <item> in <collection> : <transform>]
  # Produces: ["storageacctdev01", "storageacctdev02"]
}

# Output: List of IDs using for expression
output "count_sa_ids" {
  description = "Azure Resource IDs of storage accounts created via count"
  value       = [for sa in azurerm_storage_account.count_sa : sa.id]
  # Produces: ["/subscriptions/xxx/.../storageacctdev01", ...]
}

# Output: Names using splat operator (alternative to for loop)
output "count_sa_names_splat" {
  description = "Names using splat operator — shorthand equivalent to the for expression above"
  value       = azurerm_storage_account.count_sa[*].name
  # [*] is the splat operator: expands all instances and extracts .name
  # Only works for count-based resources
}

# ─── Outputs for FOR_EACH-based Storage Accounts ──────────────────────────────

# Output: List of names using for expression
output "foreach_sa_names" {
  description = "Names of storage accounts created via for_each (using for expression)"
  value       = [for sa in azurerm_storage_account.foreach_sa : sa.name]
  # for expression works the same way — iterates over the map of instances
  # Produces: ["storageacctprod01", "storageacctprod02"] (unordered — it's a set)
}

# Output: List of IDs using for expression
output "foreach_sa_ids" {
  description = "Azure Resource IDs of storage accounts created via for_each"
  value       = [for sa in azurerm_storage_account.foreach_sa : sa.id]
}

# Output: Map of name → ID using for map expression
output "foreach_sa_name_to_id_map" {
  description = "Map of storage account name to its Azure Resource ID"
  value       = { for key, sa in azurerm_storage_account.foreach_sa : key => sa.id }
  # Map comprehension syntax: { for <key>, <value> in <map> : <new_key> => <new_value> }
  # Produces:
  # {
  #   "storageacctprod01" = "/subscriptions/xxx/.../storageacctprod01"
  #   "storageacctprod02" = "/subscriptions/xxx/.../storageacctprod02"
  # }
}

# ─── Combined Output ───────────────────────────────────────────────────────────

# Output: All storage account names (both count and for_each) combined
output "all_storage_account_names" {
  description = "Combined list of all storage account names created in this config"
  value = concat(
    [for sa in azurerm_storage_account.count_sa : sa.name],
    [for sa in azurerm_storage_account.foreach_sa : sa.name]
  )
  # concat() merges two lists into one
  # Produces: ["storageacctdev01", "storageacctdev02", "storageacctprod01", "storageacctprod02"]
}
```

---

## 8. `count` vs `for_each` — When to Use Which?

| Scenario | Use `count` | Use `for_each` |
|---|---|---|
| You just need N identical resources | ✅ Yes | ✗ Overkill |
| Resources are identified by name/key | ✗ Risky | ✅ Yes |
| You have a `list(string)` variable | ✅ Natural | Requires `toset()` |
| You have a `set(string)` variable | ✗ Can't use | ✅ Natural |
| You have a `map(string)` variable | ✗ Can't use | ✅ Natural |
| You may remove items from the middle | ✗ Dangerous | ✅ Safe |
| You need `each.key` / `each.value` | ✗ Not available | ✅ Yes |

### The "Index Shift" Problem with `count`

This is the most important reason to prefer `for_each` when resources have meaningful names:

```hcl
# Suppose you have: ["alpha", "beta", "gamma"]
# count creates:
#   [0] = alpha
#   [1] = beta
#   [2] = gamma

# You remove "beta" → list becomes ["alpha", "gamma"]
# count now creates:
#   [0] = alpha      ← unchanged
#   [1] = gamma      ← was index 2, now index 1 → DESTROY & RECREATE!
```

With `for_each`, resources are keyed by name. Removing `"beta"` only destroys `beta`. `gamma` is untouched.

---

## 9. Common Mistakes and How to Avoid Them

### Mistake 1: Using `for_each` with a `list` directly

```hcl
# ❌ WRONG — for_each does not accept list(string)
variable "names" {
  type    = list(string)
  default = ["acc01", "acc02"]
}

resource "azurerm_storage_account" "sa" {
  for_each = var.names  # Error: for_each requires a map or set
  ...
}

# ✅ CORRECT — convert to set first
resource "azurerm_storage_account" "sa" {
  for_each = toset(var.names)
  ...
}
```

### Mistake 2: Trying to use `count.index` with `for_each`

```hcl
# ❌ WRONG — count.index is not available when using for_each
resource "azurerm_storage_account" "sa" {
  for_each = var.storage_account_names_set
  name     = var.storage_account_names[count.index]  # Error!
}

# ✅ CORRECT — use each.value
resource "azurerm_storage_account" "sa" {
  for_each = var.storage_account_names_set
  name     = each.value
}
```

### Mistake 3: Invalid Storage Account Names

Azure Storage Account names must be:
- 3 to 24 characters long
- Lowercase letters and numbers only
- Globally unique across all of Azure

```hcl
# ❌ WRONG names
default = ["My-Storage-Account", "sa", "storage account with spaces"]

# ✅ CORRECT names
default = ["storageacctdev01", "storageacctdev02"]
```

### Mistake 4: Forgetting that `for_each` with a set has no guaranteed order

```hcl
# Sets are unordered — you cannot rely on the order of iteration
variable "names" {
  type    = set(string)
  default = ["zzz", "aaa", "mmm"]
}
# for_each may iterate in any order
# This is fine for creating resources, but don't rely on order in outputs
```

### Mistake 5: Using `[*]` splat with `for_each` resources

```hcl
# ❌ WRONG — splat [*] does not work with for_each resources
output "names" {
  value = azurerm_storage_account.foreach_sa[*].name  # Error!
}

# ✅ CORRECT — use for expression
output "names" {
  value = [for sa in azurerm_storage_account.foreach_sa : sa.name]
}
```

---

## Quick Reference Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TERRAFORM LOOP CHEAT SHEET                       │
├──────────────┬──────────────────────────────────────────────────────┤
│  count       │ Works with: list(string)                             │
│              │ Access current item: var.mylist[count.index]         │
│              │ State key: resource.name[0], resource.name[1]        │
│              │ Reference all: resource.name[*].attr                 │
├──────────────┼──────────────────────────────────────────────────────┤
│  for_each    │ Works with: set(string), map(string)                 │
│              │ Access current item: each.value (or each.key)        │
│              │ State key: resource.name["item_name"]                │
│              │ Reference all: [for k,v in resource.name : v.attr]   │
├──────────────┼──────────────────────────────────────────────────────┤
│  for expr    │ Used in: output, locals, variable defaults           │
│              │ List result: [for x in col : x.attr]                 │
│              │ Map result: {for k,v in col : k => v.attr}           │
│              │ With filter: [for x in col : x.attr if condition]    │
└──────────────┴──────────────────────────────────────────────────────┘
```

---

## Running the Code

```bash
# Step 1: Initialize Terraform and download providers
terraform init

# Step 2: Preview what Terraform will create
terraform plan

# Step 3: Apply — create the actual Azure resources
terraform apply

# Step 4: View outputs
terraform output

# Step 5: Destroy all resources when done
terraform destroy
```

After `terraform apply`, your output will look something like:

```
count_sa_ids = [
  "/subscriptions/xxx/resourceGroups/rg-terraform-day08/providers/Microsoft.Storage/storageAccounts/storageacctdev01",
  "/subscriptions/xxx/resourceGroups/rg-terraform-day08/providers/Microsoft.Storage/storageAccounts/storageacctdev02",
]
count_sa_names = [
  "storageacctdev01",
  "storageacctdev02",
]
foreach_sa_name_to_id_map = {
  "storageacctprod01" = "/subscriptions/xxx/.../storageacctprod01"
  "storageacctprod02" = "/subscriptions/xxx/.../storageacctprod02"
}
foreach_sa_names = [
  "storageacctprod01",
  "storageacctprod02",
]
```

---

*End of Day 08 — Terraform Loops with Azure Storage Accounts*