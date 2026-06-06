A bare-bones Dart web app.

Uses [`package:web`](https://pub.dev/packages/web)
to interop with JS and the DOM.

## Running and building

To run the app,
activate and use [`package:webdev`](https://dart.dev/tools/webdev):

```
dart pub global activate webdev
webdev serve
```

To build a production version ready for deployment,
use the `webdev build` command:

```
webdev build
```

To learn how to interop with web APIs and other JS libraries,
check out https://dart.dev/interop/js-interop.

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