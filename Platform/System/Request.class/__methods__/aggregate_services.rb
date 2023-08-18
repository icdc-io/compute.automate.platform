service1 = $evm.root['service'].root_service
to_srv = $evm.root['dialog_merge_id']
bundle_name = $evm.root['dialog_new_name']
service2 = $evm.vmdb(:service).find_by(:id => to_srv).root_service
$evm.log(:info, "Start aggregate #{service1.id} and #{service2.id} ")

template_id = $evm.vmdb(:ServiceTemplate).where("name like ?", "Clone Service%").first.id

if bundle_name.empty?
  bundle_name = service1.name.to_s + " bundle"
end
if service1.all_service_children.present?
  if service2.all_service_children.blank?
    service2.parent_service = service1
    exit MIQ_OK
  end
end
if service1.all_service_children.blank?
  if service2.all_service_children.present?
    service1.parent_service = service2
    exit MIQ_OK
  end
end
if service1.all_service_children.present?
  if service2.all_service_children.present?
    new_service = $evm.vmdb('service').create(:name => bundle_name)
    new_service.display = true
    new_service.description = "Bundle service #{service1.name} and #{service2.name}"
    # Template id = id Empty Service Template
    new_service[:service_template_id] = template_id
    owner = $evm.vmdb(:user).find_by(:id => service1.evm_owner_id)
    new_service.owner = owner if owner
    new_service.group = owner.current_group if owner
    service1.all_service_children.each do |child_service1|
      child_service1.parent_service = new_service
    end
    service2.all_service_children.each do |child_service2|
      child_service2.parent_service = new_service
    end
    service1.root_service.retire_now
    sleep 10
    service2.root_service.retire_now
    sleep 10
    $evm.instantiate("/Service/Retirement/StateMachines/ServiceRetirement/Default")
    exit MIQ_OK
  end
end
if service1.all_service_children.blank?
  if service2.all_service_children.blank?
    new_service = $evm.vmdb('service').create(:name => bundle_name)
    new_service.display = true
    new_service.description = "Bundle service #{service1.name} and #{service2.name}"
    # Template id = id Empty Service Template
    new_service[:service_template_id] = template_id
    owner = $evm.vmdb(:user).find_by(:id => service1.evm_owner_id)
    new_service.owner = owner if owner
    new_service.group = owner.current_group if owner
    service1.parent_service = new_service
    service2.parent_service = new_service
    exit MIQ_OK
  end
end
