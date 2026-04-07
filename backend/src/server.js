const http = require("http");
const mongoose = require("mongoose");
require("dotenv").config();
const app = require("./app");
const { logger } = require("./middleware/logger");

const PORT = Number(process.env.PORT || 3000);
const MONGODB_URI = process.env.MONGODB_URI || "mongodb://localhost:27017/qtec";

async function startServer() {
  try {
    await mongoose.connect(MONGODB_URI, {
      maxPoolSize: Number(process.env.MONGO_POOL_SIZE || 10)
    });
    logger.info("MongoDB connected");

    const server = http.createServer(app);
    server.listen(PORT, () => {
      logger.info(`Server listening on port ${PORT}`);
    });
  } catch (error) {
    logger.error("Failed to start server", { error: error.message });
    process.exit(1);
  }
}

startServer();
