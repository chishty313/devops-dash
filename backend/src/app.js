const express = require("express");
require("express-async-errors");
const helmet = require("helmet");
const cors = require("cors");
const { requestLogger } = require("./middleware/logger");
const { metricsMiddleware, metricsHandler } = require("./middleware/metrics");
const statusRoute = require("./routes/status");
const dataRoute = require("./routes/data");

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(requestLogger);
app.use(metricsMiddleware);

app.get("/api/metrics", metricsHandler);
app.use("/api/status", statusRoute);
app.use("/api/data", dataRoute);

app.get("/api/healthz", (_req, res) => res.status(200).json({ status: "healthy" }));

app.use((err, _req, res, _next) => {
  return res.status(500).json({
    message: "Internal server error",
    error: process.env.NODE_ENV === "production" ? undefined : err.message
  });
});

module.exports = app;
