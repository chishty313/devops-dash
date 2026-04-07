const morgan = require("morgan");
const { createLogger, format, transports } = require("winston");

const logger = createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: format.combine(format.timestamp(), format.errors({ stack: true }), format.json()),
  defaultMeta: { service: "qtec-backend" },
  transports: [new transports.Console()]
});

const requestLogger = morgan("combined", {
  stream: {
    write: (message) => {
      logger.info(message.trim(), { type: "http_access" });
    }
  }
});

module.exports = {
  logger,
  requestLogger
};
