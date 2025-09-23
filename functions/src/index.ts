import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

exports.cleanupOldProfileImages = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const storage = admin.storage();
    const bucket = storage.bucket();

    try {
      // Get all files in lawyer_profiles directory
      const [files] = await bucket.getFiles({ prefix: 'lawyer_profiles/' });

      // Get current time minus 30 days
      const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);

      for (const file of files) {
        const metadata = await file.getMetadata();
        const createTime = new Date(metadata[0].timeCreated).getTime();

        if (createTime < thirtyDaysAgo) {
          const userId = metadata[0].metadata?.userId;
          if (userId) {
            const userDoc = await admin.firestore()
              .collection('lawyers')
              .doc(userId)
              .get();

            const currentProfilePath = userDoc.data()?.profileImagePath;
            
            if (currentProfilePath !== file.name) {
              await file.delete();
              console.log(`Deleted old profile image: ${file.name}`);
            }
          }
        }
      }
    } catch (error) {
      console.error('Error cleaning up old profile images:', error);
    }
  });