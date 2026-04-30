# 🤖 Platform — ManageIQ Automate Domain

The **Platform** repository contains a ManageIQ **Automate domain** that is maintained as code (methods, dialogs, buttons, tags, reports, schedules) and can be synchronized with a ManageIQ environment using `rake` tasks.

---

## 🚀 Overview

### 📦 What's included
- 🧩 **Automate code** — `Platform/`
- 🗂️ **Service dialogs** — `service_dialogs/`
- 🧷 **Custom buttons** — `custom_buttons/`
- 🧱 **Generic objects** — `generic_object_definitions/`
- 🏷️ **Tags** — `tags/`
- 📊 **Reports** — `reports/`
- 🕒 **Schedules** — `schedules/`

---

## ✅ Requirements

- A running **ManageIQ** environment.
- Access to the ManageIQ Rails app directory (typically `vmdb`) with `rake` available.
- Repository content present on the target system (copied or mounted).
- The filesystem paths in commands below are **examples** and may differ in your environment.

---

## ⚙️ Import to environment

Import the **Automate domain** from this repository into ManageIQ:

```bash
cd /var/www/miq/vmdb
rake evm:automate:import DOMAIN=Platform IMPORT_DIR=/opt/manageiq/automation/platform OVERWRITE=true ENABLED=true
```

> This command imports only the Automate domain (`Platform/`). Import related artifacts as needed:

### 🗂️ Service dialogs

```bash
cd /var/www/miq/vmdb
rake evm:import:service_dialogs -- --source=/opt/manageiq/automation/platform/service_dialogs
```

### 🧷 Custom buttons

```bash
cd /var/www/miq/vmdb
rake evm:import:custom_buttons -- --source=/opt/manageiq/automation/platform/custom_buttons
```

### 🧱 Generic object definitions

```bash
cd /var/www/miq/vmdb
rake evm:import:generic_object_definitions -- --source=/opt/manageiq/automation/platform/generic_object_definitions
```

### 📊 Reports

```bash
cd /var/www/miq/vmdb
rake evm:import:reports -- --source=/opt/manageiq/automation/platform/reports
```

### 🕒 Schedules

```bash
cd /var/www/miq/vmdb
rake evm:import:schedules -- --source=/opt/manageiq/automation/platform/schedules
```

### 🏷️ Tags

```bash
cd /var/www/miq/vmdb
rake evm:import:tags -- --source=/opt/manageiq/automation/platform/tags
```

---

## 📤 Export from environment back to repository

Export the **Automate domain** from ManageIQ back into this repository:

```bash
# Export may leave old files for renamed instances/methods — clean the domain folder first.
cd /opt/manageiq/automation/platform
rm -rf Platform

cd /var/www/miq/vmdb
rake evm:automate:export DOMAIN=Platform EXPORT_DIR=/opt/manageiq/automation/platform
```

> The sections below show how to export related artifacts into this repository. Review and commit changes carefully.

### 🗂️ Service dialogs

```bash
rake evm:export:service_dialogs -- --directory=/opt/manageiq/automation/platform/service_dialogs
```

> Note: this task may export dialogs not related to this domain. Review changes and commit only what is intended.

### 🧷 Custom buttons

```bash
cd /var/www/miq/vmdb
rake evm:export:custom_buttons -- --directory=/opt/manageiq/automation/platform/custom_buttons
```

### 🧱 Generic object definitions

```bash
cd /var/www/miq/vmdb
rake evm:export:generic_object_definitions -- --directory=/opt/manageiq/automation/platform/generic_object_definitions
```

> Note: this task exports **all** generic object definitions from the environment. Commit only what belongs in this repository.

### 📊 Reports

```bash
cd /var/www/miq/vmdb
rake evm:export:reports -- --directory=/opt/manageiq/automation/platform/reports
```

### 🕒 Schedules

```bash
cd /var/www/miq/vmdb
rake evm:export:schedules -- --directory=/opt/manageiq/automation/platform/schedules
```

### 🏷️ Tags

```bash
cd /var/www/miq/vmdb
rake evm:export:tags -- --directory=/opt/manageiq/automation/platform/tags
```

#### ⚠️ Important note

The tags export includes **all** definitions. Recommended workflow:

1. Do not run `git add .`
2. Add/commit only required definitions
3. If needed, delete unrelated exports: `rm -rf tags/*`
4. Restore required files: `git restore tags`

---

## 📄 License

This project is licensed under the MIT License. See [`LICENSE`](./LICENSE).
