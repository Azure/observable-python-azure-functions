SHELL=/bin/bash

create-env:
	virtualenv .venv -p python3.9

deploy-infra:
	@./scripts/deploy-infra.sh

deploy-app:
	@./scripts/publish-functionapp.sh

deploy-all:
	make deploy-infra
	make deploy-app
