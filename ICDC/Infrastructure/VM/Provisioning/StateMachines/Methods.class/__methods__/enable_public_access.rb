module ManageIQ
  module Automation
    module Infrastructure
      module VM
        module Provisioning
          module StateMachines
            class EnablePublicAccess

              def initialize(handle = $evm, protocols = [:ssh])
                @handle = handle
                @available_protocols = protocols
              end

              def main
                exit MIQ_OK unless provision.get_option(:enable_public_access) == "t"
                @vm = vm
                initialize
                @available_protocols.each do |protocol|
                  create_public_access(protocol)
                end
              end

              private

              def log(msg)
                @handle.log(:info, "[ICDC] #{msg}")
              end

              def ip
                (ip_map[@vm.id] || []).collect(&:ip).compact
              end

              def ip_map
                @ip_map ||= networks.collect{|n| n.allocations}.flatten.select{|a| a.type.to_sym == :nic }.group_by(&:vm_id)
              end

              def vm 
                provision.destination
              end

              def networks
                @networks ||= JSON.parse(service.networks_json).map do |n|
                  network = OpenStruct.new(n)
                  network.allocations = network.allocations.map{|alloc| OpenStruct.new(alloc)}
                  network
                end
              end

              def service
                id = vm.service.id
                $evm.vmdb(:Service).find(id)
              end

              def account
                @account ||= vm.service.tenant.project? && vm.service.tenant.parent || vm.service.tenant
              end

              def account_id
                @account_id ||= account.name.downcase.slice(0..4)
              end

              def location
                @location ||= service.region_description.downcase
              end

              def location_domain
                @location_domain = "#{location}.icdc.io"
              end

              def create_public_access(protocol)

				$evm.root['service'] = vm.service
                $evm.root["name"] = "pf_" + vm.service.name
				$evm.root["protocol"] = "TCP"
                $evm.root["internal_port"] = protocol_port_mapper[protocol]

                unavailable_ports = []
                $evm.vmdb(:GenericObjectDefinition).find_by(:name => "PortForwarding").generic_objects.select { |port_forwarding| port_forwarding["properties"]["account"] == $evm.root['user'].current_tenant.name }.each do |objects|
                  unavailable_ports.push(objects.external_port)
                end
                generated_external_port = rand(8000..65000)
                while unavailable_ports.include?(generated_external_port) do
                  generated_external_port = rand(8000..65000)
                end
                $evm.root["external_port"] = generated_external_port

                nics = @vm.hardware.nics
                @ip_a = nil
                nics.each do |nic|
                  cloud_network = $evm.vmdb(:CloudNetwork).find_by(:name => nic.lan.name)
                  next unless cloud_network
                  port = cloud_network.network_ports.detect{|np| np.device&.id == nic.id}
                  @ip_a = port&.ipaddresses.first
                  break if @ip_a
                end
                $evm.root["internal_ip"] = @ip_a

                $evm.instantiate("/Ansible/GenericObject/PortForwarding/create")

               end

              def provision
                @provision ||= @handle.root["miq_provision"].tap do |provision|
                  raise "ERROR - miq_provision object not passed in" unless provision
                end
              end

              def protocol_port_mapper
                {
                  :ssh => "22",
                  :cockpit => "9090",
                  :rdp => "3389"
                }
              end
            end
          end
        end
      end
    end
  end
end
