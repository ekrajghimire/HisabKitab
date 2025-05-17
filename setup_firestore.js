const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Clear existing trips collection if it exists
async function clearTripsCollection() {
  const tripsRef = db.collection('trips');
  const snapshot = await tripsRef.get();
  
  console.log('Deleting existing trips...');
  
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  
  if (snapshot.size > 0) {
    await batch.commit();
    console.log(`Deleted ${snapshot.size} trip documents`);
  } else {
    console.log('No existing trip documents found');
  }
}

// Set up Trips collection structure
async function setupTripsCollection() {
  const tripsRef = db.collection('trips');
  
  // Create a sample trip document
  const sampleTrip = {
    name: 'Sample Trip',
    description: 'This is a sample trip to demonstrate the structure',
    groupId: 'sample-group-id', // You'll need to replace this with a real group ID
    createdBy: 'sample-user-id', // You'll need to replace this with a real user ID
    startDate: admin.firestore.Timestamp.fromDate(new Date()),
    endDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)), // 7 days from now
    currency: 'INR',
    members: ['sample-user-id'], // You'll need to replace this with real user IDs
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await tripsRef.add(sampleTrip);
  console.log('Created sample trip document');
}

async function main() {
  try {
    await clearTripsCollection();
    await setupTripsCollection();
    console.log('Trip collection setup completed successfully');
  } catch (error) {
    console.error('Error setting up trips collection:', error);
  } finally {
    process.exit();
  }
}

main(); 