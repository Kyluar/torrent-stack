.PHONY: up down start stop logs clean restart help jackett

BASE := docker compose -f docker-compose.yml
BASH ?= bash

up: 
	$(BASE) up -d

start:
	$(BASE) start

stop: 
	$(BASE) stop

down: 
	$(BASE) down

restart: 
	$(BASE) restart

logs: 
	$(BASE) logs -f

clean: 
	$(BASE) down -v --remove-orphans

jackett:
	"$(BASH)" ./scripts/set-jackett-config.sh

help:
	@echo "Available Commands:"
	@echo "  up              : Creates and starts containers"
	@echo "  start           : Starts containers"
	@echo "  stop            : Stops containers"
	@echo "  down            : Stops and removes containers"
	@echo "  restart         : Restarts containers"
	@echo "  logs            : Shows the logs on real time"
	@echo "  clean           : Cleans up resources"
	@echo "  jackett         : Sets Jackett API key and URL in qBittorrent plugin config"
