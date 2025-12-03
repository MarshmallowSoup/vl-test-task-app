const express = require('express');
const { MongoClient } = require('mongodb');

const app = express();
const PORT = process.env.PORT || 3000;
const MONGO_URL = process.env.MONGO_URL || 'mongodb://localhost:27017';
const DB_NAME = process.env.DB_NAME || 'demoapp';

let db = null;
let mongoClient = null;

app.use(express.json());

async function connectToMongo() {
  try {
    mongoClient = new MongoClient(MONGO_URL);
    await mongoClient.connect();
    db = mongoClient.db(DB_NAME);
    console.log("Connected to MongoDB at ", MONGO_URL);
  } catch (error) {
    console.error("MongoDB connection error: ", error);
    setTimeout(connectToMongo, 5000);
  }
}

app.get('/health', (req, res) => {
  const status = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    mongodb: db ? 'connected' : 'disconnected'
  };
  res.json(status);
});

app.post('/echo', (req, res) => {
  res.json({
    message: 'Echo response',
    received: req.body,
    timestamp: new Date().toISOString()
  });
});

app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to K8s API Demo',
    version: '1.0.0',
    endpoints: {
      health: 'GET /health',
      echo: 'POST /echo',
      messages: 'GET /messages',
      createMessage: 'POST /messages'
    }
  });
});

// Get messages from MongoDB
app.get('/messages', async (req, res) => {
  try {
    if (!db) {
      return res.status(503).json({ error: 'Database not connected' });
    }
    
    const collection = db.collection('messages');
    const messages = await collection.find({}).sort({ timestamp: -1 }).limit(10).toArray();
    
    res.json({
      count: messages.length,
      messages: messages
    });
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

app.post('/messages', async (req, res) => {
  try {
    if (!db) {
      return res.status(503).json({ error: 'Database not connected' });
    }
    
    const { text, author } = req.body;
    
    if (!text) {
      return res.status(400).json({ error: 'Message text is required' });
    }
    
    const collection = db.collection('messages');
    const message = {
      text,
      author: author || 'Anonymous',
      timestamp: new Date().toISOString()
    };
    
    const result = await collection.insertOne(message);
    
    res.status(201).json({
      message: 'Message created',
      id: result.insertedId,
      data: message
    });
  } catch (error) {
    console.error('Error creating message:', error);
    res.status(500).json({ error: 'Failed to create message' });
  }
});

process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  if (mongoClient) {
    await mongoClient.close();
  }
  process.exit(0);
});



app.listen(PORT, async () => {
  console.log("API server running on port: ", PORT);
  await connectToMongo();
});
