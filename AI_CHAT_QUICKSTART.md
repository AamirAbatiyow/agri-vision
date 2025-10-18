# 🤖 AI Chat Feature - Quick Start Guide

## 🎉 What's New

Your AgriVision app now includes an **AI-powered agricultural assistant** that can answer questions about crops, diseases, soil health, and farming techniques!

## 🚀 Quick Start

### Flutter App (Already Done ✅)
The AI Chat tab has been added to your bottom navigation bar:
- **Icon:** 🧠 Brain icon
- **Position:** Between "Community" and "Profile" tabs
- **Features:** Modern gradient UI, animated chat bubbles, typing indicators

### Backend Setup

#### 1. Start the Flask Server
```bash
cd backend
python app.py
```

The server will start on `http://0.0.0.0:8000`

#### 2. (Optional) Configure AWS Bedrock for Enhanced AI

If you want to use AWS Bedrock Claude for more intelligent responses:

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="us-east-1"

# Optional: USDA API key for nutritional data
export USDA_API_KEY="your-usda-key"
```

#### 3. Test the Endpoint
```bash
curl "http://localhost:8000/ai_usda?query=How%20do%20I%20grow%20tomatoes"
```

Expected response:
```json
{
  "response": "🍅 Tomato Growing Tips:..."
}
```

## 📱 Using the AI Chat

1. **Open the app** and navigate to the **AI Chat** tab
2. **Type your question** in the input field
3. **Press send** (paper plane icon)
4. **Get instant AI responses** with actionable advice!

### Example Questions:
- "How do I treat tomato blight?"
- "What nutrients does corn need?"
- "My wheat has rust disease, what should I do?"
- "How often should I water lettuce?"
- "What's the best soil pH for potatoes?"
- "Tell me about tomato nutrition"

## 🎨 UI Features

### Modern Design Elements:
✨ **Gradient backgrounds** - Beautiful blurred gradients adapt to light/dark theme
✨ **Animated bubbles** - Smooth fade-in and slide animations
✨ **Typing indicator** - Animated dots show when AI is "thinking"
✨ **Smart avatars** - User and AI avatars with gradient styling
✨ **Theme-aware** - Perfect contrast in both light and dark modes
✨ **Google Fonts** - Clean typography with Inter and Poppins

### Color Coding:
- **User messages:** Primary color gradient (green tones)
- **AI messages:** Neutral surface colors
- **Header:** AI status indicator shows "Online" when ready

## 🔧 How It Works

```
┌─────────────────┐
│  User Question  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  Flutter AI Chat Page   │
│  /lib/pages/chat/       │
│  ai_chat_page.dart      │
└────────┬────────────────┘
         │ HTTP GET
         ▼
┌─────────────────────────┐
│   Flask Backend         │
│   /ai_usda endpoint     │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│   agent_usda.py         │
│   ├─ USDA API (food data)│
│   ├─ AWS Bedrock        │
│   │   (Claude 3.5)      │
│   └─ Fallback KB        │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  AI Response            │
│  (Natural language      │
│   farming advice)       │
└─────────────────────────┘
```

## 🌟 Smart Features

### Intelligent Routing:
- **Nutritional queries** → Fetches USDA data first
- **Disease questions** → Suggests using Camera feature
- **General farming** → Provides expert guidance

### Context-Aware:
- Mentions other AgriVision features when relevant
- Provides actionable steps and warnings
- Uses emoji for better visual scanning

## 💰 Cost Estimates (AWS Bedrock)

- **Per query:** ~$0.01-0.03
- **1000 queries/month:** ~$10-30
- **Fallback mode:** FREE (no AWS required)

## 🔐 Security Best Practices

✅ Environment variables for credentials  
✅ Input sanitization in agent_usda.py  
✅ Timeout protection on HTTP calls  
✅ Error handling with user-friendly messages  

## 🐛 Troubleshooting

### Backend not responding:
```bash
# Check if server is running
curl http://localhost:8000/health

# Restart the server
cd backend
python app.py
```

### AWS Bedrock errors:
```bash
# Test credentials
aws bedrock list-foundation-models --region us-east-1

# Check agent directly
python agent_usda.py
```

### Flutter connection issues:
- Android Emulator: Change backend URL in `ai_chat_page.dart` line 22
  - `http://10.0.2.2:8000` for emulator
  - `http://localhost:8000` for web/desktop
  - `http://YOUR_IP:8000` for physical device

## 📚 Dependencies Added

### Backend (requirements.txt):
- `boto3` - AWS SDK
- `requests` - HTTP calls to USDA API

### Flutter (pubspec.yaml):
- Already using existing packages (http, font_awesome_flutter)

## 🎯 Next Steps

1. **Configure AWS credentials** for enhanced AI responses
2. **Get USDA API key** for nutritional data
3. **Customize responses** in `agent_usda.py`
4. **Monitor costs** in AWS Console
5. **Add more knowledge** to fallback responses

---

**Enjoy your new AI farming assistant!** 🌾✨

For detailed setup, see `AI_CHAT_SETUP.md` in the backend folder.

