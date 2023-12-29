module Platform
  module Automate
    module Service
      module Email
        class SharingService
          def initialize(handle = $evm)
            @handle = handle
            @handle.instantiate('/Configuration/Email/Default')
            attributes = @handle.object('/Configuration/Email/Default').attributes
            @footer = attributes['signature'].to_s
            @from = attributes['from']
            @cpv_domain = "#{ENV['CPV_NAME'].downcase}.io"
            @owner_name = @handle.vmdb(:User).find_by(:id => @handle.root['ownerId'])['name']
            @service = @handle.vmdb(:Service).find_by(:id => @handle.root['serviceId'].to_i)
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
            @link_service = "https://compute.#{@service.region_description.downcase}.#{@cpv_domain}/ui/service/services/#{@service.id}"
            link_help = "https://help.#{@cpv_domain}"
            url_segment = @cpv_domain == 'icdc.io' ? 'Services' : 'Use_of_the_Services'
            @link_help_share = "#{link_help}/compute/en/#{url_segment}/Sharing_Service.html"
          end
          
          def email_params
            users_emails
            @subject = "[Compute] Common access - #{@service['name']}"
            @body = "<h3>Hello!</h3>"
            @body += "User #{@owner_name} has given you access to the service:: <a href='#{@link_service}'>#{@service['name']}</a>"
            @body += "<br><br><a href='#{@link_help_share}'>More info</a> on sharing the service.<br><br>"
            @body += @footer
          end
        end
      end
    end
  end
end

Platform::Automate::Service::Email::SharingService.new.send_emails
