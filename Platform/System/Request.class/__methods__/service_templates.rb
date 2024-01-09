$evm.object['values'] = $evm.root['ext_management_system'].tenant.children.collect(&:service_templates).flatten.map { |t| {t.id => t.name} }.inject(&:merge)
$evm.object['data_type'] = 'string'
