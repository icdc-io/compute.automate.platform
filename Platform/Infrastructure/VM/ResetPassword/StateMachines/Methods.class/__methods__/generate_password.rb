#
# Description: <Method description here>
#

module Platform
  module Automate
    module Infrastructure
      module VM
        module ResetPassword
          module StateMachines
            class GeneratePassword
              def initialize(handle = $evm)
                @handle = handle
              end

              def main
                password = ICDC::CloudServiceTemplate.new.generate_password
                @handle.root['vm_password'] = password
                @handle.set_state_var(:vm_password, password)
              end
            end
          end
        end
      end
    end
  end
end

Platform::Automate::Infrastructure::VM::ResetPassword::StateMachines::GeneratePassword.new.main
