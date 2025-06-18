# Boot strap DJango Project

## Features

- `python: 3.13.5`
- `django: 5.2.3`
- `Docker V2`
- `redis 8,0,0`
- `poetry 2.1.3`
- config via `.env`

## Command

- Setup
```sh
sh setup.sh my-project-name
```
- Start server
```sh
docker compose up --build
```
- Shutdown server
```sh
docker compose down
```
- View logs
```sh
# Terminal Output
tail -f logs/django.log

# Docker view
docker compse ps
## Web App
docker compose logs web -f
## Redis
docker compose logs redis -f
```

- Ping Redis
```sh
redis-cli PING
# OR
redis-cli -h 127.0.0.1 -p 6379 PING
```

## Appendix

### References

- [Project Structure Article](https://medium.com/django-unleashed/django-project-structure-a-comprehensive-guide-4b2ddbf2b6b8)

