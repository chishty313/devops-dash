const request = require("supertest");
const app = require("../src/app");
const Data = require("../src/models/Data");

jest.mock("../src/models/Data");

describe("API endpoints", () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test("GET /api/status returns service metadata", async () => {
    const res = await request(app).get("/api/status");

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("status", "ok");
    expect(res.body).toHaveProperty("version");
    expect(res.body).toHaveProperty("uptime");
    expect(res.body).toHaveProperty("timestamp");
  });

  test("POST /api/data creates and returns a record", async () => {
    const createdAt = new Date().toISOString();
    Data.create.mockResolvedValue({
      _id: "507f1f77bcf86cd799439011",
      key: "env",
      value: "prod",
      createdAt
    });

    const res = await request(app).post("/api/data").send({
      key: "env",
      value: "prod"
    });

    expect(res.statusCode).toBe(201);
    expect(res.body).toMatchObject({
      id: "507f1f77bcf86cd799439011",
      key: "env",
      value: "prod",
      createdAt
    });
  });

  test("POST /api/data rejects invalid payload", async () => {
    const res = await request(app).post("/api/data").send({
      key: "",
      value: ""
    });

    expect(res.statusCode).toBe(400);
    expect(res.body).toHaveProperty("message", "Validation failed");
    expect(Array.isArray(res.body.errors)).toBe(true);
  });
});
