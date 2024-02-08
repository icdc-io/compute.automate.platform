module Platform
  module Automate
    module Service
      module Email
        class OwnershipChanging
          def initialize(handle = $evm)
            @handle = handle
            @handle.instantiate('/Configuration/Email/Default')
            @handle.instantiate('/Configuration/Location/Default')
            attributes = @handle.object('/Configuration/Email/Default').attributes
            @footer = attributes['signature'].to_s
            @from = attributes['from'].to_s
            @service = @handle.root['Service']
            @location = @service.region_description.downcase
            @cpv_domain = @handle.object('/Configuration/Location/Default').attributes['cpv_domain']
          end

          def send_email
            main_links
            email_params
            @handle.log('info', "Sending email to <#{@to}> from <#{@from}> subject: <#{@subject}>")
            @handle.execute('send_email', @to, @from, @subject, @body)
          end

          private

          def main_links
            @service_url = "compute.#{@location}.#{@cpv_domain}/ui/service/services/#{@service.id}"
            @help_link = "https://help.#{@cpv_domain}/compute/en/Services/Configuration/Change_Service_Ownership.html"
          end

          def email_params
            owners_info = @handle.get_state_var(:owners_info)
            @new_owner_name = owners_info['new_name']
            @old_owner_name = owners_info['old_name']
            @old_owner_email = owners_info['old_email']
            @to = owners_info['new_email']
            @subject = "[Compute] Change ownership of service- #{@service.name}"
            @body = message_body
          end

          def message_body
            body = "<h3>Hello, #{@new_owner_name}!</h3>"
            body += "User #{@old_owner_name}(#{@old_owner_email}) transferred the services with the following configuration:" \
                    "<table  border='1'>"\
                        '<tr>'\
                            '<td>Service name</td>'\
                            "<td>#{@service.name}</td>"\
                            '<td>User / Password</td>'\
                            '<td>Configuration</td>'\
                        '</tr>'

            @service.vms.each do |vm|
              next unless vm.ipaddresses * ', ' != ''

              # in line with CPU rubocop don't understand "/" symbol after 80th position
              body += '<tr>'\
                            "<td>VM <strong>#{vm.name}</strong></td>"\
                            "<td>#{vm.ipaddresses * ', '}</td>"\
                            '<td>ask previous owner, please</td>'\
                            "<td>CPU #{vm.cpu_total_cores} / RAM #{vm.ram_size / 1024}  Gb "\
                            "/ Storage  #{vm.allocated_disk_storage / 1024**3} Gb "\
                            '</td>'\
                        '</tr>'
            end

            body += if @service.vms.count.zero?
                      '<tr>'\
                          '<td>VM<td>'\
                          '<td>the service doesn`t have any vm</td>'\
                      '</tr>'
                    else
                      '<tr>'\
                          '<td>HTML5-console</td>'\
                          "<td><a href='https://#{@service_url}'>#{@service_url}</a></td>"\
                          '<td></td>'\
                          '<td></td>'\
                      '</tr>'\
                      '<tr>'\
                          '<td>Other access types</td>'\
                          "<td><a href='https://help.#{@cpv_domain}/compute/en/Services/VM/Service_Access.html'>read more</a></td>"\
                          '<td></td>'\
                          '<td></td>'\
                      '</tr>'
                    end

            body += '</table>'
            body += "<br><br><a href='#{@help_link}'>More info</a><br><br>"
            body += @footer
            body
          end
        end
      end
    end
  end
end
