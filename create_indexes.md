# Firebase Firestore Index Creation Guide

## Quick Links to Create Required Indexes

Based on the error messages, you need to create the following indexes in Firebase Console:

### Index 1: Basic Profile + Rating
**URL:** https://console.firebase.google.com/v1/r/project/auth-f3e4d/firestore/indexes?create_composite=Ckpwcm9qZWN0cy9hdXRoLWYzZTRkL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9sYXd5ZXJzL2luZGV4ZXMvXxABGhMKD3Byb2ZpbGVDb21wbGV0ZRABGgoKBnJhdGluZxACGgwKCF9fbmFtZV9fEAI

**Fields:**
- profileComplete (Ascending)
- rating (Descending)

### Index 2: Profile + Specialization + Keywords + Rating
**URL:** https://console.firebase.google.com/v1/r/project/auth-f3e4d/firestore/indexes?create_composite=Ckpwcm9qZWN0cy9hdXRoLWYzZTRkL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9sYXd5ZXJzL2luZGV4ZXMvXxABGhIKDnNlYXJjaEtleXdvcmRzGAEaEwoPcHJvZmlsZUNvbXBsZXRlEAEaEgoOc3BlY2lhbGl6YXRpb24QARoKCgZyYXRpbmcQAhoMCghfX25hbWVfXxAC

**Fields:**
- profileComplete (Ascending)
- specialization (Ascending)
- searchKeywords (Array-contains)
- rating (Descending)

## Steps to Create Indexes:

1. **Click on the URLs above** - They will take you directly to the Firebase Console with the index pre-configured
2. **Click "Create Index"** for each one
3. **Wait for indexes to build** - This can take a few minutes to several hours depending on your data size
4. **Test your app** - The fallback methods will work in the meantime

## Manual Creation (Alternative):

If the URLs don't work, you can manually create them:

1. Go to [Firebase Console](https://console.firebase.google.com/project/auth-f3e4d/firestore/indexes)
2. Click "Create Index"
3. Set Collection ID: `lawyers`
4. Add fields as specified above
5. Click "Create Index"

## Index Status:

You can check the status of your indexes in the Firebase Console. They will show as:
- 🟡 Building (yellow) - Index is being created
- 🟢 Enabled (green) - Index is ready to use
- 🔴 Error (red) - There was an issue creating the index

## Current App Behavior:

✅ Your app is working with fallback methods
✅ Data loads and searches work (just slower)
✅ Once indexes are ready, performance will improve automatically
