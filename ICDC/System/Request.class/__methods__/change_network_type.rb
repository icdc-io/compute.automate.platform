#
# Description: switch vm to a new VLAN
# Developer: ahrechushkin@ibagroup.eu 31.07.2020
#
require '/var/www/miq/vmdb/lib/icdc/network.rb'
require 'ovirtsdk4'
def change_network_type_redhat(vm)
  ip_before_change = vm.ipaddresses.first
  hostname = vm.hostnames.first
  remove_dns_record(hostname)
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
  update_dns_record(hostname, ip_before_change)
  send_email
end

def remove_dns_record(hostname)
  @skyDNS = Etcd.new
  @skyDNS.remove_A(hostname)
rescue => e
  $evm.log(:warn, "Can't remove DNS record cause #{e.message}")
end

def update_dns_record(hostname, ip_before_change)
  service = $evm.root['service']
  4.times do 
    ips_length = service.networks.collect(&:allocations).flatten.collect(&:ip).length
    sleep 30
    if ips_length > 3
      new_ip = service.networks.collect{|n| n.allocations}.flatten.select{|curr| curr.type == :guest}.first.ip
      
       if new_ip != ip_before_change
         @skyDNS = Etcd.new
         @skyDNS.set_A(hostname, new_ip, ttl = 600)
         break
       end
    end
  end
rescue => e
  $evm.log(:warn, "Can't update DNS record cause #{e.message}")
end

def remove_dns_record(hostname)
  @skyDNS = Etcd.new
  @skyDNS.remove_A(hostname)
end

def update_dns_record(hostname, ip_before_change)
  service = $evm.root['service']
  4.times do 
    ips_length = service.networks.collect(&:allocations).flatten.collect(&:ip).length
    sleep 30
    if ips_length > 3
      new_ip = service.networks.collect{|n| n.allocations}.flatten.select{|curr| curr.type == :guest}.first.ip
      
       if new_ip != ip_before_change
         @skyDNS = Etcd.new
         @skyDNS.set_A(hostname, new_ip, ttl = 600)
         break
       end
    end
  end
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
