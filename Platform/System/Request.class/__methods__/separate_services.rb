module Platform
  module Automate
    module System
      module Request
        class SeparateServices
          def initialize(handle = $evm)
            @handle = handle
            @parent_service = @handle.root['service']
          end

          def main
            @handle.log(:info, "Start separate #{@parent_service.name})")
            separate_services
            @handle.log('info', 'End separate services')
          end

          private

          def separate_services
            if separate_all_services?
              @parent_service.all_service_children.each { |child_service| child_service.parent_service = nil }
            else
              child_service.parent_service = nil

              if @parent_service.all_service_children.blank?
                @handle.instantiate('/Service/Retirement/StateMachines/ServiceRetirement/Default')
              end
            end

            remove_generic_objects(@parent_service, child_service)
            @parent_service.start_retirement
          end

          def separate_all_services?
            @handle.root['dialog_service_id'] == 'all'
          end

          def child_service
            @child_service ||= @handle.vmdb(:Service).find_by(id: @handle.root['dialog_service_id'])
          end

          def remove_generic_objects(parent_service, children_service = nil)
            children_service ||= parent_service

            generic_objects = children_service.generic_objects
            generic_objects.each { |generic_object| generic_object.remove_from_service(parent_service) }
            # ^^^ but what will happen in we create pf in aggregated service and separate it?
            # should we destroy generic object or it will be destroyed automatically?
          end
        end
      end
    end
  end
end

Platform::Automate::System::Request::SeparateServices.new.main
