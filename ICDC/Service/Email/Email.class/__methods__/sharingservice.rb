owner_id = $evm.root['ownerId']
owner = $evm.vmdb(:User).find_by(:id => owner_id)

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

link_service = "#{$evm.object['miq_service_url']}#{service.id}"
link_help = $evm.object['miq_help']
link_help_share = "#{link_help}/ru/Use_of_the_Services/Sharing_Service"

footer = $evm.object['footer']
from = $evm.object['from']

subject = "[ICDC.IO] Common access - #{service['name']}"
body = "<h3>Hello!</h3>"
body += "User #{owner['name']} has given you access to the service:: <a href='#{link_service}'>#{service['name']}</a>"
body += "<br><br><a href='#{link_help_share}'>More info</a> on sharing the service.<br><br>"
body += footer.to_s

$evm.log("info", "Sending email to <#{to}> from <#{from}>")
$evm.execute('send_email', to, from, subject, body)
