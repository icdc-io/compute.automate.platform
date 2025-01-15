#
# Description: <Method description here>
#

require 'resolv'

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
              @handle.log(:info, "Updating dns records for service #{service.name} (#{service.id})")
              update_dns_records(vm)
              @handle.log(:info, 'End updating dns records')
            end

            private

            def update_dns_records(vm)
              @handle.log(:info, "Updating dns records for vm #{vm.name} (#{vm.id})")
              vm_env = VmEnviroment.new(vm)
              @handle.log(:info, "Old vm ip #{vm_env.old_ip}")
              @handle.log(:info, "Vm ip #{vm_env.ip}")

              if !vm_env.ip_changed? || vm_env.ip.blank? || vm_env.old_ip.blank?
                vm_env.refresh_network
                return retry_request
              end

              vm_env.create_new_dns_records
              vm_env.remove_old_dns_records
            end

            def retry_request
              @handle.root['ae_result'] = 'retry'
              @handle.root['ae_retry_interval'] = 1.minute
            end

            def service
              @service ||= @handle.root['service']
            end

            def vm
              @vm ||= @handle.vmdb(:Vm).find(@handle.root['dialog_vm_id'])
            end
          end

          class VmEnviroment
            attr_reader :vm, :service, :account, :ip, :old_ip

            def initialize(vm, handle = $evm)
              @handle = handle
              @vm = vm
              @service = vm.service
              @account = @service.tenant.name
              @ip = find_ip
              @old_ip = @handle.get_state_var(:vm_old_ip)
            end

            def update_dns_records
              remove_old_dns_records
              create_new_dns_records
            end

            def create_new_dns_records
              # create dns record with new ip
              clone_all_dns_records(service, vm, vm)
            end

            def remove_old_dns_records
              # find dns record according to the old ip
              # remove them from dns service
              remove_all_dns_records(service, vm)
            end

            def refresh_network
              !!vm.ext_management_system.try(:network_manager)&.refresh
            end

            def ip_changed?
              ip != old_ip
            end

            # overrride lib method
            def choose_vm_ips(_vm)
              vm_ips = [old_ip]
              raise "Vm ip address can't be blank" if vm_ips.blank?

              vm_ips
            end

            private

            def find_ip
              network_ports = @handle.vmdb(:NetworkPort).where(device_id: vm.hardware.nics.pluck(:id))
              network_ports.collect(&:ipaddresses).flatten.compact.first
            end
          end
        end
      end
    end
  end
end

Platform::Automate::System::StateMachines::Methods::RegisterDNS.new.main
