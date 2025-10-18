# AI Chat Feature Setup Guide

## Overview
The AI Chat feature provides an intelligent agricultural assistant powered by AWS Bedrock (Claude 3.5 Sonnet) and USDA FoodData Central API.

## Backend Setup

### 1. Install Python Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure AWS Credentials

**Option A: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

**Option B: AWS CLI**
```bash
aws configure
# Follow prompts to enter credentials
```

### 3. Get USDA API Key (Optional)
1. Visit: https://fdc.nal.usda.gov/api-key-signup.html
2. Sign up for a free API key
3. Set environment variable:
```bash
export USDA_API_KEY="your-usda-key"
```

Note: If no API key is provided, it will use `DEMO_KEY` with limited requests.

### 4. Configure AWS Bedrock Access

Ensure your AWS IAM user/role has permissions for:
- `bedrock:InvokeModel`
- Model: `us.anthropic.claude-3-5-sonnet-20240620-v1:0`

**IAM Policy Example:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0"
    }
  ]
}
```

### 5. Test the Backend

**Test the agent directly:**
```bash
cd backend
python agent_usda.py
```

**Start the Flask server:**
```bash
python app.py
```

**Test the endpoint:**
```bash
curl "http://localhost:8000/ai_usda?query=How%20do%20I%20grow%20tomatoes"
```

## Frontend (Flutter)

The AI Chat tab has been automatically added to your bottom navigation.

### Features:
✨ Modern chat UI with gradient backgrounds
✨ Animated message bubbles with fade-in effects
✨ Typing indicator animation
✨ Dark/light theme support
✨ Responsive to screen sizes

### Usage:
1. Open the app
2. Navigate to the **AI Chat** tab (brain icon)
3. Type questions about farming, crops, diseases
4. Get instant AI-powered responses!

## Example Queries

Try asking:
- "How do I grow tomatoes?"
- "What nutrients are in corn?"
- "My wheat has rust disease, what should I do?"
- "How often should I water lettuce?"
- "What's the best soil pH for potatoes?"
- "Tell me about tomato nutrition"

## Fallback Mode

If AWS Bedrock is unavailable (no boto3 or credentials), the agent automatically falls back to a knowledge-based response system with pre-programmed answers for common agricultural questions.

## Architecture

```
User → Flutter App (AI Chat Page)
         ↓
      Flask Backend (/ai_usda endpoint)
         ↓
    agent_usda.py
         ↓
   ┌────────────┬──────────────┐
   ↓            ↓              ↓
USDA API   AWS Bedrock    Fallback KB
              (Claude)
```

## Troubleshooting

### "Connection refused" error:
- Make sure Flask server is running on port 8000
- For Android emulator, server should listen on `0.0.0.0:8000`
- App uses `10.0.2.2:5000` to reach host from Android emulator

### "boto3 not found":
```bash
pip install boto3
```

### "Invalid credentials" from AWS:
- Check `~/.aws/credentials` file
- Verify IAM permissions for Bedrock
- Try: `aws bedrock list-foundation-models` to test access

### USDA API Rate Limits:
- DEMO_KEY: 30 requests/hour, 50/day
- Free API key: 1000 requests/hour
- Responses are cached when possible

## Performance Notes

- First request may take 2-5 seconds (AWS Bedrock cold start)
- Subsequent requests: < 1 second
- USDA API calls add ~200-500ms when nutritional data is needed
- Fallback mode: instant responses

## Security Notes

⚠️ **Production Considerations:**
- Store AWS credentials securely (AWS Secrets Manager, environment variables)
- Rate-limit the `/ai_usda` endpoint
- Sanitize user inputs
- Consider caching frequent queries
- Monitor AWS Bedrock costs (per-token pricing)

## Cost Estimates

**AWS Bedrock (Claude 3.5 Sonnet):**
- Input: $0.003 per 1K tokens
- Output: $0.015 per 1K tokens
- Average query: ~$0.01-0.03

**USDA API:**
- Free (with API key)

**Typical monthly cost for 1000 queries:** ~$10-30

## Next Steps

1. ✅ Backend API created
2. ✅ Frontend UI integrated
3. ✅ Navigation updated
4. 🔄 Configure AWS credentials
5. 🔄 Test end-to-end functionality

Enjoy your AI-powered farming assistant! 🌾🤖

