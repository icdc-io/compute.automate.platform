require 'bundler'
Bundler.setup(:default)
require 'resolv'
require 'coredns'

def update_dns_record(vm)
  init_environment(vm)
  remove_dns_record
  update_dns_record
  send_email
end

def init_environment(vm)
  @ip_before_change = vm.ipaddresses.first
  @vm = vm
  @hostname = (@vm.hostnames.first || (ip_map[@vm.id] || []).collect(&:hostname).compact.first).split('.').first
  @location = @vm.miq_provision.region_description.downcase
  @account = account
  ip
end  
  
def remove_dns_record
  zone = "#{@account.name}.cmp.#{@location}.icdc.io"
  domain = @hostname + '.' + zone
  name_to_delete = CoreDns::Etcd.new("etcd.dns.#{@location}.icdc.io").domain(domain).list.select{|x| x["host"] == @ip_before_change}[0]["name"]
  CoreDns::Etcd.new("etcd.dns.#{@location}.icdc.io").domain(domain).delete({"name" => name_to_delete})
rescue => e
  $evm.log(:warn, "Can't remove DNS record cause #{e.message}")
end

def update_dns_record
  zone = "#{@account.name}.cmp.#{@location}.icdc.io"
  if @hostname == "@" || @hostname == "" || !@hostname
    domain = "apex.dns.#{@location}"
  elsif @hostname
    domain = "#{@hostname}.#{zone}"
  end
  return unless check_domain_length(domain, @hostname)
  $evm.log(:info, "UN ip = #{@ip_a}, domain=#{domain}, location=#{@location}, owner=#{@vm.evm_owner.userid}, name = #{@hostname}")
  CoreDns::Etcd.new("etcd.dns.#{@location}.icdc.io").domain(domain).add({:host => @ip_a, :ttl => 600, :group => domain,
                                                                                       :metadata => {:account => @account.name, :owner => @vm.evm_owner.userid}})
rescue => e
  $evm.log(:warn, "Can't update DNS record cause #{e.message}")
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
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = 1.minute
    network_manager.refresh
  else
    nics.each do |nic|
      cloud_network = $evm.vmdb(:CloudNetwork).find_by(:name => nic.lan.name)
      next unless cloud_network
      port = cloud_network.network_ports.detect{|np| np.device&.id == nic.id}
      @ip_a = port.ipaddresses.first if port&.ipaddresses
      if @ip_a == @ip_before_change
        $evm.root['ae_result'] = 'retry'
        $evm.root['ae_retry_interval'] = 1.minute
        network_manager.refresh
      else      
        break if @ip_a 
      end
    end
  end
  $evm.log(:info,"UN ip = #{@ip_a}")
  @ip_a
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
@service.vms.each do |vm|
  update_dns_record(vm)
end
