list = {}
$evm.root['ext_management_system'].tenant.service_templates.each { |service_template| list[service_template.id] = service_template.name }
$evm.object['values'] = list
$evm.object["data_type"] = "string"
