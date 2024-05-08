#
# Description: <Method description here>
#

$evm.log(:info, $evm.root['vm'].evm_owner_email)

body  = "<table border='1'>\n"
body += "  <tr><td>VM Name</td><td>#{$evm.root['vm'].name}</td></tr>\n"
body += "  <tr><td>Username</td><td>#{$evm.root['dialog_username']}</td></tr>\n"
body += "  <tr><td>Temporary Password</td><td>#{$evm.get_state_var(:vm_password)}</td></tr>\n"
body += "</table>\n"

$evm.object['body'] = body
