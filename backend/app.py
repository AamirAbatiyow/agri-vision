from flask import Flask, request, jsonify
from flask_cors import CORS
import pymongo
from werkzeug.security import generate_password_hash, check_password_hash
from config import MONGO_URI, DB_NAME  # Make sure this exists with your Mongo URI

app = Flask(__name__)
CORS(app)

# ---------------------------
# MongoDB Connection
# ---------------------------
client = pymongo.MongoClient(MONGO_URI, tlsAllowInvalidCertificates=True)
db = client[DB_NAME]

# ---------------------------
# Users API - Create User (Signup)
# ---------------------------
@app.route("/users", methods=["POST"])
def create_user():
    data = request.json
    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return jsonify({"error": "Username and password required"}), 400

    # Check if user already exists
    if db.users.find_one({"username": username}):
        return jsonify({"error": "Username already exists"}), 400

    user = {
        "username": username,
        "password": generate_password_hash(password),  # hash the password
        "xp": 0,
        "level": 1,
        "badges": [],
        "joined": data.get("joined", "Unknown")
    }

    db.users.insert_one(user)

    # Return user info without password
    return jsonify({"message": "User created", "user": {"username": username}}), 201

# ---------------------------
# Login API
# ---------------------------
@app.route("/login", methods=["POST"])
def login():
    data = request.json
    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return jsonify({"success": False, "error": "Username and password required"}), 400

    user = db.users.find_one({"username": username})
    if not user or not check_password_hash(user["password"], password):
        return jsonify({"success": False, "error": "Invalid username or password"}), 401

    return jsonify({"success": True, "username": username})

# ---------------------------
# Get User Info (without password)
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
    leaderboard = sorted(users, key=lambda x: x["xp"], reverse=True)
    return jsonify(leaderboard)

# ---------------------------
# Update XP
# ---------------------------
@app.route("/users/<username>/xp", methods=["PATCH"])
def update_xp(username):
    data = request.json
    xp_gain = data.get("xp", 0)

    result = db.users.update_one({"username": username}, {"$inc": {"xp": xp_gain}})
    if result.matched_count == 0:
        return jsonify({"error": "User not found"}), 404

    return jsonify({"message": f"Added {xp_gain} XP to {username}"})


if __name__ == "__main__":
    app.run(debug=True)
