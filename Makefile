# Variables
APP_NAME := chatwoot
RAILS_ENV ?= development
STACKLAB_ENABLED ?= true

# Targets
setup:
	gem install bundler
	bundle install
	pnpm install

db_create:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:create

db_migrate:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:migrate

db_seed:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:seed

db_reset:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:reset

db:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:chatwoot_prepare

console:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails console

server:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails server -b 0.0.0.0 -p 3000

burn:
	bundle && pnpm install

run:
	@if [ -f ./.overmind.sock ]; then \
		echo "Overmind is already running. Use 'make force_run' to start a new instance."; \
	else \
		overmind start -f Procfile.dev; \
	fi

force_run:
	rm -f ./.overmind.sock
	overmind start -f Procfile.dev

debug:
	overmind connect backend

debug_worker:
	overmind connect worker

docker: 
	docker buildx build --builder cloud-stacklabdigital-stacklab-cloud-builder -t stacklabdigital/kanban:v2.7.1 --build-arg STACKLAB_ENABLED=$(STACKLAB_ENABLED) --push -f ./docker/Dockerfile .

# Build sem stacklab (Community Edition)
docker-ce:
	$(MAKE) docker STACKLAB_ENABLED=false

.PHONY: setup db_create db_migrate db_seed db_reset db console server burn docker docker-ce run force_run debug debug_worker
