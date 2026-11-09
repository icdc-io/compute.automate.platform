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
              @handle.log(:info, "Changing network type for vm #{vm.name} (#{vm.id})")

              case vm.vendor
              when 'redhat', 'ovirt'
                change_network_type_redhat(vm)
              when 'power_systems'
                change_network_type_power(vm)
              end
            end

            def change_network_type_redhat(vm)
              connection = vm.ext_management_system.connect
              vm_service = connection.system_service.vms_service.vm_service(vm.uid_ems)
              nics_service = vm_service.nics_service

              nic = nics_service.list.first
              nic_id = nic.id

              new_vlan = @handle.root['dialog_network_profile']
              cluster = vm.ems_cluster
              network_id = connection.system_service.clusters_service.cluster_service(cluster.uid_ems).networks_service.list.find { |nw| nw.name == new_vlan }.id
              new_nic_id = connection.system_service.networks_service.network_service(network_id).vnic_profiles_service.list(max: 1).first.id

              @handle.log(:info, "nic_id: #{nic_id}, nic_profile_id: #{nic.vnic_profile.id}, new_nic_id: #{new_nic_id}")

              if nic.vnic_profile.id == new_nic_id || nic_id == new_nic_id
              	@handle.log(:info, "New network type is the same as original one. Aborting...")
                exit MIQ_ABORT
              end

              add_security_groups_info(vm, nic_id)
              add_vm_old_ip_info(vm)
              set_vnic_profile(vm_service, nics_service, nic_id, new_nic_id)
            end

            def add_vm_old_ip_info(vm)
              network_ports = @handle.vmdb(:NetworkPort).where(device_id: vm.hardware.nics.pluck(:id))
              vm_old_ip = network_ports.collect(&:ipaddresses).flatten.compact.first
              @handle.set_state_var(:vm_old_ip, vm_old_ip)
            end

            def add_security_groups_info(vm, nic_id)
              security_groups_info = nil

              port = @handle.vmdb(:NetworkPort).find_by(device_ref: nic_id)
              port_security_groups = port.security_groups.collect(&:ems_ref)

              if port_security_groups.present?
                security_groups_info = {
                  vm_id: vm.id,
                  nic_id: nic_id,
                  old_port_id: port.ems_ref,
                  port_security_groups: port_security_groups
                }
              end

              @handle.set_state_var(:security_groups_info, security_groups_info)
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

            def vm
              @vm ||= @handle.vmdb(:Vm).find(@handle.root['dialog_vm_id'])
            end
          end
        end
      end
    end
  end
end

Platform::Automate::System::StateMachines::Methods::ChangeNetworkType.new.main
