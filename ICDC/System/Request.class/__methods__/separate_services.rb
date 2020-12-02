p_service = $evm.root['service']
if $evm.root['dialog_service_id'] != "all"
  id = $evm.root['dialog_service_id']
  service = $evm.vmdb(:service).find_by(:id => id)
  service.parent_service = nil
  if p_service.all_service_children.blank?
    $evm.instantiate("/Service/Retirement/StateMachines/ServiceRetirement/Default")
    p_service.remove_from_vmdb
  end
else
  p_service.all_service_children.each do |child_service|
    child_service.parent_service = nil
  end
  p_service.remove_from_vmdb
  $evm.instantiate("/Service/Retirement/StateMachines/ServiceRetirement/Default")
end
