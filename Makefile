#Makefile
up:
	docker compose up --build
down:
	docker compose down
Logs:
	docker compose logs -f