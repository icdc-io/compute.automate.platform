module Platform
  module Automate
    module System
      module StateMachines
        module Methods
          class SendEmail
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              @handle.log(:info, "Sending email messages for service #{service.name} (#{service.id})")
              send_email_messages
              @handle.log(:info, 'End sending email messages')
            end

            private

            def send_email_messages
              vms.each do |vm|
                @handle.root['vm'] = vm
                Platform::Automate::Service::Email::ChangeNetworkType.new.send_email
              end
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

Platform::Automate::System::StateMachines::Methods::SendEmail.new.main
