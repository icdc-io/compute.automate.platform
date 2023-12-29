#
# Developer: ahrechushkin@ibagroup.eu
#
module Platform
  module Automate
    module Service
      module Email
        class ChangeNetworkType
          def initialize(handle = $evm)
            @handle = handle
            @handle.instantiate('/Configuration/Email/Default')
            @handle.instantiate('/Configuration/Location/Default')
            @email_attributes = @handle.object('/Configuration/Email/Default').attributes
  	    @location_attributes = @handle.object('/Configuration/Location/Default').attributes
            @network_name = @handle.root['new_network_name']
            @service = @handle.root['service']
            @vm = @handle.root['vm']
            @location = @service.region_description.downcase
            @cpv_domain = "#{ENV['CPV_NAME'].downcase}.io"
          end
          
          def send_email
            main_links
            email_params
            @handle.log(:info, "Sending email to <#{@to}> from <#{@from}>")
  	    @handle.execute('send_email', @to, @from, @subject, @body)
          end
          
          private
          
          def main_links
            @link_service = "https://compute.#{@location}.#{@cpv_domain}/ui/service/services/#{@service.id}"
            @link_vm = "#{@link_service}/resource=#{@vm.id}"
            link_help = "https://help.#{@cpv_domain}"
            url_segment = @cpv_domain == 'icdc.io' ? 'Services' : 'Use_of_the_Services'
            @link_help_share = "#{link_help}/compute/en/#{url_segment}/Networks/network_change.html"
          end
          
          def email_params
            owner = @service.evm_owner
            @to = owner.email
            @from = @email_attributes['from'].to_s
            @subject = "[Compute] Change network type for VM #{@vm.name} in service #{@service.name}"
            @body = "<h3>Hello, #{owner.name}!</h3>"
            @body += "Your network type was changed for VM - <a href='#{@link_vm}'>#{@vm.name}</a> in service - <a href='#{@link_service}'>#{@service.name}</a>"
            @body += "<br>New network is #{@network_name}"
            @body += "<br><br><a href='#{@link_help_share}'>More info</a> on changing the network type.<br><br>"
            @body += @email_attributes['signature']
          end
        end
      end
    end
  end
end
