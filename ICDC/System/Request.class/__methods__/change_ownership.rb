new_owner_userid = $evm.root['dialog_new_owner_userid']
service = $evm.root['Service']
old_owner = $evm.vmdb(:User).find_by(:id => service.evm_owner_id)
new_owner = $evm.vmdb(:User).find_by(:userid => new_owner_userid)

$evm.log(:info, "OBEKASOV #{new_owner_userid}")
$evm.log(:info, "OBEKASOV #{service.inspect}")
$evm.log(:info, "OBEKASOV #{old_owner.inspect}")
$evm.log(:info, "OBEKASOV #{new_owner.inspect}")

$evm.log(:info, "OBEKASOV #{$evm.root['user'].id}")
$evm.log(:info, "OBEKASOV #{service.evm_owner_id}")

# exit MIQ_OK if $evm.root['user'].id != service.evm_owner_id
exit MIQ_OK unless defined?(old_owner) && defined?(new_owner) && defined?(service)
old_account_id = $evm.vmdb(:Tenant).find_by(:id => service.tenant_id).account.id
new_account_id = $evm.vmdb(:Tenant).find_by(:id => new_owner.current_group.tenant_id).account.id
exit MIQ_OK unless old_account_id == new_account_id

service.owner = new_owner
service.group = new_owner.current_group
service.vms.each do |vm|
  vm.owner = new_owner
  vm.group = new_owner.current_group
end

# sending email to new owner
owners_info = {}
owners_info["new_name"] = new_owner.name
owners_info["new_email"] = new_owner.userid
owners_info["old_name"] = old_owner.name
owners_info["old_email"] = old_owner.userid
$evm.set_state_var(:owners_info, owners_info)
$evm.instantiate("/Service/Email/Email/OwnershipChanging")
