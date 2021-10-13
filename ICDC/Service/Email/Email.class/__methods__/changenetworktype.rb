#
# Developer: ahrechushkin@ibagroup.eu
#
$evm.instantiate("/TemplateProvisioning/Configuration/Email/Default")
def send_email
  attributes = $evm.object("/TemplateProvisioning/Configuration/Email/Default").attributes
  signature = attributes["signature"].to_s
  service = $evm.root['service']
  service_id = service.id.to_i
  owner = service.evm_owner

  link_service = "#{$evm.object['miq_service_url']}#{service.id}"
  link_help = $evm.object['miq_help']
  link_help_share = "#{link_help}/Use_of_the_Services/Networks/Networks.html"

  footer = $evm.object['footer']
  to = owner.email
  from = attributes["from"].to_s
  miq_help = attributes["miq_help"].to_s

  subject = "[ICDC.IO] Change network type - #{service['name']}"
  body = "<h3>Hello, #{owner.name}!</h3>"
  body += "Your network type was changed for service - <a href='#{link_service}'>#{service.name}</a>"
  body += "<br><br><a href='#{miq_help}'>More info</a>.<br><br>"
  body += signature

  $evm.log(:info, "Sending email to <#{to}> from <#{from}>")
  $evm.execute('send_email', to, from, subject, body)
end
