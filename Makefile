up:
	docker compose up -d

build:
	docker compose up -d --build

down:
	docker compose down

bash:
	docker compose exec app bash

logs:
	docker compose logs -f

test:
	bundle exec rspec spec zip_code_endpoint_spec.rb

install-deps:
	docker compose exec app bundle install