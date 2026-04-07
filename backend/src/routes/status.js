const express = require("express");

const router = express.Router();
const startedAt = Date.now();

router.get("/", (_req, res) => {
  res.status(200).json({
    status: "ok",
    version: process.env.APP_VERSION || "1.0.0",
    uptime: Math.floor((Date.now() - startedAt) / 1000),
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || "development",
    color: process.env.DEPLOY_COLOR || "blue"
  });
});

module.exports = router;
