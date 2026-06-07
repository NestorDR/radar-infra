:: Remove the Terraform add-ons and cached status files to be able to reset a clean state
rmdir /s /q .terraform
del .terraform.lock.hcl
del terraform.tfstate
del terraform.tfstate.backup