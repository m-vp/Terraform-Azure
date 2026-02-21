## Task for Day07

### Using the files from previous task(day06) , understand the use the below type constraints

- Name: environment, type=string
- Name: storage-disk, type=number
- Name: is_delete, type=boolean
- Name: Allowed_locations, type=list(string)
- Name: resource_tags , type=map(string)
- Name: network_config , type=tuple([string, string, number])
- Name: allowed_vm_sizes, type=list(string)
- Name: vm_config,
```
  type = object({
    size         = string
    publisher    = string
    offer        = string
    sku          = string
    version      = string
  })
```

### accessing ele from a list

'''
element(list, index)
element(["dev", "test", "prod"], 1)
'''

### concatinating string and variables
 
'''
${} is used
${var.env}-rg 
this will help terraform decide which part is variable and which one is string
'''

# Azure VM Terraform Blocks — Explanation

This document explains the purpose of the following Terraform blocks used in an Azure Virtual Machine configuration:

* `storage_image_reference`
* `storage_os_disk`
* `os_profile`

These blocks define:

* 🖥️ Which Operating System the VM uses
* 💾 How the VM disk is created
* 👤 How you log into the VM

---

## 1️⃣ `storage_image_reference` — VM Operating System

### ✅ Purpose

This block tells Azure **which OS image** to use when creating the VM.

Think of it like choosing Windows/Linux when installing an OS on a new computer.

### Example

```hcl
storage_image_reference {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = var.vm_config.sku
  version   = var.vm_config.version
}
```

### Field Explanation

#### `publisher`

Company providing the OS image.

Example:

```
Canonical = Ubuntu provider
```

---

#### `offer`

The OS product family.

Example:

```
0001-com-ubuntu-server-jammy = Ubuntu Server 22.04 LTS
```

---

#### `sku`

Specific OS edition.

Typical values:

* `22_04-lts`
* `minimal`
* `gen2`

Here it is coming from a variable:

```
var.vm_config.sku
```

---

#### `version`

Specifies image version.

Most common:

```
latest
```

Azure automatically selects the newest version.

---

### ✔️ Simple Meaning

This block means:

> “Create the VM using Ubuntu Linux from Azure Marketplace.”

---

## 2️⃣ `storage_os_disk` — VM OS Disk

### ✅ Purpose

Defines how the VM’s **main hard disk** is created.

This is similar to choosing:

* Disk size
* SSD vs HDD
* Performance level

---

### Example

```hcl
storage_os_disk {
  name              = "myosdisk1"
  caching           = "ReadWrite"
  create_option     = "FromImage"
  managed_disk_type = "Standard_LRS"
  disk_size_gb      = var.storage_disk
}
```

---

### Field Explanation

#### `name`

Name of the disk resource in Azure.

---

#### `caching`

Disk caching mode for performance.

Common value:

```
ReadWrite
```

---

#### `create_option`

How disk is created.

```
FromImage = created from OS image
```

---

#### `managed_disk_type`

Disk performance tier.

| Type         | Meaning          |
| ------------ | ---------------- |
| Standard_LRS | Cheap HDD        |
| Premium_LRS  | SSD              |
| UltraSSD     | High performance |

---

#### `disk_size_gb`

Size of OS disk in GB.

Here it uses:

```
var.storage_disk
```

---

### ✔️ Simple Meaning

This block means:

> “Create a managed OS disk of specified size and type.”

---

## 3️⃣ `os_profile` — VM Login Configuration

### ✅ Purpose

Defines the **administrator login settings** for the VM.

---

### Example

```hcl
os_profile {
  computer_name  = "hostname"
  admin_username = "testadmin"
  admin_password = "Password1234!"
}
```

---

### Field Explanation

#### `computer_name`

Hostname inside the OS.

---

#### `admin_username`

Username used to log into the VM.

Example SSH login:

```
ssh testadmin@vm-ip
```

---

#### `admin_password`

Password for login.

⚠️ In real projects, never hardcode passwords.

Use:

* Variables
* Key Vault
* SSH keys

---

### ✔️ Simple Meaning

This block means:

> “Create an admin user with login credentials for the VM.”

---

## 🧠 Big Picture — How These Blocks Work Together

When Terraform creates a VM:

```
1️⃣ storage_image_reference → Select OS
2️⃣ storage_os_disk → Configure disk
3️⃣ os_profile → Set login credentials
```

---

## 🏗️ Real-World Analogy

Creating a VM is like buying a laptop:

| Step                    | Terraform Block         |
| ----------------------- | ----------------------- |
| Choose Operating System | storage_image_reference |
| Choose Hard Disk        | storage_os_disk         |
| Set Login Password      | os_profile              |

---

## 🎯 One-Line Summary

These Terraform blocks define:

* The VM operating system image
* The configuration of the OS disk
* The administrator login settings

---

## 🔐 Best Practice Notes

* Never store passwords in code
* Use variables or secrets management
* Prefer SSH keys for Linux VMs
* Use Premium SSD for production workloads

---

## 🚀 Next Topics to Learn

Recommended next concepts:

* Network interfaces in Azure VM Terraform
* SSH key configuration (`os_profile_linux_config`)
* Managed vs unmanaged disks
* Secure secret handling in Terraform
