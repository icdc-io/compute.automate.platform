# TODO: remove this functionality, we going to get rid of this in Compute Global UI
module Platform
  module Automate
    module Service
      module Email
        class SharingService
          def initialize(handle = $evm)
            @handle = handle
            @handle.instantiate('/Configuration/Email/Default')
            @handle.instantiate('/Configuration/Location/Default')
            attributes = @handle.object('/Configuration/Email/Default').attributes
            @footer = attributes['signature'].to_s
            @from = attributes['from']
            @cpv_domain = @handle.object('/Configuration/Location/Default').attributes['cpv_domain']
            @owner_name = @handle.vmdb(:User).find_by(:id => @handle.root['ownerId'])['name']
            @service = @handle.vmdb(:Service).find_by(:id => @handle.root['serviceId'].to_i)
            @location = @service.region_description.downcase
          end

          def send_emails
            main_links
            email_params
            @handle.log('info', "Sending email to <#{@to}> from <#{@from}>")
            @handle.execute('send_email', @to, @from, @subject, @body)
          end
          
          private
          
          def users_emails
            users_emails = @handle.root['userList']
            users_shared = []
            @to = []
            email_regex = /[a-zA-Z0-9]+\@[a-zA-Z0-9]+\.[a-zA-Z0-9]+/
            users_emails.scan(email_regex).each do |matched_email|
              if users_shared.push($evm.vmdb(:User).find_by(:email => matched_email))
                @to.push(matched_email)
              end
            end
          end
          
          def main_links
            @link_service = "https://compute.#{@location}.#{@cpv_domain}/ui/service/services/#{@service.id}"
            @link_docs = "https://docs.#{@cpv_domain}/en/compute/dedicated_ui/services/sharing_service/"
          end
          
          def email_params
            users_emails
            @subject = "[Compute] Common access - #{@service['name']}"
            @body = "<h3>Hello!</h3>"
            @body += "User #{@owner_name} has given you access to the service: <a href='#{@link_service}'>#{@service['name']}</a>"
            @body += "<br><br><a href='#{@link_docs}'>More info</a> on sharing the service.<br><br>"
            @body += @footer
          end
        end
      end
    end
  end
end

Platform::Automate::Service::Email::SharingService.new.send_emails
