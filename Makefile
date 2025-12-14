encrypt_secrets: 
	sops --encrypt --age $(SOPS_PUBLIC_KEY) secrets.yaml > secrets.enc.yaml
tflint:
	tflint --recursive --fix
