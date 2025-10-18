# app.py
from flask import Flask, request, jsonify
from flask_cors import CORS
import pymongo
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timezone
from config import MONGO_URI, DB_NAME  # holds MONGO_URI, DB_NAME

app = Flask(__name__)
CORS(app)

# ---------------------------
# MongoDB Connection
# ---------------------------
client = pymongo.MongoClient(MONGO_URI, tlsAllowInvalidCertificates=True)
db = client[DB_NAME]

# indexes (safe to run each boot)
db.users.create_index("username", unique=True)
db.messages.create_index([("room", 1), ("ts", 1)])
db.messages.create_index([("participants", 1), ("ts", 1)])

def now_utc_iso():
    return datetime.now(timezone.utc).isoformat()

# ---------------------------
# Health
# ---------------------------
@app.route("/ping")
def ping():
    return {"ok": True, "time": now_utc_iso()}


# ---------------------------
# Users API - Create User (Signup)
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

# ---------------------------
# Login API
# ---------------------------
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

# ---------------------------
# Get User Info (no password)
# ---------------------------
@app.route("/users/<username>", methods=["GET"])
def get_user(username):
    user = db.users.find_one({"username": username}, {"_id": 0, "password": 0})
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user)

# ---------------------------
# Leaderboard API
# ---------------------------
@app.route("/leaderboard", methods=["GET"])
def leaderboard():
    users = list(db.users.find({}, {"_id": 0, "username": 1, "xp": 1}))
    leaderboard = sorted(users, key=lambda x: x.get("xp", 0), reverse=True)
    return jsonify(leaderboard)

# ---------------------------
# Update XP
# ---------------------------
@app.route("/users/<username>/xp", methods=["PATCH"])
def update_xp(username):
    data = request.json or {}
    xp_gain = int(data.get("xp", 0))
    result = db.users.update_one({"username": username}, {"$inc": {"xp": xp_gain}})
    if result.matched_count == 0:
        return jsonify({"error": "User not found"}), 404
    return jsonify({"message": f"Added {xp_gain} XP to {username}"})

# ======================================================
# ===============   CHAT PERSISTENCE   =================
# ======================================================
# Schema:
#  - General message:
#       { room: "general", sender: "alice", text: "hi", ts: <ISO> }
#  - DM message:
#       { room: "dm", participants: ["alice","bob"], sender: "alice", text: "yo", ts: <ISO> }

# Post a message (general or DM)
@app.route("/messages", methods=["POST"])
def post_message():
    data = request.json or {}
    sender = (data.get("sender") or "").strip()
    text = (data.get("text") or "").strip()
    room = (data.get("room") or "general").strip()

    if not sender or not text:
        return jsonify({"error": "sender and text required"}), 400

    doc = {
        "sender": sender,
        "text": text,
        "ts": now_utc_iso()
    }

    if room == "general":
        doc["room"] = "general"
    elif room == "dm":
        a = (data.get("a") or "").strip()
        b = (data.get("b") or "").strip()
        if not a or not b or sender not in [a, b]:
            return jsonify({"error": "invalid DM participants"}), 400
        doc["room"] = "dm"
        # store sorted participants for easy querying
        doc["participants"] = sorted([a, b])
    else:
        return jsonify({"error": "unknown room"}), 400

    db.messages.insert_one(doc)
    return jsonify({"message": "ok", "ts": doc["ts"]}), 201

# Get general chat messages (latest first)
@app.route("/messages/general", methods=["GET"])
def get_general():
    limit = int(request.args.get("limit", 200))
    after = request.args.get("after")  # ISO ts; return > after
    q = {"room": "general"}
    if after:
        q["ts"] = {"$gt": after}
    rows = list(
        db.messages.find(q, {"_id": 0})
        .sort("ts", pymongo.ASCENDING)
        .limit(limit)
    )
    return jsonify(rows)

# Get a DM thread between two users (latest first)
@app.route("/messages/dm", methods=["GET"])
def get_dm():
    a = (request.args.get("a") or "").strip()
    b = (request.args.get("b") or "").strip()
    limit = int(request.args.get("limit", 200))
    after = request.args.get("after")  # ISO ts

    if not a or not b:
        return jsonify({"error": "a and b required"}), 400

    participants = sorted([a, b])
    q = {"room": "dm", "participants": participants}
    if after:
        q["ts"] = {"$gt": after}

    rows = list(
        db.messages.find(q, {"_id": 0})
        .sort("ts", pymongo.ASCENDING)
        .limit(limit)
    )
    return jsonify(rows)

# List DM threads for a user (peers by last activity)
@app.route("/messages/threads/<username>", methods=["GET"])
def threads(username):
    # Find distinct peers and last timestamps
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

# ======================================================
# ============   ACHIEVEMENTS PERSISTENCE   ============
# ======================================================

# Add a badge to a user (idempotent)
@app.route("/users/<username>/achievements", methods=["POST"])
def add_achievement(username):
    data = request.json or {}
    badge = (data.get("badge") or "").strip()
    if not badge:
        return jsonify({"error": "badge required"}), 400

    result = db.users.update_one(
        {"username": username},
        {"$addToSet": {"badges": badge}}
    )
    if result.matched_count == 0:
        return jsonify({"error": "User not found"}), 404
    return jsonify({"message": "added", "badge": badge})

# Get user achievements
@app.route("/users/<username>/achievements", methods=["GET"])
def get_achievements(username):
    user = db.users.find_one({"username": username}, {"_id": 0, "badges": 1})
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user.get("badges", []))

# ======================================================

if __name__ == "__main__":
    # IMPORTANT: bind 0.0.0.0 so Android emulator can reach it (via 10.0.2.2)
    app.run(host="0.0.0.0", port=5000, debug=True)
