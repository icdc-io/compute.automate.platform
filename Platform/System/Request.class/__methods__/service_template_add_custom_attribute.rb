$evm.log(:info, "add_custom_attribute started")

id = $evm.root['dialog_service_template']
service_template = $evm.vmdb(:ServiceTemplate).find_by(id: id)
key = $evm.root['dialog_key']
value = $evm.root['dialog_value']

service_template.custom_set(key, value)
exit MIQ_OK
