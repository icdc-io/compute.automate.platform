require '/var/www/miq/vmdb/lib/icdc/network'
require 'ovirtsdk4'

module Platform
  module Automate
    module System
      module Request
        class ChangeNetworkType
          def initialize(handle = $evm)
            @handle = handle
            @service = @handle.root['service']
          end

          def main
            @handle.log(:info, "Changing network type for service #{@service.name} (#{@service.id})")
            change_network_type
            @handle.log(:info, 'End changing network type')
          end

          private

          def change_network_type
            vms.each do |vm|
              @handle.log(:info, "Changing network type for vm #{vm.name} (#{vm.id})")

              vendor = vm.vendor
              case vendor
              when 'redhat'
                change_network_type_redhat(vm)
              when 'power_systems'
                change_network_type_power(vm)
              end
            end
          end

          def change_network_type_redhat(vm)
            connection = vm.ext_management_system.connect
            new_vlan = @handle.root['dialog_network_profile']

            vm_service = connection.system_service.vms_service.vm_service(vm.uid_ems)
            nics_service = vm_service.nics_service

            datacenter = vm.parent_datacenter
            nic_id, nic_profile_id, new_nic_id = collect_nic_info(connection, nics_service, new_vlan, datacenter)

            @handle.log(:info, "nic_id: #{nic_id}, nic_profile_id: #{nic_profile_id}, new_nic_id: #{new_nic_id}")

            return if nic_profile_id == new_nic_id

            exit MIQ_OK if nic_id == new_nic_id

            set_vnic_profile(vm_service, nics_service, nic_id, new_nic_id)
          end

          def change_network_type_power(vm)
            raise NotImplementedError
          end

          def collect_nic_info(connection, nics_service, new_vlan, datacenter)
            nic_id = nics_service.list.first.id
            nic_profile_id = nics_service.list.first.vnic_profile.id

            network_id = connection.system_service.data_centers_service.data_center_service(datacenter.uid_ems).networks_service.list(search: "name=#{new_vlan}", max: 1).first.id
            new_nic_id = connection.system_service.networks_service.network_service(network_id).vnic_profiles_service.list(max: 1).first.id

            [nic_id, nic_profile_id, new_nic_id]
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

          def vms
            @vms ||= if network_change_for_all_vms?
                       @service.vms
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

# Platform::Automate::System::Request::ChangeNetworkType.new.main outdated
