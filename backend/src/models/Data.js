const mongoose = require("mongoose");

const dataSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      required: true,
      trim: true,
      maxlength: 128
    },
    value: {
      type: String,
      required: true,
      trim: true,
      maxlength: 2048
    }
  },
  { timestamps: true }
);

module.exports = mongoose.model("Data", dataSchema);
