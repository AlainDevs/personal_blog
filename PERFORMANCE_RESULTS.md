# Performance Test Results

This file is generated from the latest `wrk` benchmark output by
[`scripts/performance/generate_report.js`](scripts/performance/generate_report.js).
Do not edit the benchmark numbers by hand; regenerate this file with
`npm run performance:report`.

## Summary

| Metric | Result |
| --- | ---: |
| Generated at | `2026-06-06T15:04:50.523Z` |
| Benchmark tool | `wrk` with Lua request mix |
| Target | `http://app:8080` |
| Threads | `1` |
| Connections | `4` |
| Duration | `2s` |
| Timeout | `5s` |
| Total requests | `1,877` |
| Requests per second | `935.31` |
| Transfer per second | `8.39 MB` |
| Data read | `16.84 MB` |
| Average latency | `4.27ms` |
| Max latency | `9.88ms` |
| 99th percentile latency | `7.45ms` |
| Socket errors | `none reported` |
| Non-2xx/3xx responses | `none reported` |

> Note: benchmark results vary by host machine, Docker resource limits, warm-up
> state, and selected load settings. Compare results only when the command,
> machine context, request mix, and database state are comparable.

## Test environment

- Date: 2026-06-06T15:04:50.523Z
- Host operating system: Darwin 25.5.0 (darwin, arm64)
- Node.js: v22.22.0
- Test runner: Docker Compose performance stack
- Application image: built from the project `Dockerfile`
- Database: isolated PostgreSQL 18 service with a dedicated performance volume
- Benchmark image: local Alpine-based `wrk` image built from source
- Readiness check: benchmark waits for `/` and
  `/blog/building-a-calmer-personal-blog` before starting

## Report generation command

```shell
WRK_THREADS=1 \
WRK_CONNECTIONS=4 \
WRK_DURATION=2s \
WRK_TIMEOUT=5s \
PERF_APP_PORT=8081 \
npm run performance:report
```

## Benchmark command executed

```shell
WRK_THREADS=1 \
WRK_CONNECTIONS=4 \
WRK_DURATION=2s \
WRK_TIMEOUT=5s \
PERF_APP_PORT=8081 \
docker compose -f docker-compose.performance.yml up --build --abort-on-container-exit --exit-code-from wrk wrk
```

Cleanup after the benchmark:

```shell
docker compose -f docker-compose.performance.yml down -v
```

Cleanup status: **passed**.

## Request mix

The benchmark used the weighted route mix printed by
[`scripts/performance/request_mix.lua`](scripts/performance/request_mix.lua).

| Weight | Route | Purpose |
| ---: | --- | --- |
| 50.0% | `/` | Homepage with published posts from the database |
| 25.0% | `/blog/building-a-calmer-personal-blog` | Seeded blog detail page |
| 10.0% | `/blog/a-tiny-publishing-checklist` | Seeded blog detail page |
| 10.0% | `/output.css` | Generated stylesheet |
| 5.0% | `/public/app.js` | Public JavaScript asset |

## Raw benchmark output

```text
Waiting for http://app:8080 to serve seeded pages...
curl: (7) Failed to connect to app port 8080 after 0 ms: Could not connect to server
Attempt 1: application is not ready yet.
Application is ready.
Running wrk against http://app:8080
threads=1 connections=4 duration=2s timeout=5s
Running 2s test @ http://app:8080
  1 threads and 4 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     4.27ms    1.72ms   9.88ms   81.11%
    Req/Sec     0.94k    76.03     1.09k    85.00%
  Latency Distribution
     50%    4.76ms
     75%    5.04ms
     90%    5.35ms
     99%    7.45ms
  1877 requests in 2.01s, 16.84MB read
Requests/sec:    935.31
Transfer/sec:      8.39MB

Configured request mix:
   50.0%  /
   25.0%  /blog/building-a-calmer-personal-blog
   10.0%  /blog/a-tiny-publishing-checklist
   10.0%  /output.css
    5.0%  /public/app.js
```

## Validation checks

| Command | Status |
| --- | --- |
| `docker compose -f docker-compose.performance.yml config --quiet` | Passed |
| `dart analyze` | Passed |
| `dart test --timeout=30s` | Passed |

## How to run a longer benchmark

Use the default benchmark documented in [`README.md`](README.md):

```shell
npm run performance:report
```

Or increase the load:

```shell
WRK_THREADS=8 \
WRK_CONNECTIONS=128 \
WRK_DURATION=60s \
WRK_TIMEOUT=10s \
npm run performance:report
```

For a fast smoke report, run:

```shell
npm run performance:report:smoke
```
