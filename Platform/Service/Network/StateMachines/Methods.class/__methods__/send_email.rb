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
              send_email_message
              @handle.log(:info, 'End sending email messages')
            end

            private

            def send_email_message
              @handle.root['vm'] = vm
              Platform::Automate::Service::Email::ChangeNetworkType.new.send_email
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

Platform::Automate::System::StateMachines::Methods::SendEmail.new.main
