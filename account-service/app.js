const express = require('express');
const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'account-service' });
});

app.get('/accounts', (req, res) => {
  res.json([
    { id: 1, owner: 'Alice', balance: 5000 },
    { id: 2, owner: 'Bob', balance: 3200 }
  ]);
});

app.post('/accounts', (req, res) => {
  const { owner, balance } = req.body;
  res.status(201).json({ id: Date.now(), owner, balance, created: true });
});

app.get('/accounts/:id', (req, res) => {
  res.json({ id: req.params.id, owner: 'Alice', balance: 5000 });
});

app.listen(PORT, () => {
  console.log(`Account Service running on port ${PORT}`);
});
