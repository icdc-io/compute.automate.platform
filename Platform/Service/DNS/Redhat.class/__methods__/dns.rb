#
# Description: dns class # TODO
#

require 'coredns'

def clone_all_dns_records(service, old_vm, new_vm)
  ip = ips(new_vm).first
  raise "Ip address can't be blank" if ip.blank?

  account = service.tenant.name
  owner = new_vm.evm_owner.userid

  dns_records(service, old_vm).each do |dns_record|
    create_dns_record(service, ip, account, dns_record['group'], owner)
  end
rescue StandardError => e
  $evm.log(:warn, "Can't create DNS records because #{e.message}")
end

def remove_all_dns_records(service, vm)
  dns_records(service, vm).each do |dns_record|
    remove_dns_record(service, dns_record['host'], dns_record['name'], dns_record['group'], dns_record['zone'])
  end
rescue StandardError => e
  $evm.log(:warn, "Can't remove DNS records because #{e.message}")
end

def remove_dns_record(service, ip, name, group, zone)
  core_dns_domain = dns(service).domain(zone)
  $evm.log(:info, "Removing Core Dns Record with hostname '#{group}' and ip '#{ip}'")
  core_dns_domain.delete({ 'name' => name })
rescue StandardError => e
  $evm.log(:warn, "Can't remove DNS record with ip '#{ip}' because #{e.message}")
end

def create_dns_record(service, ip, account, group, owner)
  core_dns_domain = dns(service).domain(group)
  $evm.log(:info, "Creating Core Dns Record with hostname '#{group}' and ip '#{ip}'")
  core_dns_domain.add(core_dns_add_params(ip, account, group, owner))
rescue StandardError => e
  $evm.log(:warn, "Can't create DNS record with ip '#{ip}' in '#{group}' because #{e.message}")
end

def core_dns_add_params(ip, account, group, owner)
  {
    host: ip,
    ttl: 600,
    group: group,
    metadata: {
      account: account,
      owner: owner
    }
  }
end

def dns_records(service, vm)
  vm_ips = choose_vm_ips(vm)
  dns_records = []

  $evm.log(:info, "Vm IPs: #{vm_ips}")
  account_zones = account_zones(service)
  account_zones.each do |zone|
    dns_domain = dns(service).domain(zone)
    dns_domain.list.each do |record|
      if vm_ips.include?(record['host'])
        $evm.log(:info, "Found [#{record['name']}] from zone: #{zone}")
        dns_records.push(record.merge('zone' => zone))
      end
    end
  rescue StandardError
    nil
  end

  $evm.log(:info, "DNS records not found") if dns_records.empty?
  dns_records
end

def choose_vm_ips(vm)
  vm_ips = ips(vm)
  raise "Vm ip address can't be blank" if vm_ips.blank?

  vm_ips
end

def ips(vm)
  vm.hardware.nics
    .filter_map { |nic| $evm.vmdb(:NetworkPort).find_by(device_id: nic.id) }
    .collect(&:ipaddresses).flatten.compact
end

def account_zones(service)
  dns(service).zone('').list_all.select do |zone|
    zone.dig('metadata', 'account') == service.tenant.name
  end.pluck('name')
end

# maybe it's bad to use memorization, cause services could be different
def dns(service = nil)
  @dns ||= CoreDns::Etcd.new(coredns_address(service))
end

def coredns_address(service = nil)
  @coredns_address ||= ENV.fetch('DNS_SERVER', nil)
  @coredns_address ||= "etcd.dns.#{location_domain(service)}"
end

def location_domain(service = nil)
  @location_domain ||= ENV.fetch('LOCATION_DOMAIN', nil)
  @location_domain ||= "#{location_name(service)}.#{cpv_domain}"
end

def location_name(service)
  @location_name ||= service.region_description.downcase
end

def cpv_domain
  @cpv_domain ||= ENV.fetch('CPV_DOMAIN', nil)
  @cpv_domain ||= "#{ENV['CPV_NAME'].downcase}.io" # outdated
end
