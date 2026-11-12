
const express = require('express');
const { MongoClient } = require('mongodb');
const cors = require('cors');
const dotenv = require('dotenv');
const jwt = require('jsonwebtoken');

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json({ limit: '8mb' }));

let db;
let lecturers;

// Connect to MongoDB
async function connectDB() {
  const client = new MongoClient(process.env.MONGODB_URI);

  await client.connect();

  db = client.db(process.env.DB_NAME);
  lecturers = db.collection('GiangVien');

  console.log('MongoDB connected successfully');
}

// Login
app.post('/api/login', (req, res) => {
  const { email, password } = req.body;

  if (
    email !== process.env.ADMIN_EMAIL ||
    password !== process.env.ADMIN_PASSWORD
  ) {
    return res.status(401).json({
      message: 'Invalid email or password'
    });
  }

  const token = jwt.sign(
    { role: 'admin' },
    process.env.JWT_SECRET,
    { expiresIn: '12h' }
  );

  res.json({
    message: 'Login successful',
    token
  });
});

// Authentication middleware
function verifyToken(req, res, next) {
  const header = req.headers.authorization;

  if (!header) {
    return res.status(401).json({
      message: 'Please login first'
    });
  }

  try {
    const token = header.split(' ')[1];

    jwt.verify(token, process.env.JWT_SECRET);

    next();
  } catch (error) {
    res.status(401).json({
      message: 'Invalid or expired token'
    });
  }
}

// 1. Display all lecturers
app.get('/api/lecturers', verifyToken, async (req, res) => {
  try {
    const result = await lecturers
      .find({}, { projection: { _id: 0 } })
      .sort({ IDGV: 1 })
      .toArray();

    res.json(result);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// 2. Add lecturer
app.post('/api/lecturers', verifyToken, async (req, res) => {
  try {
    const { IDGV, Fullname, Image, SumClass } = req.body;

    if (
      !IDGV?.trim() ||
      !Fullname?.trim() ||
      typeof Image !== 'string' ||
      !Number.isInteger(SumClass) ||
      SumClass < 0
    ) {
      return res.status(400).json({
        message: 'Invalid lecturer information'
      });
    }

    const existing = await lecturers.findOne({ IDGV });

    if (existing) {
      return res.status(409).json({
        message: 'Lecturer ID already exists'
      });
    }

    await lecturers.insertOne({
      IDGV: IDGV.trim(),
      Fullname: Fullname.trim(),
      Image,
      SumClass
    });

    res.json({ message: 'Lecturer added successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// 3. Edit lecturer
app.put('/api/lecturers/:idgv', verifyToken, async (req, res) => {
  try {
    const { Fullname, Image, SumClass } = req.body;

    if (
      !Fullname?.trim() ||
      typeof Image !== 'string' ||
      !Number.isInteger(SumClass) ||
      SumClass < 0
    ) {
      return res.status(400).json({
        message: 'Invalid lecturer information'
      });
    }

    const result = await lecturers.updateOne(
      { IDGV: req.params.idgv },
      {
        $set: {
          Fullname: Fullname.trim(),
          Image,
          SumClass
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({
        message: 'Lecturer not found'
      });
    }

    res.json({ message: 'Lecturer updated successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// 4. Delete lecturer
app.delete('/api/lecturers/:idgv', verifyToken, async (req, res) => {
  try {
    const result = await lecturers.deleteOne({
      IDGV: req.params.idgv
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({
        message: 'Lecturer not found'
      });
    }

    res.json({ message: 'Lecturer deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Start server
connectDB()
  .then(() => {
    app.listen(process.env.PORT || 3000, '0.0.0.0', () => {
      console.log('Server running on port 3000');
    });
  })
  .catch((error) => {
    console.error('MongoDB connection error:', error);
    process.exit(1);
  });
