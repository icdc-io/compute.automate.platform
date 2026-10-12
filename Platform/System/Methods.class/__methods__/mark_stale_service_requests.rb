#
# Description: Mark stale service requests as error
#

module Platform
  module Automation
    module System
      module Methods
        class MarkStaleServiceRequests
          def initialize(handle = $evm)
            @handle = handle
          end

          def main
            @handle.log(:info, 'Start mark stale service requests')
            mark_stale_provision_tasks
            mark_stale_provision_requests
            mark_stale_retirement_requests
            @handle.log(:info, 'End mark stale service requests')
          end

          private

          def mark_stale_provision_requests
            @handle.log(:info, 'Schedule - collecting stale Miq Provision Requests')

            stale_provision_requests = @handle.vmdb(:MiqRequest).where(
              "approval_state = 'approved' " \
                "AND type IN ('MiqProvisionRequest', 'ServiceTemplateProvisionRequest') " \
                "AND request_state IN ('active', 'queued', 'pending') " \
                "AND ((status = 'Ok' AND process = TRUE) OR (status = 'Error' AND request_state = 'active')) " \
                "AND (source_type IS NULL OR (source_type = 'VmOrTemplate' AND source_id IN (SELECT id FROM vms)) " \
                "OR (source_type = 'ServiceTemplate' AND source_id IN (SELECT id FROM service_templates))) " \
                "AND ((created_on + interval '1 hour') < NOW())"
            )

            @handle.log(:info, "Schedule - founded #{stale_provision_requests.size} stale Miq Provision Request records")
            return if stale_provision_requests.empty?

            stale_provision_requests.each do |request|
              tasks = request.miq_request_tasks
              if tasks.pluck(:state).uniq.count != 1
                tasks.each { |task| task.object_send(:update_and_notify_parent, :state => 'finished') }
              end
              request.object_send(:update, status: 'Error', request_state: 'finished', message: 'Request timed out')
            end
          end

          def mark_stale_provision_tasks
            # MiqProvisionTask is the lowest level provision (VM provision)
            # it can stale in `provisioned` state so parent ServiceTemplateProvisionTask never finished and requeue
            @handle.log(:info, 'Schedule - collecting stale MiqProvisionTask')
            stale_provision_tasks = @handle.vmdb(:MiqProvisionTask).where(
              "state IN ('provisioned')" \
              " AND ((created_on + interval '1 hour') < NOW())" 
            )
            @handle.log(:info, "Schedule - founded #{stale_provision_tasks.size} stale MiqProvisionTask records")
            return if stale_provision_tasks.empty?
            
            stale_provision_tasks.each do |task|
              if task.state == 'provisioned'
                # Provisioned means VM exists already, so set MiqProvisionTask as finished, so this allow
                # parent ServiceTemplateProvisionTask to fisnish it's state as well
                @handle.log(:info, "Schedule - update MiqProvisionTask [#{task.id}] state [#{task.state}] => finished")
                task.object_send(:update_and_notify_parent, :state => 'finished', :message => "#{task.message} (stale, forced finished)")
              end
            end
          end

          def mark_stale_retirement_requests
            @handle.log(:info, 'Schedule - collecting stale Miq Retirement Requests')

            stale_retirement_requests = @handle.vmdb(:MiqRequest).where(
              "approval_state = 'approved' " \
                "AND type = 'ServiceRetireRequest' " \
                "AND status = 'Error' " \
                "AND message != 'Request timed out' " \
                "AND ((created_on + interval '1 hour') < NOW())"
            )
            @handle.log(:info, "Schedule - founded #{stale_retirement_requests.size} stale Miq Retirement Request records")

            service_retire_reload_count = retire_stale_services(stale_retirement_requests)
            return if service_retire_reload_count.zero?

            @handle.log(:info, "Schedule - created #{service_retire_reload_count} retire requests")
          end

          def retire_stale_services(stale_retirement_requests)
            stale_retirement_requests.each do |request|
              request.object_send(:update, message: 'Request timed out')
              request.object_send(:update, request_state: 'finished') if %w[active queued pending].include?(request.request_state)
            end
            create_new_requests(stale_retirement_requests)
          end

          def create_new_requests(stale_retirement_requests)
            service_retire_reload_count = 0
            service_ids = stale_retirement_requests.collect { |req| req.options[:src_ids] }.flatten.uniq
            service_ids.each do |service_id|
              service = @handle.vmdb(:Service).find_by(id: service_id)
              next unless service

              service.retirement_state = nil
              service.vms.each { |vm| vm.retirement_state = nil }
              @handle.execute(:create_retire_request, service)
              service_retire_reload_count += 1
            end
            service_retire_reload_count
          end
        end
      end
    end
  end
end

Platform::Automation::System::Methods::MarkStaleServiceRequests.new.main
