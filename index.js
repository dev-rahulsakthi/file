const express = require("express");
const multer = require("multer");
const cors = require("cors");

const app = express();
app.use(cors());

const upload = multer({ storage: multer.memoryStorage() });

const PORT = process.env.PORT || 3000;

// Temporary storage
const files = {}; // code => { file, expires }

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Upload
app.post("/upload", upload.single("file"), (req, res) => {
  const code = generateCode();

  files[code] = {
    file: req.file,
    expires: Date.now() + 10 * 60 * 1000, // 10 minutes
  };

  res.json({ code });
});

// Download
app.get("/download/:code", (req, res) => {
  const data = files[req.params.code];

  if (!data) return res.status(404).send("Invalid Code");

  if (Date.now() > data.expires) {
    delete files[req.params.code];
    return res.status(410).send("Expired");
  }

  res.setHeader(
    "Content-Disposition",
    `attachment; filename="${data.file.originalname}"`
  );

  res.send(data.file.buffer);
  delete files[req.params.code]; // delete after download
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});