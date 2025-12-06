# Firebase Cloud Functions for AI Edition

## Setup

1. **Install dependencies:**
   ```bash
   cd functions
   npm install
   ```

2. **Set API keys as secrets:**
   ```bash
   # Set Gemini API key (recommended - free tier)
   firebase functions:secrets:set GEMINI_API_KEY
   # Enter your API key when prompted
   
   # Set Anthropic API key (optional)
   firebase functions:secrets:set ANTHROPIC_API_KEY
   # Enter your API key when prompted
   ```

3. **Deploy:**
   ```bash
   firebase deploy --only functions
   ```

## Function: generateTrivia

**Endpoint:** `https://us-central1-wordn3rd-7bd5d.cloudfunctions.net/generateTrivia`

**Authentication:** Required (Firebase Auth token)

**Request:**
```json
{
  "topic": "dinosaurs",
  "isYouthEdition": false,
  "count": 50
}
```

**Response:**
```json
{
  "result": {
    "success": true,
    "trivia": [
      {
        "category": "types of dinosaurs",
        "words": ["T-Rex", "Triceratops", ...],
        "correctAnswers": ["T-Rex", "Triceratops", ...]
      }
    ],
    "provider": "gemini"
  }
}
```

## Cost Management

- Monitor usage in Firebase Console
- Set up billing alerts
- Gemini free tier: 60 requests/minute
- Anthropic: Pay-per-use

## Local Testing

```bash
firebase emulators:start --only functions
```

Function will be available at:
`http://localhost:6004/wordn3rd-7bd5d/us-central1/generateTrivia`

