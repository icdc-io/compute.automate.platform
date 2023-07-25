$evm.log(:info, "open external url #1")
vm = $evm.vmdb(:Vm).all.first
$evm.log(:info, "open external url")
vm.external_url = "https://www.linkedin.com"
