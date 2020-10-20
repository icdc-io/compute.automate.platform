require '/var/www/miq/vmdb/lib/icdc/network.rb'
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
                @available_protocols.each do |protocol|
                  response = create_public_access(protocol)
                  provision.set_option("external_#{protocol}_access", {:host => response[:host], :port => response[:port]})
                end
              end

              private

              def ip
                (ip_map[@vm.id] || []).collect(&:ip).compact
              end

              def ip_map
                @ip_map ||= service.networks.collect{|n| n.allocations}.flatten.select{|a| a.type == :nic }.group_by(&:vm_id)
              end

              def vm 
                provision.destination
              end

              def service
                id = vm.service.id
                $evm.vmdb(:Service).find(id)
              end

              def generate_payload(protocol)
                {
                  "vms" => [{
                    "host" => ip.first,
                    "id" => @vm.id,
                    "name" => @vm.name
                  }],
                  "port" => protocol_port_mapper[protocol],
                  "name" => "#{protocol.to_s} access",
                  "externalProtocol" => "TCP",
                  "internalProtocol" => "TCP",
                  "dns" => "#{protocol.to_s}.#{provision.get_option(:hostname)}",
                  "project" => {
                    "code" => "",
                    "name" => ""
                  },
                  "purpose" => "For public acces to VM via #{protocol.to_s}"
                }
              end

              def create_public_access(protocol)
                payload = generate_payload(protocol)
                service.add_haproxy_routes(payload)
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
