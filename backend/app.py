from flask import Flask, request, jsonify
from flask_cors import CORS
from config import Config
import traceback
import boto3
import os
import json
from datetime import datetime

from agent import main as run_agent_script

app = Flask(__name__)
CORS(app)

rekognition_client = Config.get_rekognition_client()

@app.route('/analyze', methods=['POST'])
def analyze_image():
    """
    Endpoint to analyze an image using AWS Rekognition Custom Labels.
    Accepts an image file and returns detected custom labels.
    Saves result to a local JSON file (results.json), overwriting each time.
    """
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file provided'}), 400
        
        image_file = request.files['image']

        if image_file.filename == '':
            return jsonify({'error': 'Empty filename'}), 400
        
        image_bytes = image_file.read()

        # Detect custom labels using AWS Rekognition
        response = rekognition_client.detect_custom_labels(
            ProjectVersionArn=Config.CUSTOM_LABEL_MODEL_ARN,
            Image={'Bytes': image_bytes},
            MaxResults=Config.MAX_CUSTOM_LABELS,
            MinConfidence=Config.CUSTOM_MIN_CONFIDENCE
        )

        detected_labels = [
            {
                'name': label['Name'],
                'confidence': round(label['Confidence'], 2)
            }
            for label in response.get('CustomLabels', [])
        ]

        # If no labels found
        if not detected_labels:
            detected_labels = [{'name': 'None found', 'confidence': 0.0}]

        # Prepare single record to overwrite file
        result_data = {
            'timestamp': datetime.now().isoformat(),
            'filename': image_file.filename,
            'labels': detected_labels
        }

        # Save (overwrite) JSON file
        results_path = os.path.join(os.path.dirname(__file__), 'results.json')
        with open(results_path, 'w') as f:
            json.dump(result_data, f, indent=2)

        return jsonify({
            'success': True,
            'custom_labels': detected_labels
        }), 200

    except Exception as e:
        print(f"Error processing image: {str(e)}")
        print(traceback.format_exc())
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/results', methods=['GET'])
def get_results():
    """
    Return the latest classification result stored in results.json.
    """
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
    """Run agents.py, wait for completion, and return the AI Strands results JSON."""
    try:
        # Run the agent synchronously
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


if __name__ == '__main__':
    print("Starting Flask server on port 8000...")
    app.run(host='0.0.0.0', port=8000, debug=True)
