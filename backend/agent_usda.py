# agent_usda.py
import os
import requests
import json
from strands import Agent

# --- Model Config ---
MODEL_NAME = "us.anthropic.claude-3-5-sonnet-20240620-v1:0"
agent = Agent(model=MODEL_NAME)

# --- USDA API Config ---
USDA_API_KEY = os.getenv("USDA_API_KEY", "")
USDA_SEARCH_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"

def fetch_usda_data(query: str):
    """Fetch agricultural info directly from USDA database."""
    if not USDA_API_KEY:
        return {"error": "USDA_API_KEY not configured."}

    try:
        response = requests.get(
            USDA_SEARCH_URL,
            params={"query": query, "api_key": USDA_API_KEY, "pageSize": 3},
            timeout=10
        )
        if response.status_code == 200:
            data = response.json()
            foods = data.get("foods", [])
            results = []
            for food in foods:
                results.append({
                    "description": food.get("description", "N/A"),
                    "dataType": food.get("dataType", "N/A"),
                    "fdcId": food.get("fdcId"),
                    "nutrients": food.get("foodNutrients", [])[:3],
                })
            return results
        else:
            return {"error": f"USDA API error {response.status_code}"}
    except Exception as e:
        return {"error": str(e)}

def run_usda_query(user_query: str):
    """Combine USDA data and AI explanation."""
    if not user_query:
        return "Please enter a valid question or crop name."

    usda_data = fetch_usda_data(user_query)
    if isinstance(usda_data, dict) and "error" in usda_data:
        return f"Error retrieving USDA data: {usda_data['error']}"

    # Prepare AI prompt
    ai_prompt = (
        f"You are an agricultural assistant using USDA data for accurate responses.\n"
        f"User query: '{user_query}'\n\n"
        f"Here are the top results from USDA:\n{json.dumps(usda_data, indent=2)}\n\n"
        f"Summarize and explain in a conversational tone, focusing on:\n"
        f"- Disease or crop context if relevant\n"
        f"- Nutritional or biological facts\n"
        f"- Best farming or management practices\n"
        f"Keep it concise and easy to understand."
    )

    response = agent(ai_prompt)
    content = getattr(response, "content", str(response))
    return content

if __name__ == "__main__":
    print(run_usda_query("potato blight"))
