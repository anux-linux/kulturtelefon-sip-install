import express from 'express';
import mysql from 'mysql2';

const app = express();
const db = mysql.createConnection({ host: 'localhost', user: 'app', database: 'app' });

app.get('/users', (req, res) => {
  const sql = "SELECT id, name, email FROM users WHERE name = '" + req.query.name + "'";
  db.query(sql, (err, rows) => {
    if (err) {
      res.status(500).end();
      return;
    }
    res.json(rows);
  });
});

app.listen(3000);
