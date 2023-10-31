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
                "AND status = 'Ok' AND process = TRUE " \
                "AND (source_type IS NULL OR (source_type = 'VmOrTemplate' AND source_id IN (SELECT id FROM vms)) " \
                "OR (source_type = 'ServiceTemplate' AND source_id IN (SELECT id FROM service_templates))) " \
                "AND ((created_on + interval '1 hour') < NOW())"
            )

            @handle.log(:info, "Schedule - founded #{stale_provision_requests.size} stale Miq Provision Request records")
            return if stale_provision_requests.empty?

            stale_provision_requests.each do |request|
              request.object_send(:update, status: 'Error', message: 'Request timed out')
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
            service_retire_reload_count = 0

            stale_retirement_requests.each do |request|
              service_id = request.options[:src_ids][0]
              service = @handle.vmdb(:Service).find_by(id: service_id)
              next unless service
              next if service.retirement_state != 'retiring' && service.retired

              service.retirement_state = nil
              @handle.execute(:create_retire_request, service)

              request.object_send(:update, message: 'Request timed out')
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
