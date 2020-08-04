#
# Developer: ahrechushkin@ibagroup.eu
#
service = $evm.root['service']
service_id = service.id.to_i
owner = service.evm_owner

link_service = "#{$evm.object['miq_service_url']}#{service.id}"
link_help = $evm.object['miq_help']
link_help_share = "#{link_help}/Use_of_the_Services/Networks/Networks.html"

footer = $evm.object['footer']
from = $evm.object['from']
to = owner.email

subject = "[ICDC.IO] Change network type - #{service['name']}"
body = "<h3>Hello!, #{owner.name}</h3>"
body += "Your network type was changed for service - <a href='#{link_service}'>#{service.name}</a>"
body += "<br><br><a href='#{link_help_share}'>More info</a>.<br><br>"
body += footer.to_s

$evm.log("info", "Sending email to <#{to}> from <#{from}>")
$evm.execute('send_email', to, from, subject, body)
