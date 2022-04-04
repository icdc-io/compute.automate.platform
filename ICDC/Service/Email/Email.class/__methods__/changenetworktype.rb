#
# Developer: ahrechushkin@ibagroup.eu
#
$evm.instantiate("/ICDC/Service/Email/Email/Email")

def send_email
  attributes = $evm.object("/ICDC/Service/Email/Email/Email").attributes
  service = $evm.root['service']
  service_id = service.id.to_i
  owner = service.evm_owner
  footer = attributes["footer"]
  to = owner.email
  from = attributes["from"].to_s
  link_service = "#{attributes["miq_service_url"].to_s}#{service.id}"
  link_help = attributes["miq_help"].to_s
  link_help_share = "#{link_help}/compute/ru/Use_of_the_Services/Networks/network_change.html"
  subject = "[ICDC.IO] Change network type - #{service['name']}"
  body = "<h3>Hello, #{owner.name}!</h3>"
  body += "Your network type was changed for service - <a href='#{link_service}'>#{service.name}</a>"
  body += "<br><br><a href='#{link_help_share}'>More info</a>on changing the network type.<br><br>"
  body += footer

  $evm.log(:info, "Sending email to <#{to}> from <#{from}>")
  $evm.execute('send_email', to, from, subject, body)
end
