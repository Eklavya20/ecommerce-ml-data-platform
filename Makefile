.PHONY: up down reset install profile baseline delta debug freshness build docs

up:
	docker compose up -d

down:
	docker compose down

reset:
	docker compose down -v
	docker compose up -d

install:
	python -m pip install -r requirements.txt

profile:
	cp dbt/profiles.yml.example dbt/profiles.yml

baseline:
	python -m data_generator.generate_and_load --seed 42 --scale 1 --batch baseline

delta:
	python -m data_generator.generate_and_load --seed 42 --scale 1 --batch delta

debug:
	dbt debug --project-dir dbt --profiles-dir dbt

freshness:
	dbt source freshness --project-dir dbt --profiles-dir dbt

build:
	dbt build --project-dir dbt --profiles-dir dbt

docs:
	dbt docs generate --project-dir dbt --profiles-dir dbt

