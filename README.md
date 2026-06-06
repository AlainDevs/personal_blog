A bare-bones Dart web app.

Uses [`package:web`](https://pub.dev/packages/web)
to interop with JS and the DOM.

## Run with Docker Compose

This project has one beginner-friendly way to start and deploy it: Docker
Compose. You do not need to install Dart, Node.js, PostgreSQL, or WebDev on your
computer. Docker builds the app and starts the database for you.

### 1. Install Docker

Install Docker Desktop on macOS or Windows, or Docker Engine with Docker Compose
on Linux. After installing Docker, check that these commands work:

```shell
docker --version
docker compose version
```

### 2. Start the blog

From this project folder, run:

```shell
docker compose up --build
```

The first start can take a few minutes because Docker downloads the base images,
installs dependencies, builds the server, builds the CSS, and starts PostgreSQL.

### 3. Open the website

When the containers are running, open the blog in your browser:

```text
http://localhost:8080
```

The database is created automatically. It also includes demo content and two
users you can use right away:

| Role | Email | Username | Password |
| --- | --- | --- | --- |
| Admin | `admin@example.com` | `admin` | `AdminPass123!` |
| Reader | `reader@example.com` | `reader` | `ReaderPass123!` |

Use the admin account to open the admin area:

```text
http://localhost:8080/admin
```

### 4. Stop the blog

Press `Ctrl+C` in the terminal running Docker Compose, then run:

```shell
docker compose down
```

### 5. Start again later

Use the same command again whenever you want to start the blog:

```shell
docker compose up --build
```

Your database data is kept in a Docker volume, so posts and users remain after
stopping the containers.

### 6. Reset the database only when needed

If you want to delete all local database data and return to the demo content,
run:

```shell
docker compose down -v
docker compose up --build
```

## Performance testing

A separate Docker Compose stack is available for local performance testing with
Lua `wrk`. It builds the same application image as the main stack, starts an
isolated PostgreSQL database, waits for seeded public pages to become available,
and then runs a weighted request mix against the website. The latest recorded
benchmark output is generated into [PERFORMANCE_RESULTS.md](PERFORMANCE_RESULTS.md).

Generate a fresh GitHub-ready benchmark report:

```shell
npm run performance:report
```

Run a shorter smoke report while developing:

```shell
npm run performance:report:smoke
```

Run the default benchmark directly without updating the report:

```shell
docker compose -f docker-compose.performance.yml up --build --abort-on-container-exit --exit-code-from wrk wrk
```

The website remains reachable from the host at `http://localhost:8081` while the
performance stack is running. Change the host port if needed:

```shell
PERF_APP_PORT=8090 docker compose -f docker-compose.performance.yml up --build --abort-on-container-exit --exit-code-from wrk wrk
```

Tune the benchmark load with environment variables:

```shell
WRK_THREADS=8 \
WRK_CONNECTIONS=128 \
WRK_DURATION=60s \
WRK_TIMEOUT=10s \
docker compose -f docker-compose.performance.yml up --build --abort-on-container-exit --exit-code-from wrk wrk
```

Override the weighted request mix with comma-separated paths. Add `=weight` to a
path to make it more or less frequent:

```shell
WRK_PATHS='/=70,/blog/building-a-calmer-personal-blog=20,/output.css=10' \
docker compose -f docker-compose.performance.yml up --build --abort-on-container-exit --exit-code-from wrk wrk
```

Remove the isolated performance database volume when you want a clean run:

```shell
docker compose -f docker-compose.performance.yml down -v
```