.PHONY: bootstrap platform preflight check apply storage storage-init apps backup seal syntax
bootstrap:
	ansible-playbook playbooks/bootstrap.yml
platform:
	ansible-playbook playbooks/platform.yml
preflight:
	ansible-playbook playbooks/preflight.yml
check:
	ansible-playbook playbooks/site.yml --check --diff
apply:
	ansible-playbook playbooks/site.yml
storage:
	ansible-playbook playbooks/storage.yml
storage-init:
	ansible-playbook playbooks/storage.yml -e allow_destructive_storage_init=true
apps:
	ansible-playbook playbooks/apps.yml
backup:
	ansible-playbook playbooks/backup.yml
seal:
	scripts/seal-secrets.sh
syntax:
	ansible-playbook playbooks/site.yml --syntax-check
