require 'ovirtsdk4'

module Platform
  module Automate
    module System
      module StateMachines
        module Methods
          class ChangeNetworkType
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              @handle.log(:info, "Changing network type for service #{service.name} (#{service.id})")
              change_network_type
              @handle.log(:info, 'End changing network type')
            end

            private

            def change_network_type
              vms.each do |vm|
                @handle.log(:info, "Changing network type for vm #{vm.name} (#{vm.id})")

                case vm.vendor
                when 'redhat'
                  change_network_type_redhat(vm)
                when 'power_systems'
                  change_network_type_power(vm)
                end
              end
            end

            def change_network_type_redhat(vm)
              connection = vm.ext_management_system.connect
              vm_service = connection.system_service.vms_service.vm_service(vm.uid_ems)
              nics_service = vm_service.nics_service

              nic = nics_service.list.first
              nic_id = nic.id

              new_vlan = @handle.root['dialog_network_profile']
              new_nic_id = connection.system_service.vnic_profiles_service.list.find { |x| x.name == new_vlan }.id
              return if nic.vnic_profile.id == new_nic_id || nic_id == new_nic_id

              add_security_groups_info(vm, nic_id)
              set_vnic_profile(vm_service, nics_service, nic_id, new_nic_id)

              @handle.set_state_var(:security_groups_info, security_groups_info)
            end

            def add_security_groups_info(vm, nic_id)
              port = @handle.vmdb(:NetworkPort).find_by(device_ref: nic_id)
              port_security_groups = port.security_groups.collect(&:ems_ref)
              return if port_security_groups.empty?

              data = {
                vm_id: vm.id,
                nic_id: nic_id,
                old_port_id: port.ems_ref,
                port_security_groups: port_security_groups
              }

              security_groups_info.push(data)
            end

            def security_groups_info
              @security_groups_info ||= []
            end

            def change_network_type_power(vm)
              raise NotImplementedError
            end

            def set_vnic_profile(vm_service, nics_service, nic_id, new_nic_id)
              vm_service.shutdown
              sleep 25

              begin
                nics_service.nic_service(nic_id).update(vnic_profile: { id: new_nic_id })
              rescue StandardError
                sleep 15
                retry
              end

              vm_service.start
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
          end
        end
      end
    end
  end
end

Platform::Automate::System::StateMachines::Methods::ChangeNetworkType.new.main
