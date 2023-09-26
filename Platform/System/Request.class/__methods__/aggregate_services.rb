module Platform
  module Automate
    module System
      module Request
        class AggregateServices
          def initialize(handle = $evm)
            @handle = handle
            @service1 = @handle.root['service'].root_service
            @service2 = @handle.vmdb(:Service).find_by(id: @handle.root['dialog_merge_id']).root_service
          end

          def main
            @handle.log(:info, "Start aggregate #{@service1.name} (#{@service1.id}) and #{@service2.name} (#{@service2.id})")
            aggregate_services
            @handle.log(:info, 'End aggregare services')
          end

          def bundle_name
            @bundle_name ||= @handle.root['dialog_new_name'] # TODO: fix in ui
            @bundle_name = "#{@service1.name} and #{@service2.name} bundle" if @bundle_name.blank?
            @bundle_name
          end

          private

          def aggregate_services
            if @service1.all_service_children.present? && @service2.all_service_children.blank?
              @service2.parent_service = @service1
            elsif @service1.all_service_children.blank? && @service2.all_service_children.present?
              @service1.parent_service = @service2
            elsif @service1.all_service_children.present? && @service2.all_service_children.present?
              aggregate_services_with_all_service_children
            elsif @service1.all_service_children.blank? && @service2.all_service_children.blank?
              aggregate_services_without_all_service_children
            end
          end

          def aggregate_services_with_all_service_children
            new_service = create_aggregated_service

            @service1.all_service_children.each { |child_service1| child_service1.parent_service = new_service }
            @service2.all_service_children.each { |child_service2| child_service2.parent_service = new_service }

            @service1.root_service.retire_now
            sleep 10

            @service2.root_service.retire_now
            sleep 10

            @handle.instantiate('/Service/Retirement/StateMachines/ServiceRetirement/Default')
          end

          def aggregate_services_without_all_service_children
            new_service = create_aggregated_service

            @service1.parent_service = new_service
            @service2.parent_service = new_service
          end

          def create_aggregated_service
            new_service = @handle.vmdb('service').create(name: bundle_name)
            new_service.display = true
            new_service.description = "Bundle service #{@service1.name} and #{@service2.name}"

            # Template id = id Empty Service Template
            template_id = @handle.vmdb(:ServiceTemplate).find_by(name: 'Clone Service').id
            new_service[:service_template_id] = template_id
            owner = @handle.vmdb(:user).find_by(id: @service1.evm_owner_id)

            if owner
              new_service.owner = owner
              new_service.group = owner.current_group
            end

            new_service
          end
        end
      end
    end
  end
end

Platform::Automate::System::Request::AggregateServices.new.main
