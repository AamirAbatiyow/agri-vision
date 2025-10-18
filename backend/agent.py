from strands import Agent
import json
import os
import re

# --- Model setup ---
MODEL_NAME = "us.anthropic.claude-3-5-sonnet-20240620-v1:0"
agent = Agent(model=MODEL_NAME)

# --- File paths ---
RESULTS_FILE = os.path.join(os.path.dirname(__file__), "results.json")
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "solutions.json")

def load_latest_result():
    """Load the most recent Rekognition result."""
    if not os.path.exists(RESULTS_FILE):
        raise FileNotFoundError(f"{RESULTS_FILE} not found. Run the Flask app first to create it.")
    
    with open(RESULTS_FILE, "r") as f:
        return json.load(f)

def generate_solution_prompt(label_name: str) -> str:
    """
    Generate the text prompt for the AI model.
    Make it explicit: output valid JSON only, no extra text.
    """
    return (
        f"You are an expert agricultural assistant.\n"
        f"The detected disease is '{label_name}'.\n\n"
        f"Provide a short explanation and top treatments for this disease.\n"
        f"Return valid JSON **only** with these keys exactly: "
        f"'disease', 'cause', 'symptoms', 'treatment'.\n"
        f"The 'treatment' field must be a list of the 3 most important treatments.\n"
        f"Do not include any extra text outside JSON.\n"
        f"Example format:\n"
        f"{{\n"
        f"  \"disease\": \"Potato Late Blight\",\n"
        f"  \"cause\": \"Fungal infection\",\n"
        f"  \"symptoms\": \"Leaf spots, blight\",\n"
        f"  \"treatment\": [\"Remove infected plants\", \"Fungicide spray\", \"Crop rotation\"]\n"
        f"}}"
    )

def extract_top_treatments(treatment_text: str) -> list:
    """Extract top 3 treatments from a raw string if model outputs a string."""
    lines = re.split(r'\n\d*\.?\s*', treatment_text)
    lines = [line.strip() for line in lines if line.strip()]
    return lines[:3]

def main():
    try:
        result_data = load_latest_result()
        labels = result_data.get("labels", [])

        if not labels or labels[0].get("name") == "None found":
            print("No disease detected.")
            solutions = {"disease": None, "cause": None, "symptoms": None, "treatment": []}
            with open(OUTPUT_FILE, "w") as f:
                json.dump(solutions, f, indent=4)
            return

        disease_name = labels[0]["name"]
        prompt = generate_solution_prompt(disease_name)

        response = agent(prompt)
        content = getattr(response, "content", str(response))

        # --- Safely parse JSON ---
        try:
            solutions = json.loads(content)

            # Ensure treatment is a list of strings
            if "treatment" in solutions:
                if isinstance(solutions["treatment"], str):
                    solutions["treatment"] = extract_top_treatments(solutions["treatment"])
                elif not isinstance(solutions["treatment"], list):
                    solutions["treatment"] = []

        except json.JSONDecodeError:
            # Fallback if AI returns invalid JSON
            solutions = {
                "disease": disease_name,
                "cause": None,
                "symptoms": None,
                "treatment": extract_top_treatments(content)
            }

        # --- Save solutions ---
        with open(OUTPUT_FILE, "w") as f:
            json.dump(solutions, f, indent=4)

        print(f"✅ Solutions saved to {OUTPUT_FILE}")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()