import { pool } from './src/config/db.js';

async function test() {
  try {
    console.log('=== DEBUGGING STAFF CHECKIN DATES ===\n');
    
    // Get column info
    const { rows: colInfo } = await pool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = 'club_staff_checkin_days' 
      AND column_name IN ('checkin_date', 'created_at', 'updated_at');
    `);
    
    console.log('Column Types:');
    colInfo.forEach(col => {
      console.log(`  ${col.column_name}: ${col.data_type}`);
    });
    
    // Get all days
    console.log('\nStored Checkin Days:');
    const { rows: days } = await pool.query(`
      SELECT 
        id, 
        event_key, 
        checkin_date,
        is_active,
        created_at,
        updated_at
      FROM club_staff_checkin_days 
      ORDER BY checkin_date DESC
      LIMIT 10;
    `);
    
    days.forEach(day => {
      console.log(`  ID: ${day.id}`);
      console.log(`    checkin_date: ${day.checkin_date} (type: ${typeof day.checkin_date})`);
      console.log(`    is_active: ${day.is_active}`);
      console.log(`    created_at: ${day.created_at}`);
      console.log('');
    });
    
    // Test the lookup
    console.log('Testing Lookup Queries:');
    const today = new Date().toISOString().slice(0, 10);
    console.log(`  Today's date (JS): ${today}`);
    
    const { rows: result1 } = await pool.query(
      `SELECT checkin_date FROM club_staff_checkin_days 
       WHERE checkin_date::date = $1::date AND is_active = true LIMIT 1;`,
      [today]
    );
    console.log(`  Query with '::date = $1::date': ${result1.length > 0 ? 'FOUND' : 'NOT FOUND'}`);
    
    if (days.length > 0) {
      const dayDate = days[0].checkin_date;
      if (typeof dayDate === 'string') {
        const dayDateOnly = dayDate.split('T')[0];
        const { rows: result2 } = await pool.query(
          `SELECT checkin_date FROM club_staff_checkin_days 
           WHERE checkin_date::date = $1::date AND is_active = true LIMIT 1;`,
          [dayDateOnly]
        );
        console.log(`  Query with first day's date '${dayDateOnly}': ${result2.length > 0 ? 'FOUND' : 'NOT FOUND'}`);
      }
    }
    
    process.exit(0);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

test();
