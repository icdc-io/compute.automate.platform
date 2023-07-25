#
# Developer: ahrechushkin@ibagroup.eu
#
$evm.instantiate("/Configuration/Email/ServiceActions")

def send_email
  attributes = $evm.object("/Configuration/Email/ServiceActions").attributes
  service = $evm.root['service']
  service_id = service.id.to_i
  owner = service.evm_owner
  footer = attributes['footer']
  to = owner.email
  from = attributes["from"].to_s
  link_service = "https://compute.#{location}.#{ENV['CPV_NAME'].downcase}.io/ui/service/services/#{service.id}"
  link_help = attributes["miq_help"].to_s
  link_help_share = "#{link_help}/compute/ru/Use_of_the_Services/Networks/network_change.html"
  subject = "[#{ENV['CPV_NAME']}.IO] Change network type - #{service['name']}"
  body = "<h3>Hello, #{owner.name}!</h3>"
  body += "Your network type was changed for service - <a href='#{link_service}'>#{service.name}</a>"
  body += "<br><br><a href='#{link_help_share}'>More info</a>on changing the network type.<br><br>"
  body += footer

  $evm.log(:info, "Sending email to <#{to}> from <#{from}>")
  $evm.execute('send_email', to, from, subject, body)
end

def location
  $evm.root['service'].region_description.downcase
end
