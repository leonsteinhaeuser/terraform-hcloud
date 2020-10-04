clear:
	terraform plan -destroy -var 'hcloud_token=$(TF_HCLOUD_TOKEN)'

test:
	terraform plan -var 'hcloud_token=$(TF_HCLOUD_TOKEN)'

# export TF_HCLOUD_TOKEN='token generated by hetzner'
init:
	terraform init

apply:
	terraform apply -var 'hcloud_token=$(TF_HCLOUD_TOKEN)'

destroy:
	terraform destroy -var 'hcloud_token=$(TF_HCLOUD_TOKEN)'
