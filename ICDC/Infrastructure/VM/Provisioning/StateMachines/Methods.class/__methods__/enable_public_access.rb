module ManageIQ
  module Automation
    module Infrastructure
      module VM
        module Provisioning
          module StateMachines
            class EnablePublicAccess

              def initialize(handle = $evm)
                @handle = handle
              end

              def main
                exit MIQ_OK unless provision.get_option(:enable_public_access)
                @vm = vm
                response = create_public_access
                if response.code == "200"
                  provision.set_option(:public_access, "#{response.body.dig("host")} -p #{response.body.dig("port")}")
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
                vm.service
              end

              def proxy_server
                $evm.vmdb(:HaproxyCluster).get_proxy_server(service)
              end

              def payload
                {
                  "vms" => [{
                    "host" => ip.first,
                    "id" => @vm.id,
                    "name" => @vm.name
                  }],
                  "port" => "22",
                  "name" => "SSH Access",
                  "externalProtocol" => "TCP",
                  "internalProtocol" => "TCP",
                  "dns" => provision.get_option(:hostname),
                  "project" => {
                    "code" => "",
                    "name" => ""
                  },
                  "purpose" => "For public acces to VM via SSH"
                }
              end

              def create_public_access
                proxy_server.add_service_routers(service, payload)
              end

              def provision
                @provision ||= @handle.root["miq_provision"].tap do |provision|
                  raise "ERROR - miq_provision object not passed in" unless provision
                end
              end
            end
          end
        end
      end
    end
  end
end
