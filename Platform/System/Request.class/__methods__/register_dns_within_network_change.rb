require 'bundler'
Bundler.setup(:default)
require 'resolv'
require 'coredns'

def update_dns_record(vm)
  init_environment(vm)
  return if @hostname == "n/a" || !@hostname
  remove_dns_record
  create_dns_record
  send_email unless $evm.root['ae_result'] == 'retry'
end

def init_environment(vm)
  @ip_before_change = vm.ipaddresses.first
  @vm = $evm.root['vm'] = vm
  @hostname = (@vm.hostnames.first || (ip_map[@vm.id] || []).collect(&:hostname).compact.first).downcase
  @location = @vm.miq_provision.region_description.downcase
  @account = account
  ip
end  
  
def remove_dns_record
  name_to_delete = CoreDns::Etcd.new("etcd.dns.#{@location}.icdc.io").domain(@hostname).list.select{|x| x["host"] == @ip_before_change}[0]["name"]
  CoreDns::Etcd.new("etcd.dns.#{@location}.icdc.io").domain(@hostname).delete({"name" => name_to_delete})
rescue => e
  $evm.log(:warn, "Can't remove DNS record cause #{e.message}")
end

def create_dns_record
  if @hostname.split('.').first == "@" || @hostname.split('.').first == ""
    domain = "apex.dns.#{@location}"
  elsif @hostname
    domain = @hostname
  end
  return unless check_domain_length(domain, @hostname.split('.').first) && @ip_a &&
                CoreDns::Etcd.new("etcd.dns.#{@location}.icdc.io").domain(domain).list.select{|x| x["host"] == @ip_a}.empty?
  CoreDns::Etcd.new("etcd.dns.#{@location}.icdc.io").domain(domain).add({:host => @ip_a, :ttl => 600, :group => domain,
                                                                                       :metadata => {:account => @account.name.downcase, :owner => @vm.evm_owner.userid}})
rescue => e
  $evm.log(:warn, "Can't create DNS record cause #{e.message}")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = 1.minute
end
    
def account
   tenant = $evm.vmdb(:User).find_by(:userid => @vm.evm_owner.userid).current_tenant
   tenant.project? && tenant.account || tenant
end

def check_domain_length(domain, name)
  valid = true
  $evm.log(:warn,"UN Name #{name} can't be more than 63 symbols") && (valid = false ) if name && name.length > 63
  $evm.log(:warn,"UN Domain #{domain} length can't be more than 250 symbols") && (valid = false ) if domain.length > 250
  valid
end

def ip
  network_manager = @vm.ext_management_system.try(:network_manager)
  nics = @vm.hardware.nics
  @ip_a = nil
  if network_manager && nics.reject{|nic| nic.lan&.name}.present?
    network_manager.refresh
  else
    nics.each do |nic|
      cloud_network = $evm.vmdb(:CloudNetwork).find_by(:name => nic.lan.name)
      next unless cloud_network
      port = cloud_network.network_ports.detect{|np| np.device&.id == nic.id}
      @ip_a = port.ipaddresses.first if port&.ipaddresses
      break if @ip_a && @ip_a != '' && (nic.lan.name == $evm.root['dialog_network_profile'])
      if @ip_a == @ip_before_change
        network_manager.refresh
        @ip_a = nil
      end
    end
  end
  unless @ip_a && @ip_a != '' && @hostname && @hostname != 'n/a'
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = 1.minute
    @ip_a = nil
    network_manager.refresh
  else
    @ip_a
  end
end

def ip_map
  networks.map{|n| n.allocations}.flatten.select{|a| a.type == "nic"}.group_by(&:vm_id)
end

def networks
  @networks ||= JSON.parse(@service.networks_json).map do |n|
    network = OpenStruct.new(n)
    network.allocations = network.allocations.map{|alloc| OpenStruct.new(alloc)}
    network
  end
end

@service = $evm.root['service']
vm_id = $evm.root['dialog_vm_id']
vms = if vm_id == 'all'
        $evm.root['service'].vms
      else
        $evm.vmdb(:Vm).where(:id => vm_id)
      end

vms.each do |vm|
  update_dns_record(vm)
end
