module Platform
  module Automate
    module System
      module Request
        class SeparateServices
          SPECIAL_SERVICE_TYPES = ['ServiceAnsiblePlaybook'].freeze

          def initialize(handle = $evm)
            @handle = handle
            @parent_service = @handle.root['service']
          end

          def main
            @handle.log(:info, "Start separate #{@parent_service.name} (#{@parent_service.id})")
            separate_services
            @handle.log('info', 'End separate services')
          end

          private

          def separate_services
            if separate_all_services?
              parent_direct_service_children.each { |child_service| child_service.parent_service = nil }
            else
              child_service.parent_service = nil
            end

            @parent_service.start_retirement if @parent_service.vms.empty? && parent_direct_service_children.empty?
          end

          def parent_direct_service_children
            @parent_service.direct_service_children.reject do |child_service|
              child_service.type.in?(SPECIAL_SERVICE_TYPES)
            end
          end

          def separate_all_services?
            @handle.root['dialog_service_id'] == 'all'
          end

          def child_service
            @child_service ||= @handle.vmdb(:Service).find_by(id: @handle.root['dialog_service_id'])
            return @child_service unless @child_service.type.in?(SPECIAL_SERVICE_TYPES)

            @handle.log('info', 'Unsupported child service for separating')
            raise 'Unsupported child service for separating'
          end
        end
      end
    end
  end
end

Platform::Automate::System::Request::SeparateServices.new.main
