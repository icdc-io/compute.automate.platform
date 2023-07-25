#
# Description: This method used for removing system's default group from interface and then assign assign account's private security group
#

def provision_object
  @provision_object ||= begin
    $evm.root['miq_provision_request'] ||
      $evm.root['miq_provision']         ||
      $evm.root['miq_provision_request_template']
  end
end

def account
  @account ||= begin
    t = provision_object.miq_request&.tenant
    t.present? && t.project? && t.account || t
  end
end

def location
  provision_object.region_description.downcase
end
  
def remove_from_port()
  vm=$evm.vmdb(:Vm).where("name like '%pt_sg_1%' and created_on > '2023-03-05'").last
  ns = vm.ext_management_system.network_manager.openstack_handle.detect_network_service
  nics = vm.hardware.nics
  nics.each do |nic|
    port = $evm.vmdb(:NetworkPort).where(:device_id => nic.id).first
    next unless port
    port_id = port.ems_ref
    $evm.log('info', "Removing default security group")
    # security_group.network_ports.delete($evm.vmdb(:NetworkPort).find_by(:ems_ref => port_id))
    ns.update_port(port_id, {:security_groups => []})
    $evm.log('info', "Removed default security group")
  end
end

def add_to_port(security_group)
  vm=$evm.vmdb(:Vm).where("name like '%pt_sg_1%' and created_on > '2023-03-05'").last
  ns = vm.ext_management_system.network_manager.openstack_handle.detect_network_service
  nics = vm.hardware.nics
  nics.each do |nic|
    port = $evm.vmdb(:NetworkPort).where(:device_id => nic.id).first
    next unless port
    port_id = port.ems_ref
    $evm.log('info', "Adding security group")
    # security_group.network_ports.push($evm.vmdb(:NetworkPort).find_by(:ems_ref => port_id))
    $evm.log('info', "#{security_group}")
    ns.update_port(port_id, {:security_groups => [security_group.ems_ref]})
    $evm.log('info', "Added security group")
    rescue RuntimeError => e
      next
  end
end
  
$evm.log('info', "Finding security groups")
new_group = $evm.vmdb(:SecurityGroup).find_by(:name => "zby_icdc_default") 
$evm.log('info', "Finding new security group")
unless new_group.nil?
  remove_from_port
  add_to_port(new_group)
else
  $evm.log(:error, "[ICDC] ERROR security group does not exist")
end
