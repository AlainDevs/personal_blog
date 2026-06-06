#!/usr/bin/env node

const { spawn, spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const projectRoot = path.resolve(__dirname, '../..');
const composeFileName = 'docker-compose.performance.yml';
const composeFilePath = path.join(projectRoot, composeFileName);
const reportPath = path.join(
  projectRoot,
  process.env.PERFORMANCE_RESULTS_PATH || 'PERFORMANCE_RESULTS.md',
);

const defaultBenchmarkEnvironment = {
  WRK_THREADS: '4',
  WRK_CONNECTIONS: '64',
  WRK_DURATION: '30s',
  WRK_TIMEOUT: '5s',
  WRK_PATHS: '',
  PERF_APP_PORT: '8081',
};

const benchmarkEnvironment = {
  ...defaultBenchmarkEnvironment,
  ...pickDefined(process.env, Object.keys(defaultBenchmarkEnvironment)),
};

const runtimeEnvironment = {
  ...process.env,
  ...benchmarkEnvironment,
  COMPOSE_ANSI: 'never',
  COMPOSE_MENU: 'false',
  COMPOSE_PROGRESS: 'plain',
};

const composeUpCommand = [
  'docker',
  'compose',
  '-f',
  composeFileName,
  'up',
  '--build',
  '--abort-on-container-exit',
  '--exit-code-from',
  'wrk',
  'wrk',
];

const cleanupCommand = [
  'docker',
  'compose',
  '-f',
  composeFileName,
  'down',
  '-v',
];

const validationCommands = [
  ['docker', 'compose', '-f', composeFileName, 'config', '--quiet'],
  ['dart', 'analyze'],
  ['dart', 'test', '--timeout=30s'],
];

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

async function main() {
  assertFileExists(composeFilePath);

  const validationResults = await runValidationCommands();
  const benchmarkResult = await runBenchmarkWithCleanup();

  if (benchmarkResult.run.exitCode !== 0) {
    throw new Error(
      `wrk benchmark failed with exit code ${benchmarkResult.run.exitCode}.`,
    );
  }

  const wrkOutput = extractWrkOutput(benchmarkResult.run.output);
  const metrics = parseWrkOutput(wrkOutput);
  validateMetrics(metrics);

  const markdown = renderReport({
    cleanup: benchmarkResult.cleanup,
    metrics,
    validationResults,
    wrkOutput,
  });

  fs.writeFileSync(reportPath, markdown);
  console.log(`\nWrote ${path.relative(projectRoot, reportPath)}.`);

  if (benchmarkResult.cleanup.exitCode !== 0) {
    throw new Error(
      `Cleanup failed with exit code ${benchmarkResult.cleanup.exitCode}.`,
    );
  }
}

async function runValidationCommands() {
  if (process.env.SKIP_PERFORMANCE_VALIDATION === '1') {
    return validationCommands.map((command) => ({
      command,
      exitCode: 0,
      output: 'Skipped by SKIP_PERFORMANCE_VALIDATION=1.',
      skipped: true,
    }));
  }

  const results = [];

  for (const command of validationCommands) {
    const result = await runCommand(command);
    results.push(result);

    if (result.exitCode !== 0) {
      throw new Error(
        `Validation command failed: ${formatCommand(command)}.`,
      );
    }
  }

  return results;
}

async function runBenchmarkWithCleanup() {
  let run;

  try {
    run = await runCommand(composeUpCommand);
  } finally {
    const cleanup = runCleanup();

    if (!run) {
      return {
        run: {
          command: composeUpCommand,
          exitCode: 1,
          output: '',
        },
        cleanup,
      };
    }

    return { run, cleanup };
  }
}

function runCommand(command) {
  console.log(`\n$ ${formatCommand(command)}`);

  return new Promise((resolve, reject) => {
    const child = spawn(command[0], command.slice(1), {
      cwd: projectRoot,
      env: runtimeEnvironment,
      shell: false,
    });

    let output = '';

    child.stdout.on('data', (chunk) => {
      const text = chunk.toString();
      output += text;
      process.stdout.write(text);
    });

    child.stderr.on('data', (chunk) => {
      const text = chunk.toString();
      output += text;
      process.stderr.write(text);
    });

    child.on('error', reject);
    child.on('close', (exitCode) => {
      resolve({ command, exitCode, output });
    });
  });
}

function runCleanup() {
  console.log(`\n$ ${formatCommand(cleanupCommand)}`);

  const result = spawnSync(cleanupCommand[0], cleanupCommand.slice(1), {
    cwd: projectRoot,
    env: runtimeEnvironment,
    encoding: 'utf8',
  });

  if (result.stdout) {
    process.stdout.write(result.stdout);
  }

  if (result.stderr) {
    process.stderr.write(result.stderr);
  }

  return {
    command: cleanupCommand,
    exitCode: result.status ?? 1,
    output: `${result.stdout || ''}${result.stderr || ''}`,
  };
}

function extractWrkOutput(commandOutput) {
  const cleanOutput = stripAnsi(commandOutput).replace(/\r/g, '\n');
  const lines = cleanOutput.split('\n');
  const wrkLines = [];

  for (const line of lines) {
    const normalizedLine = removeControlCharacters(line).trimEnd();
    const match = normalizedLine.match(
      /(?:^|\s)(?:[\w.-]+-)?wrk-\d+\s+\|\s?(.*)$/,
    );

    if (match) {
      wrkLines.push(match[1]);
    }
  }

  if (wrkLines.length > 0) {
    return trimBlankLines(wrkLines).join('\n');
  }

  const fallbackStart = cleanOutput.indexOf('Waiting for ');
  if (fallbackStart >= 0) {
    return cleanOutput.slice(fallbackStart).trim();
  }

  return cleanOutput.trim();
}

function parseWrkOutput(wrkOutput) {
  const lines = wrkOutput.split(/\r?\n/).map((line) => line.trimEnd());
  const metrics = {
    latencyDistribution: {},
    requestMix: [],
  };

  for (const line of lines) {
    const targetMatch = line.match(/Running wrk against\s+(.+)$/);
    if (targetMatch) {
      metrics.target = targetMatch[1].trim();
      continue;
    }

    const configMatch = line.match(
      /threads=(\S+)\s+connections=(\S+)\s+duration=(\S+)\s+timeout=(\S+)/,
    );
    if (configMatch) {
      metrics.threads = configMatch[1];
      metrics.connections = configMatch[2];
      metrics.duration = configMatch[3];
      metrics.timeout = configMatch[4];
      continue;
    }

    const latencyMatch = line.match(
      /^\s*Latency\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/,
    );
    if (latencyMatch) {
      metrics.averageLatency = latencyMatch[1];
      metrics.latencyStdev = latencyMatch[2];
      metrics.maxLatency = latencyMatch[3];
      metrics.latencyStdevPercent = latencyMatch[4];
      continue;
    }

    const requestRateMatch = line.match(
      /^\s*Req\/Sec\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/,
    );
    if (requestRateMatch) {
      metrics.threadRequestsPerSecondAverage = requestRateMatch[1];
      metrics.threadRequestsPerSecondStdev = requestRateMatch[2];
      metrics.threadRequestsPerSecondMax = requestRateMatch[3];
      metrics.threadRequestsPerSecondStdevPercent = requestRateMatch[4];
      continue;
    }

    const percentileMatch = line.match(/^\s*(50|75|90|99)%\s+(\S+)/);
    if (percentileMatch) {
      metrics.latencyDistribution[percentileMatch[1]] = percentileMatch[2];
      continue;
    }

    const totalRequestsMatch = line.match(
      /^\s*([\d,]+)\s+requests in\s+([^,]+),\s+(\S+)\s+read/,
    );
    if (totalRequestsMatch) {
      metrics.totalRequests = totalRequestsMatch[1].replace(/,/g, '');
      metrics.elapsed = totalRequestsMatch[2];
      metrics.dataRead = totalRequestsMatch[3];
      continue;
    }

    const requestsPerSecondMatch = line.match(/Requests\/sec:\s+(\S+)/);
    if (requestsPerSecondMatch) {
      metrics.requestsPerSecond = requestsPerSecondMatch[1];
      continue;
    }

    const transferPerSecondMatch = line.match(/Transfer\/sec:\s+(\S+)/);
    if (transferPerSecondMatch) {
      metrics.transferPerSecond = transferPerSecondMatch[1];
      continue;
    }

    const socketErrorsMatch = line.match(/Socket errors:\s+(.+)$/);
    if (socketErrorsMatch) {
      metrics.socketErrors = socketErrorsMatch[1].trim();
      continue;
    }

    const nonSuccessMatch = line.match(/Non-2xx or 3xx responses:\s+([\d,]+)/);
    if (nonSuccessMatch) {
      metrics.nonSuccessResponses = nonSuccessMatch[1].replace(/,/g, '');
    }
  }

  const requestMixStart = lines.findIndex((line) =>
    line.includes('Configured request mix:'),
  );

  if (requestMixStart >= 0) {
    for (const line of lines.slice(requestMixStart + 1)) {
      const match = line.match(/^\s*([\d.]+)%\s+(.+)$/);

      if (!match) {
        if (line.trim() !== '') {
          break;
        }
        continue;
      }

      metrics.requestMix.push({
        weight: match[1],
        route: match[2].trim(),
      });
    }
  }

  metrics.p99Latency = metrics.latencyDistribution['99'];

  return metrics;
}

function validateMetrics(metrics) {
  const requiredFields = [
    'target',
    'threads',
    'connections',
    'duration',
    'timeout',
    'totalRequests',
    'requestsPerSecond',
    'transferPerSecond',
    'dataRead',
    'averageLatency',
    'maxLatency',
    'p99Latency',
  ];

  const missingFields = requiredFields.filter((field) => !metrics[field]);

  if (missingFields.length > 0) {
    throw new Error(
      `Unable to parse required wrk metrics: ${missingFields.join(', ')}.`,
    );
  }
}

function renderReport({ cleanup, metrics, validationResults, wrkOutput }) {
  const generatedAt = new Date().toISOString();
  const requestMixRows = metrics.requestMix.map((entry) => {
    return `| ${entry.weight}% | \`${entry.route}\` | ${routePurpose(entry.route)} |`;
  });
  const validationRows = validationResults.map((result) => {
    const status = result.skipped
      ? 'Skipped'
      : result.exitCode === 0
        ? 'Passed'
        : 'Failed';
    return `| \`${formatCommand(result.command)}\` | ${status} |`;
  });

  return `# Performance Test Results

This file is generated from the latest \`wrk\` benchmark output by
[\`scripts/performance/generate_report.js\`](scripts/performance/generate_report.js).
Do not edit the benchmark numbers by hand; regenerate this file with
\`npm run performance:report\`.

## Summary

| Metric | Result |
| --- | ---: |
| Generated at | \`${generatedAt}\` |
| Benchmark tool | \`wrk\` with Lua request mix |
| Target | \`${metrics.target}\` |
| Threads | \`${metrics.threads}\` |
| Connections | \`${metrics.connections}\` |
| Duration | \`${metrics.duration}\` |
| Timeout | \`${metrics.timeout}\` |
| Total requests | \`${formatInteger(metrics.totalRequests)}\` |
| Requests per second | \`${metrics.requestsPerSecond}\` |
| Transfer per second | \`${formatByteValue(metrics.transferPerSecond)}\` |
| Data read | \`${formatByteValue(metrics.dataRead)}\` |
| Average latency | \`${metrics.averageLatency}\` |
| Max latency | \`${metrics.maxLatency}\` |
| 99th percentile latency | \`${metrics.p99Latency}\` |
| Socket errors | \`${metrics.socketErrors || 'none reported'}\` |
| Non-2xx/3xx responses | \`${metrics.nonSuccessResponses || 'none reported'}\` |

> Note: benchmark results vary by host machine, Docker resource limits, warm-up
> state, and selected load settings. Compare results only when the command,
> machine context, request mix, and database state are comparable.

## Test environment

- Date: ${generatedAt}
- Host operating system: ${os.type()} ${os.release()} (${os.platform()}, ${os.arch()})
- Node.js: ${process.version}
- Test runner: Docker Compose performance stack
- Application image: built from the project \`Dockerfile\`
- Database: isolated PostgreSQL 18 service with a dedicated performance volume
- Benchmark image: local Alpine-based \`wrk\` image built from source
- Readiness check: benchmark waits for \`/\` and
  \`/blog/building-a-calmer-personal-blog\` before starting

## Report generation command

\`\`\`shell
${formatEnvironmentCommand('npm run performance:report')}
\`\`\`

## Benchmark command executed

\`\`\`shell
${formatEnvironmentCommand(formatCommand(composeUpCommand))}
\`\`\`

Cleanup after the benchmark:

\`\`\`shell
${formatCommand(cleanup.command)}
\`\`\`

Cleanup status: **${cleanup.exitCode === 0 ? 'passed' : 'failed'}**.

## Request mix

The benchmark used the weighted route mix printed by
[\`scripts/performance/request_mix.lua\`](scripts/performance/request_mix.lua).

| Weight | Route | Purpose |
| ---: | --- | --- |
${requestMixRows.join('\n')}

## Raw benchmark output

\`\`\`text
${wrkOutput.trim()}
\`\`\`

## Validation checks

| Command | Status |
| --- | --- |
${validationRows.join('\n')}

## How to run a longer benchmark

Use the default benchmark documented in [\`README.md\`](README.md):

\`\`\`shell
npm run performance:report
\`\`\`

Or increase the load:

\`\`\`shell
WRK_THREADS=8 \\
WRK_CONNECTIONS=128 \\
WRK_DURATION=60s \\
WRK_TIMEOUT=10s \\
npm run performance:report
\`\`\`

For a fast smoke report, run:

\`\`\`shell
npm run performance:report:smoke
\`\`\`
`;
}

function routePurpose(route) {
  const purposes = {
    '/': 'Homepage with published posts from the database',
    '/blog/building-a-calmer-personal-blog': 'Seeded blog detail page',
    '/blog/a-tiny-publishing-checklist': 'Seeded blog detail page',
    '/output.css': 'Generated stylesheet',
    '/public/app.js': 'Public JavaScript asset',
  };

  return purposes[route] || 'Configured benchmark route';
}

function formatEnvironmentCommand(command) {
  const entries = Object.entries(benchmarkEnvironment).filter(([key, value]) => {
    return key !== 'WRK_PATHS' ? value !== '' : value.length > 0;
  });
  const environmentPrefix = entries
    .map(([key, value]) => `${key}=${shellEscape(value)}`)
    .join(' \\\n');

  if (environmentPrefix.length === 0) {
    return command;
  }

  return `${environmentPrefix} \\\n${command}`;
}

function formatCommand(command) {
  return command.map(shellEscape).join(' ');
}

function shellEscape(value) {
  const text = String(value);

  if (/^[A-Za-z0-9_@%+=:,./-]+$/.test(text)) {
    return text;
  }

  return `'${text.replace(/'/g, `'\\''`)}'`;
}

function formatInteger(value) {
  return Number.parseInt(value, 10).toLocaleString('en-US');
}

function formatByteValue(value) {
  return value.replace(/^([\d.]+)([KMGT]?B)$/i, '$1 $2');
}

function pickDefined(source, keys) {
  return keys.reduce((selected, key) => {
    if (source[key] !== undefined) {
      selected[key] = source[key];
    }
    return selected;
  }, {});
}

function assertFileExists(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Required file does not exist: ${filePath}`);
  }
}

function stripAnsi(value) {
  return value.replace(
    /[\u001B\u009B][[\]()#;?]*(?:(?:(?:[a-zA-Z\d]*(?:;[a-zA-Z\d]*)*)?\u0007)|(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PR-TZcf-nq-uy=><~]))/g,
    '',
  );
}

function removeControlCharacters(value) {
  return value.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '');
}

function trimBlankLines(lines) {
  let start = 0;
  let end = lines.length;

  while (start < end && lines[start].trim() === '') {
    start += 1;
  }

  while (end > start && lines[end - 1].trim() === '') {
    end -= 1;
  }

  return lines.slice(start, end);
}
