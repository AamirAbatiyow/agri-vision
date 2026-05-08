# AgriVision

**AI in your pocket for every farmer’s field.**

[![Hackathon](https://img.shields.io/badge/LionHog%20Tech%20Hackathon-2nd%20Place-gold?style=for-the-badge)](.)
[![Mobile](https://img.shields.io/badge/Mobile-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/API-Flask-000000?style=for-the-badge&logo=flask)](https://flask.palletsprojects.com)
[![CV](https://img.shields.io/badge/Vision-AWS%20Rekognition-FF9900?style=for-the-badge&logo=amazonaws)](https://aws.amazon.com/rekognition/)
[![Database](https://img.shields.io/badge/Data-MongoDB%20Atlas-47A248?style=for-the-badge&logo=mongodb)](https://www.mongodb.com/atlas)

*Snap a crop photo, identify diseases and pests with AI, and get real-time treatment recommendations.*

Built at the **LionHog Tech Hackathon**, where AgriVision won **2nd Place**.

---

## 🌱 What It Does

AgriVision is an AI-powered farming assistant that helps users identify:

- Crop diseases
- Plant stress
- Pest damage
- Nutrient deficiencies

Farmers can upload or capture a photo directly in the mobile app, and AgriVision analyzes the image using computer vision models hosted on AWS. The app then generates treatment recommendations and prevention guidance using AI.

The goal is to make crop diagnostics faster, more accessible, and easier for farmers without immediate access to agronomists or extension services.

---

## ✨ Features

- 📸 Camera-first crop scanning
- 🌱 AI-powered disease & pest detection
- 📊 Confidence scoring for predictions
- 🤖 Treatment recommendations using Claude 3.5 Sonnet
- ☁️ Weather-aware dashboard context
- 💬 Community chat & farmer discussions
- 🏆 XP, badges, and leaderboard system
- 📱 Cross-platform Flutter app
- 🗄 MongoDB-backed user system

---

## 🛠 Tech Stack

### Frontend
- Flutter
- Material 3 UI
- image_picker
- geolocator
- REST APIs

### Backend
- Flask
- MongoDB Atlas
- PyMongo
- boto3

### AI & Computer Vision
- AWS Rekognition Custom Labels
- Amazon Bedrock
- Claude 3.5 Sonnet

### External APIs
- USDA FoodData Central
- Open-Meteo API

---

## 🏗 Architecture

```text
Flutter Mobile App
        │
        ▼
     Flask API
        │
 ┌──────┼──────┐
 ▼      ▼      ▼
AWS   Bedrock MongoDB
Rekognition Claude  Atlas
```

---

## 🤖 AI Pipeline

1. User uploads a crop image from the Flutter app.
2. Flask API sends the image to AWS Rekognition Custom Labels.
3. The model returns disease/pest predictions with confidence scores.
4. Claude 3.5 Sonnet generates treatment recommendations and explanations.
5. Results are returned to the app and displayed in a farmer-friendly format.

---

## 📁 Repository Structure

```text
agri-vision/
├── backend/
│   ├── app.py
│   ├── agent.py
│   ├── config.py
│   └── requirements.txt
│
└── agri_vision/
    ├── lib/
    ├── pubspec.yaml
    └── assets/
```

---

## 🚀 Quickstart

### Backend

```bash
cd backend

python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

python app.py
```

### Frontend

```bash
cd agri_vision

flutter pub get
flutter run
```

---

## 🔐 Environment Variables

Create a `.env` file inside `/backend`:

```env
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_REGION=your_region

CUSTOM_LABEL_MODEL_ARN=your_model_arn

MONGO_URI=your_mongodb_uri

USDA_API_KEY=your_usda_key
```

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/analyze` | Analyze uploaded crop image |
| GET | `/ai_results` | Generate AI treatment recommendations |
| GET | `/health` | Health check |
| POST | `/users` | Create account |
| POST | `/login` | User login |
| GET | `/leaderboard` | XP leaderboard |

---

## 🔮 Future Improvements

- Offline-first support
- Multi-language support
- GPS-tagged field tracking
- Push notifications for outbreak risks
- On-device ML models for low-connectivity regions
- Historical crop analytics

---

## 🏆 Acknowledgements

- LionHog Tech Hackathon
- AWS Rekognition & Bedrock
- Anthropic Claude
- MongoDB Atlas
- Flutter & Flask open-source communities

---

## 📄 License

MIT License