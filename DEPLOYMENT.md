# Firebase Cloud Functions Deployment Guide

## Prerequisites
1. Node.js 18+ installed
2. Firebase CLI installed: `npm install -g firebase-tools`
3. OpenAI API key

## Setup Steps

### 1. Initialize Firebase (if not already done)
```bash
firebase login
firebase init
# Select Functions, Firestore, and any other services you need
```

### 2. Install Dependencies
```bash
cd functions
npm install
```

### 3. Set Environment Variables
```bash
# Set your OpenAI API key
firebase functions:config:set openai.api_key="your_openai_api_key_here"


# For local development, create .env file in functions directory
cp .env.example .env
# Edit .env and add your OpenAI API key
```

### 4. Update Firebase Project ID
Edit `.firebaserc` and replace `"your-project-id"` with your actual Firebase project ID.

### 5. Deploy Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:getPhilosopherResponse
```

### 6. Update Flutter App
Update `lib/firebase_options.dart` with your actual Firebase configuration.

## Testing

### Test Cloud Function
```bash
# Test locally
firebase emulators:start --only functions

# Test deployed function
firebase functions:log --only getPhilosopherResponse
```

### Test from Flutter App
The `ChatService` includes a `testCloudFunction()` method you can call to verify connectivity.

## Security Rules

Update Firestore security rules in `firestore.rules` as needed for your authentication setup.

## Monitoring

Monitor function performance and errors in the Firebase Console:
- Functions > Logs
- Functions > Metrics

## Cost Optimization

1. Set OpenAI API usage limits
2. Monitor Firebase Functions usage
3. Implement rate limiting if needed
4. Consider caching responses for common questions

## Troubleshooting

### Common Issues:
1. **CORS errors**: Ensure CORS is properly configured in the function
2. **API key errors**: Verify OpenAI API key is set correctly
3. **Timeout errors**: Increase function timeout if needed
4. **Quota exceeded**: Monitor OpenAI API usage and billing