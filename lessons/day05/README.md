## Task for Day05

- Using the files created in the previous task (day04), update them to use variables below
- Add an input variable named "environment" and set the default value to "staging"
- Create the terraform.tfvars file and set the environment value to demo
- Test the variable precedence by passing the variables in different ways: tfvars file, environment variables, default, etc.
- Create a local variable with a tag called common_tags with values as env=dev, lob=banking, stage=alpha, and use the local variable in the tags section of main.tf
- Create an output variable to print the storage account name

# Terraform Variables — Complete Guide (All in Markdown)

## 📌 Types of Variables in Terraform

Terraform has **3 types of variables**:

1. **Input Variables** (`variable`)
2. **Local Variables** (`locals`)
3. **Output Variables** (`output`)

---

# 1️⃣ Input Variables

## ✅ What are they?

Input variables are values that you **pass INTO Terraform from outside**.

They make configurations:

- Reusable
- Flexible
- Environment-specific

---

## ✅ Example

```hcl
variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

resource "azurerm_resource_group" "rg" {
  location = var.location
}
```

---

## 🧠 Think of them as

```
Function parameters
```

---

## ✅ Ways to Set Input Variables (Precedence)

Terraform resolves input variables using this order:

---

### 🥇 1. CLI Variables (Highest Priority)

```bash
terraform apply -var="location=West Europe"
```

---

### 🥈 2. `.tfvars` Files

Example: `terraform.tfvars`

```hcl
location = "Central India"
```

Automatically loaded if present.

---

### 🥉 3. Environment Variables

```bash
export TF_VAR_location="East US"
```

---

### 4️⃣ Default Value (Lowest Priority)

```hcl
variable "location" {
  default = "East US"
}
```

---

## 🎯 Input Variable Precedence Order

```
CLI > TFVARS > ENV > DEFAULT
```

---

---

# 2️⃣ Local Variables

## ✅ What are they?

Local variables are values defined **inside Terraform** for internal reuse.

They **cannot be overridden externally**.

---

## ✅ Example

```hcl
locals {
  prefix = "prod-app"
}

resource "azurerm_resource_group" "rg" {
  name = "${local.prefix}-rg"
}
```

---

## 🧠 Think of them as

```
Internal constants / helper variables
```

---

## ✅ Key Characteristics

- Used only within Terraform
- Cannot be changed externally
- Help avoid repetition
- Can compute values

---

## ❗ Important

Locals have **NO precedence** because they cannot be overridden.

---

---

# 3️⃣ Output Variables

## ✅ What are they?

Output variables display values **after Terraform apply**.

Used to expose resource information.

---

## ✅ Example

```hcl
output "rg_name" {
  value = azurerm_resource_group.rg.name
}
```

---

## ✅ Output Example After Apply

```
Outputs:

rg_name = demo-rg
```

---

## 🧠 Think of them as

```
Return values of Terraform
```

---

## ✅ Common Uses

- Display resource IDs
- Show IP addresses
- Share values between modules
- Provide connection info

---

## ❗ Important

Outputs:

- Do not accept input
- Have no precedence

---

---

# 4️⃣ Comparison Table

| Feature | Input Variables | Local Variables | Output Variables |
|--------|-----------------|----------------|------------------|
| Direction | Into Terraform | Internal | Out of Terraform |
| External Override | Yes | No | No |
| Purpose | Configure values | Reuse logic | Display results |
| Precedence Applies | Yes | No | No |

---

---

# 5️⃣ Complete Example (All Together)

```hcl
variable "environment" {
  default = "dev"
}

locals {
  prefix = "app-${var.environment}"
}

resource "azurerm_resource_group" "rg" {
  name     = local.prefix
  location = "East US"
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
```

---

## 🔄 Flow Explanation

```
Input Variable → Local Variable → Resource Creation → Output Variable
```

---

---

# 6️⃣ Visual Flow Diagram

```
User Input
   ↓
Input Variables
   ↓
Local Variables (internal logic)
   ↓
Resources Created
   ↓
Output Variables Displayed
```

---

---

# 7️⃣ Key Memory Summary

```
Input Variables = Parameters
Local Variables = Internal Constants
Output Variables = Return Values
```

---

---

# 8️⃣ Most Important Interview Point

Only **Input Variables** follow precedence rules.

Local and Output variables do NOT.
