$evm.instantiate("/ICDC/Service/Email/Email/Email")

attributes = $evm.object("/ICDC/Service/Email/Email/Email").attributes
footer = attributes["footer"].to_s

owner_id = $evm.root['ownerId']
owner = $evm.vmdb(:User).find_by(:id => owner_id)

from = attributes["from"]
users_emails = $evm.root['userList']
users_shared = []
to = []
email_regex = /[a-zA-Z0-9]+\@[a-zA-Z0-9]+\.[a-zA-Z0-9]+/
users_emails.scan(email_regex).each do |matched_email|
  if users_shared.push($evm.vmdb(:User).find_by(:email => matched_email))
    to.push(matched_email)
  end
end

service_id = $evm.root['serviceId'].to_i
service = $evm.vmdb(:Service).find_by(:id => service_id)

link_service = "#{attributes['miq_service_url']}#{service.id}"
link_help = attributes['miq_help']
link_help_share = "#{link_help}/compute/ru/Use_of_the_Services/Sharing_Service.html"

subject = "[ICDC.IO] Common access - #{service['name']}"
body = "<h3>Hello!</h3>"
body += "User #{owner['name']} has given you access to the service:: <a href='#{link_service}'>#{service['name']}</a>"
body += "<br><br><a href='#{link_help_share}'>More info</a> on sharing the service.<br><br>"
body += footer

$evm.log("info", "Sending email to <#{to}> from <#{from}>")
$evm.execute('send_email', to, from, subject, body)
