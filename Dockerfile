FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install pg
COPY <<EOF init.js
const { Client } = require('pg');
const fs = require('fs');

(async () => {
  try {
    // Connect to default postgres database
    const adminClient = new Client({
      host: process.env.PGHOST,
      port: process.env.PGPORT,
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      database: 'postgres',
    });

    await adminClient.connect();
    await adminClient.query('CREATE DATABASE IF NOT EXISTS manufacturing');
    await adminClient.end();

    // Now connect to manufacturing database
    const client = new Client({
      host: process.env.PGHOST,
      port: process.env.PGPORT,
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      database: 'manufacturing',
    });

    await client.connect();
    const files = fs.readdirSync('.').filter(f => f.endsWith('.sql')).sort();
    for (const file of files) {
      console.log(`Running ${file}...`);
      const sql = fs.readFileSync(file, 'utf8');
      await client.query(sql);
    }
    console.log('All scripts executed successfully!');
    await client.end();
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
EOF
ENTRYPOINT ["node", "init.js"]
