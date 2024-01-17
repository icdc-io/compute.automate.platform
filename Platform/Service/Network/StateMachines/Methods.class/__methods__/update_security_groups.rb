module Platform
  module Automate
    module System
      module StateMachines
        module Methods
          class UpdateSecurityGroups
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              @handle.log(:info, "Updating security groups for service #{service.name} (#{service.id})")
              update_security_groups
              @handle.log(:info, 'End updating security groups')
            end

            private

            def service
              @service ||= @handle.root['service']
            end

            def update_security_groups
              security_groups_info.each do |data|
                vm = @handle.vmdb(:Vm).find_by(id: data[:vm_id])

                ns = vm.ext_management_system.network_manager.openstack_handle.detect_network_service
                nic = vm.nics.find { |nic| nic.uid_ems == data[:nic_id] }
                next unless nic

                @handle.log(:info, "[ICDC] Process SG for NIC: #{nic.id}")
                new_port = @handle.vmdb(:NetworkPort).find_by(device_id: nic.id)
                next unless new_port

                new_port_id = new_port.ems_ref
                @handle.log(:info, "[ICDC] NIC[#{nic.id}] has port: #{new_port_id}")

                unless new_port_id == data[:old_port_id]
                  ns.update_port(new_port_id, { security_groups: data[:port_security_groups] })
                end
              rescue RuntimeError => e
                @handle.log(:error, "[ICDC] Could not set NIC[#{nic.id}]: #{e.message}")
                next # Skip setting group
              end
            end

            def security_groups_info
              security_groups_info = []

              if @handle.state_var_exist?(:security_groups_info)
                security_groups_info = @handle.get_state_var(:security_groups_info)
              end

              security_groups_info
            end
          end
        end
      end
    end
  end
end

Platform::Automate::System::StateMachines::Methods::UpdateSecurityGroups.new.main
