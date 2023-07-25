# Platform

Shared automation not included in other automation packages.

## Import code from repository to DEV environment

```bash
cd /var/www/miq/vmdb
rake evm:automate:import DOMAIN=Platform IMPORT_DIR=/opt/manageiq/automation/platform OVERWRITE=true ENABLED=true
```

After import fresh automation code you must import service dialogs and customization buttons.


## Export code from DEV environment info repository

```bash
# Remove old template provisioning, as export leaves old files for renamed instances and methods in repository.
cd /opt/manageiq/automation/platform
rm -rf Platform
# Import new
cd /var/www/miq/vmdb
rake evm:automate:export DOMAIN=Platform EXPORT_DIR=/opt/manageiq/automation/platform
```

Export service dialogs:
 - as it exports all dialogs then remove not related dialogs and commit carefully only those which ready for production

```bash
rake evm:export:service_dialogs -- --directory=/opt/manageiq/automation/platform/service_dialogs
```

Export customization templates:

```bash
vmdb
rake evm:export:customization_templates -- --directory=/opt/manageiq/automation/platform/customization_templates
```

Export tags and prepare commit:
 - as it exports all tags, so remove extra tags not related to template-provision

```bash
vmdb
rake evm:export:tags -- --directory=/opt/manageiq/automation/platform/tags
```

TODO: export buttons

