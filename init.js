const { Client } = require('pg');
const fs = require('fs');

(async () => {
  try {
    const sqlFiles = fs.readdirSync('.').filter(f => f.endsWith('.sql')).sort();

    // Separate database-level DDL (must run outside a transaction on the admin
    // connection) from schema/table DDL (runs on the manufacturing connection).
    const dbLevelFiles = sqlFiles.filter(f => f.startsWith('00-'));
    const schemaFiles  = sqlFiles.filter(f => !f.startsWith('00-'));

    // ------------------------------------------------------------------ //
    // Phase 1 — admin connection (postgres db)                            //
    // DROP DATABASE / CREATE DATABASE cannot run inside a transaction     //
    // block (PG error 25001). The pg client does NOT wrap individual      //
    // client.query() calls in a transaction, so running them here is safe.//
    // ------------------------------------------------------------------ //
    const adminClient = new Client({
      host: process.env.PGHOST,
      port: process.env.PGPORT,
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      database: 'postgres',
    });

    await adminClient.connect();
    for (const file of dbLevelFiles) {
      console.log(`Running ${file} on admin connection...`);
      const sql = fs.readFileSync(file, 'utf8');
      await adminClient.query(sql);
      console.log(`${file} completed.`);
    }
    await adminClient.end();

    // ------------------------------------------------------------------ //
    // Phase 2 — manufacturing connection                                  //
    // Schema, table, role, and data scripts run against the target db.    //
    // ------------------------------------------------------------------ //
    const client = new Client({
      host: process.env.PGHOST,
      port: process.env.PGPORT,
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      database: 'manufacturing',
    });

    await client.connect();
    for (const file of schemaFiles) {
      console.log(`Running ${file}...`);
      const sql = fs.readFileSync(file, 'utf8');
      await client.query(sql);
      console.log(`${file} completed.`);
    }
    console.log('All scripts executed successfully!');
    await client.end();
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
