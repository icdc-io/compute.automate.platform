#
# Description: <Method description here>
#

require 'bundler'
Bundler.setup(:default)
require 'resolv'
require 'coredns'

module Platform
  module Automate
    module System
      module StateMachines
        module Methods
          class RegisterDNS
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              @handle.log(:info, "Updating dns record for service #{service.name} (#{service.id})")
              update_vms_dns_records
              @handle.log(:info, 'End updating dns record')
            end

            private

            def update_vms_dns_records
              vms.each do |vm|
                @handle.log(:info, "Updating dns record for vm #{vm.name} (#{vm.id})")
                update_vm_dns_record(vm)
              end
            end

            def update_vm_dns_record(vm)
              init_vm_enviroment(vm)
              return if @vm_hostname == 'n/a' || !@vm_hostname

              remove_vm_dns_record
              create_vm_dns_record
            end

            def remove_vm_dns_record
              core_dns_domain = CoreDns::Etcd.new("etcd.dns.#{@vm_location}.#{server_hostname}.io").domain(@vm_hostname)
              name_to_delete = core_dns_domain.list.find { |x| x['host'] == @vm_ip_before_change }['name']
              core_dns_domain.delete({ 'name' => name_to_delete })
            rescue StandardError => e
              @handle.log(:warn, "Can't remove DNS record cause #{e.message}")
              retry_request
            end

            def create_vm_dns_record
              domain = vm_hostname_domain
              new_core_dns_domain = CoreDns::Etcd.new("etcd.dns.#{@vm_location}.#{server_hostname}.io").domain(domain)
              ip_address_free = new_core_dns_domain.list.none? { |x| x['host'] == @vm_ip }
              return unless check_domain_length(domain, @vm_hostname.split('.').first) && @vm_ip && ip_address_free

              new_core_dns_domain.add(core_dns_domain_params(domain))
            rescue StandardError => e
              @handle.log(:warn, "Can't create DNS record cause #{e.message}")
              retry_request
            end

            def retry_request
              @handle.root['ae_result'] = 'retry'
              @handle.root['ae_retry_interval'] = 1.minute
            end

            def vm_hostname_domain
              hostname_first_part = @vm_hostname.split('.').first
              if ['@', ''].include?(hostname_first_part)
                "apex.dns.#{@vm_location}"
              elsif @vm_hostname
                @vm_hostname
              end
            end

            def core_dns_domain_params(domain)
              {
                host: @vm_ip,
                ttl: 600,
                group: domain,
                metadata: {
                  account: @vm_account.name.downcase,
                  owner: @vm.evm_owner.userid
                }
              }
            end

            def check_domain_length(domain, name)
              valid = true

              if name&.length&.> 63
                @handle.log(:warn, "UN Name #{name} can't be more than 63 symbols")
                valid = false
              end

              if domain.length > 250
                @handle.log(:warn, "UN Domain #{domain} length can't be more than 250 symbols")
                valid = false
              end

              valid
            end

            def service
              @service ||= @handle.root['service']
            end

            def vms
              @vms ||= if network_change_for_all_vms?
                         service.vms
                       else
                         @handle.vmdb(:Vm).where(id: @handle.root['dialog_vm_id'])
                       end
            end

            def network_change_for_all_vms?
              @handle.root['dialog_vm_id'] == 'all'
            end

            def server_hostname
              @server_hostname ||= ENV['CPV_NAME'].downcase
            end

            # vm params initialization section

            def init_vm_enviroment(vm)
              @vm = vm
              @vm_ip_before_change = vm.ipaddresses.first
              @vm_hostname = vm_hostname(vm)
              @vm_location = @vm.service.region_description.downcase
              @vm_account = vm_account(vm)
              @vm_ip = vm_ip
            end

            def vm_hostname(vm)
              hostname = vm.hostnames.first
              ip_map = networks.flat_map(&:allocations).select { |a| a.type == 'nic' }.group_by(&:vm_id)
              hostname = (ip_map[vm.id] || []).filter_map(&:hostname).first if hostname.nil?
              hostname.downcase
            end

            def networks
              @networks ||= JSON.parse(service.networks_json).map do |n|
                network = OpenStruct.new(n)
                network.allocations = network.allocations.map { |alloc| OpenStruct.new(alloc) }
                network
              end
            end

            def vm_account(vm)
              tenant = @handle.vmdb(:User).find_by(userid: vm.evm_owner.userid).current_tenant
              (tenant.project? && tenant.account) || tenant
            end

            def vm_ip
              network_manager = @vm.ext_management_system.try(:network_manager)
              nics = @vm.hardware.nics
              dialog_network_profile = @handle.root['dialog_network_profile']
              ip_a = nil

              if network_manager && nics.reject { |nic| nic.lan&.name }.present?
                network_manager.refresh
              else
                nics.each do |nic|
                  nic_lan_name = nic.lan.name
                  cloud_network = @handle.vmdb(:CloudNetwork).find_by(name: nic_lan_name)
                  next unless cloud_network

                  port = cloud_network.network_ports.detect { |network_port| network_port.device&.id == nic.id }
                  ip_a = port.ipaddresses.first if port&.ipaddresses
                  break if ip_a && ip_a != '' && (nic_lan_name == dialog_network_profile)

                  if ip_a == @vm_ip_before_change
                    network_manager.refresh
                    ip_a = nil
                  end
                end
              end

              if ip_a && ip_a != '' && @vm_hostname && @vm_hostname != 'n/a'
                ip_a
              else
                retry_request

                ip_a = nil
                network_manager.refresh
              end

              ip_a
            end
          end
        end
      end
    end
  end
end

Platform::Automate::System::StateMachines::Methods::RegisterDNS.new.main
