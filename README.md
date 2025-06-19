# Bootstrap Django Project

## Features

- `python: 3.13.5`
- `django: 5.2.3`
- `Docker V2`
- `django-redis 6.0.0`
- `poetry 2.1.3`
- `django-prometheus 2.4.0 `
- `prometheus`
- `grafana`
- config via `.env`

## Command

### Setup

- To do your own set-up you only need setup file.

```sh
sh setup.sh my-project-name
```

### Maintain server

#### Server
- Start server
```sh
docker compose up --build
```
- Shutdown server
```sh
docker compose down
```
- Docker view
```sh
docker compse ps
```
- Ping Redis
```sh
redis-cli PING
# OR
redis-cli -h 127.0.0.1 -p 6379 PING
```
- Swagger
```
http://localhost:8000/swagger/#/
```
#### Watch Metrics 
- At port
```sh
http://localhost:8000/metrics
```
- At Grafana
```sh
http://localhost:3000/
```
#### View logs
- Terminal Output
```sh
tail -f logs/django.log
```

- Web App
```sh
docker compose logs web -f
```
- Redis
```sh
docker compose logs redis -f
```

## Appendix

### References

- [Project Structure Article](https://medium.com/django-unleashed/django-project-structure-a-comprehensive-guide-4b2ddbf2b6b8)

