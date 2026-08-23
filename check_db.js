const { MongoClient } = require('mongodb');

async function run() {
  const uri = "mongodb+srv://syedmozamilsherazi_db_user:bqogjxsop7AL7i3r@syedmozamilshah.hagzum9.mongodb.net/healthverse?appName=SyedMozamilShah";
  const client = new MongoClient(uri);

  try {
    await client.connect();
    const database = client.db('healthverse');
    const doctors = database.collection('doctor');

    const doctor = await doctors.findOne({ email: "syedmozamilsherazi@gmail.com" });
    if (doctor) {
      console.log("Doctor found:", doctor.first_name, doctor.last_name);
      console.log("Daily Availabilities:", JSON.stringify(doctor.daily_availabilities, null, 2));
    } else {
      console.log("Doctor not found.");
    }
  } finally {
    await client.close();
  }
}
run().catch(console.dir);
