require 'nokogiri'

path = $evm.root['dialog_path']
params = $evm.root['dialog_params']
# FIX ASAP ICDC-G
options_hash = JSON.parse(params.gsub('=>', ':'))
# END FIX

# options_hash = JSON.parse(params)
# FIX: quick fix for doubled params https://support.icdc.io/issues/5426
# if options_hash.key?("params")
#  options_hash = JSON.parse(options_hash["params"])
# end

$evm.log(:info, "Call automation: #{path} with options: #{options_hash.inspect}")
unless options_hash.empty?
  options_hash.each do |key, value|
    $evm.root[key.to_s] = value.to_s
    $evm.set_state_var(key, value)
  end
end

$evm.instantiate(path)
