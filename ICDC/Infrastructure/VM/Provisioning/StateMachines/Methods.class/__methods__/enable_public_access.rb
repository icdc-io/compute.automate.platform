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
                  SkyDNS.set_CNAME(response[:host], "lb-default.#{account_id}.#{location_domain}.")
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
                log("public_access payload: #{payload}")
                result = service.add_haproxy_routes(payload)
                log("public_access result: #{result}")
                result
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
