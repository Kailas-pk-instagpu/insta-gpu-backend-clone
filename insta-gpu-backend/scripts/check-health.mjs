// Calls /healthz on every service. Usage: pnpm check:health  (services must be running)
const services = [
  ["bff-service", 3000],
  ["auth-service", 3001],
  ["cafe-management-service", 3002],
  ["session-service", 3003],
  ["billing-service", 3004],
  ["integration-service", 3005]
];
const host = process.env.HEALTH_HOST ?? "127.0.0.1";
let failed = 0;
for (const [name, port] of services) {
  try {
    const res = await fetch(`http://${host}:${port}/healthz`, { signal: AbortSignal.timeout(3000) });
    const body = await res.json();
    const ok = res.ok && body.status === "ok";
    if (!ok) failed++;
    console.log(`${ok ? "OK  " : "FAIL"}  ${name.padEnd(26)} :${port}  ${JSON.stringify(body)}`);
  } catch (err) {
    failed++;
    console.log(`FAIL  ${name.padEnd(26)} :${port}  ${err.message}`);
  }
}
process.exitCode = failed ? 1 : 0;
