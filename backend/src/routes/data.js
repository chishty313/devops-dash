const express = require("express");
const { body, validationResult } = require("express-validator");
const Data = require("../models/Data");

const router = express.Router();

router.post(
  "/",
  [
    body("key").isString().trim().notEmpty().withMessage("key is required"),
    body("value").isString().trim().notEmpty().withMessage("value is required")
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        message: "Validation failed",
        errors: errors.array()
      });
    }

    const doc = await Data.create({
      key: req.body.key,
      value: req.body.value
    });

    return res.status(201).json({
      id: doc._id,
      key: doc.key,
      value: doc.value,
      createdAt: doc.createdAt
    });
  }
);

module.exports = router;
