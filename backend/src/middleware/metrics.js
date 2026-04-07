const client = require("prom-client");

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
  registers: [register]
});

const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5],
  registers: [register]
});

function metricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();
  res.on("finish", () => {
    const route = req.route ? req.route.path : req.path;
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1_000_000_000;
    const labels = {
      method: req.method,
      route,
      status_code: String(res.statusCode)
    };
    httpRequestsTotal.inc(labels);
    httpRequestDuration.observe(labels, durationSeconds);
  });
  next();
}

async function metricsHandler(_req, res) {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
}

module.exports = {
  metricsMiddleware,
  metricsHandler
};
