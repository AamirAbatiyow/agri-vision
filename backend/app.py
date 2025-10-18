from flask import Flask, request, jsonify
from flask_cors import CORS
import traceback
import os
import json
from datetime import datetime, timezone

# AWS
import boto3
from config import Config

# MongoDB
import pymongo
from werkzeug.security import generate_password_hash, check_password_hash

# AI agent
from agent import main as run_agent_script
from agent_usda import run_usda_query

app = Flask(__name__)
CORS(app)

# ---------------------------
# AWS Rekognition
# ---------------------------
rekognition_client = Config.get_rekognition_client()

@app.route('/analyze', methods=['POST'])
def analyze_image():
    """Analyze image with AWS Rekognition Custom Labels"""
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file provided'}), 400
        
        image_file = request.files['image']
        if image_file.filename == '':
            return jsonify({'error': 'Empty filename'}), 400

        image_bytes = image_file.read()

        response = rekognition_client.detect_custom_labels(
            ProjectVersionArn=Config.CUSTOM_LABEL_MODEL_ARN,
            Image={'Bytes': image_bytes},
            MaxResults=Config.MAX_CUSTOM_LABELS,
            MinConfidence=Config.CUSTOM_MIN_CONFIDENCE
        )

        detected_labels = [
            {'name': label['Name'], 'confidence': round(label['Confidence'], 2)}
            for label in response.get('CustomLabels', [])
        ]

        if not detected_labels:
            detected_labels = [{'name': 'None found', 'confidence': 0.0}]

        result_data = {
            'timestamp': datetime.now().isoformat(),
            'filename': image_file.filename,
            'labels': detected_labels
        }

        results_path = os.path.join(os.path.dirname(__file__), 'results.json')
        with open(results_path, 'w') as f:
            json.dump(result_data, f, indent=2)

        return jsonify({'success': True, 'custom_labels': detected_labels}), 200

    except Exception as e:
        print(f"Error processing image: {str(e)}")
        print(traceback.format_exc())
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/results', methods=['GET'])
def get_results():
    """Return latest Rekognition result"""
    try:
        results_path = os.path.join(os.path.dirname(__file__), 'results.json')
        if not os.path.exists(results_path):
            return jsonify({'error': 'No results found. Please analyze an image first.'}), 404
        with open(results_path, 'r') as f:
            data = json.load(f)
        return jsonify(data), 200
    except Exception as e:
        print(f"Error reading results: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/ai_results', methods=['GET'])
def get_ai_results():
    """Run AI agent and return results"""
    try:
        run_agent_script()
        results_path = os.path.join(os.path.dirname(__file__), 'solutions.json')
        if not os.path.exists(results_path):
            return jsonify({'error': 'solutions.json not found after running agent'}), 500
        with open(results_path, 'r') as f:
            data = json.load(f)
        return jsonify(data), 200
    except Exception as e:
        print(f"Error running AI agent: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

# ---------------------------
# MongoDB Setup
# ---------------------------
MONGO_URI = getattr(Config, "MONGO_URI", None)
DB_NAME = getattr(Config, "DB_NAME", None)
client = pymongo.MongoClient(MONGO_URI, tlsAllowInvalidCertificates=True)
db = client[DB_NAME]

# Indexes
db.users.create_index("username", unique=True)
db.messages.create_index([("room", 1), ("ts", 1)])
db.messages.create_index([("participants", 1), ("ts", 1)])


def now_utc_iso():
    return datetime.now(timezone.utc).isoformat()


# ---------------------------
# User & Auth Endpoints
# ---------------------------
@app.route("/users", methods=["POST"])
def create_user():
    data = request.json or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    if not username or not password:
        return jsonify({"error": "Username and password required"}), 400
    if db.users.find_one({"username": username}):
        return jsonify({"error": "Username already exists"}), 400
    user = {
        "username": username,
        "password": generate_password_hash(password),
        "xp": 0,
        "level": 1,
        "badges": [],
        "joined": data.get("joined", "Unknown")
    }
    db.users.insert_one(user)
    return jsonify({"message": "User created", "user": {"username": username}}), 201


@app.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    if not username or not password:
        return jsonify({"success": False, "error": "Username and password required"}), 400
    user = db.users.find_one({"username": username})
    if not user or not check_password_hash(user["password"], password):
        return jsonify({"success": False, "error": "Invalid username or password"}), 401
    return jsonify({"success": True, "username": username})


@app.route("/users/<username>", methods=["GET"])
def get_user(username):
    user = db.users.find_one({"username": username}, {"_id": 0, "password": 0})
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user)


@app.route("/leaderboard", methods=["GET"])
def leaderboard():
    users = list(db.users.find({}, {"_id": 0, "username": 1, "xp": 1}))
    leaderboard = sorted(users, key=lambda x: x.get("xp", 0), reverse=True)
    return jsonify(leaderboard)


@app.route("/users/<username>/xp", methods=["PATCH"])
def update_xp(username):
    data = request.json or {}
    xp_gain = int(data.get("xp", 0))
    result = db.users.update_one({"username": username}, {"$inc": {"xp": xp_gain}})
    if result.matched_count == 0:
        return jsonify({"error": "User not found"}), 404
    return jsonify({"message": f"Added {xp_gain} XP to {username}"})


# ---------------------------
# Achievements
# ---------------------------
@app.route("/users/<username>/achievements", methods=["POST"])
def add_achievement(username):
    data = request.json or {}
    badge = (data.get("badge") or "").strip()
    if not badge:
        return jsonify({"error": "badge required"}), 400
    result = db.users.update_one({"username": username}, {"$addToSet": {"badges": badge}})
    if result.matched_count == 0:
        return jsonify({"error": "User not found"}), 404
    return jsonify({"message": "added", "badge": badge})


@app.route("/users/<username>/achievements", methods=["GET"])
def get_achievements(username):
    user = db.users.find_one({"username": username}, {"_id": 0, "badges": 1})
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user.get("badges", []))


# ---------------------------
# Chat
# ---------------------------
@app.route("/messages", methods=["POST"])
def post_message():
    data = request.json or {}
    sender = (data.get("sender") or "").strip()
    text = (data.get("text") or "").strip()
    room = (data.get("room") or "general").strip()
    if not sender or not text:
        return jsonify({"error": "sender and text required"}), 400

    doc = {"sender": sender, "text": text, "ts": now_utc_iso()}

    if room == "general":
        doc["room"] = "general"
    elif room == "dm":
        a = (data.get("a") or "").strip()
        b = (data.get("b") or "").strip()
        if not a or not b or sender not in [a, b]:
            return jsonify({"error": "invalid DM participants"}), 400
        doc["room"] = "dm"
        doc["participants"] = sorted([a, b])
    else:
        return jsonify({"error": "unknown room"}), 400

    db.messages.insert_one(doc)
    return jsonify({"message": "ok", "ts": doc["ts"]}), 201


@app.route("/messages/general", methods=["GET"])
def get_general():
    limit = int(request.args.get("limit", 200))
    after = request.args.get("after")
    q = {"room": "general"}
    if after:
        q["ts"] = {"$gt": after}
    rows = list(db.messages.find(q, {"_id": 0}).sort("ts", pymongo.ASCENDING).limit(limit))
    return jsonify(rows)


@app.route("/messages/dm", methods=["GET"])
def get_dm():
    a = (request.args.get("a") or "").strip()
    b = (request.args.get("b") or "").strip()
    limit = int(request.args.get("limit", 200))
    after = request.args.get("after")
    if not a or not b:
        return jsonify({"error": "a and b required"}), 400
    participants = sorted([a, b])
    q = {"room": "dm", "participants": participants}
    if after:
        q["ts"] = {"$gt": after}
    rows = list(db.messages.find(q, {"_id": 0}).sort("ts", pymongo.ASCENDING).limit(limit))
    return jsonify(rows)


@app.route("/messages/threads/<username>", methods=["GET"])
def threads(username):
    pipes = [
        {"$match": {"room": "dm", "participants": username}},
        {"$project": {
            "peer": {
                "$cond": [
                    {"$eq": [{"$arrayElemAt": ["$participants", 0]}, username]},
                    {"$arrayElemAt": ["$participants", 1]},
                    {"$arrayElemAt": ["$participants", 0]}
                ]
            },
            "ts": "$ts"
        }},
        {"$group": {"_id": "$peer", "lastTs": {"$max": "$ts"}}},
        {"$sort": {"lastTs": -1}}
    ]
    result = list(db.messages.aggregate(pipes))
    threads = [{"peer": r["_id"], "lastTs": r["lastTs"]} for r in result]
    return jsonify(threads)

@app.route("/ai_usda", methods=["GET"])
def ai_usda():
    query = request.args.get("query", "")
    if not query:
        return jsonify({"error": "Missing query"}), 400

    try:
        response = run_usda_query(query)
        return jsonify({"response": response}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ---------------------------
# Run server
# ---------------------------
if __name__ == "__main__":
    print("Starting Flask server on port 8000...")
    app.run(host="0.0.0.0", port=8000, debug=True)
