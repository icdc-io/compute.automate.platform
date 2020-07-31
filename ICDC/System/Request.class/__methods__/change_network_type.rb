#
# Description: switch vm to a new VLAN
# Developer: ahrechushkin@ibagroup.eu 31.07.2020
#
require 'ovirtsdk4'
def change_network_type_redhat(vm)
  connection = vm.ext_management_system.connect
  new_vlan = $evm.root['dialog_network_profile']
  nic_id = connection.system_service.vms_service.vm_service(vm.uid_ems).nics_service.list.first.id
  new_nic_id = connection.system_service.vnic_profiles_service.list.select { |x| x.name == new_vlan }.first.id
  exit MIQ_OK if nic_id == new_nic_id
  connection.system_service.vms_service.vm_service(vm.uid_ems).shutdown
  sleep 25
  begin
    connection.system_service.vms_service.vm_service(vm.uid_ems).nics_service.nic_service(nic_id).update(:vnic_profile => {:id => new_nic_id})
  rescue
    sleep 15
    retry
  end
  connection.system_service.vms_service.vm_service(vm.uid_ems).start
end

def change_network_type_power(vm)
  raise NotImplementedError
end

service = $evm.root['service']
service.vms.each do |vm|
  vendor = vm.vendor
  case vendor
  when "redhat"
    change_network_type_redhat(vm)
  when "power_systems"
    change_network_type_power(vm)
  end
end
