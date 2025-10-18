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
    """Fetch USDA data (mostly nutritional)."""
    if not USDA_API_KEY:
        return {"error": "USDA_API_KEY not configured."}

    try:
        response = requests.get(
            USDA_SEARCH_URL,
            params={"query": query, "api_key": USDA_API_KEY, "pageSize": 3},
            timeout=10
        )
        response.raise_for_status()
        data = response.json()
        foods = data.get("foods", [])
        if not foods:
            return []
        results = [{
            "description": food.get("description", "N/A"),
            "dataType": food.get("dataType", "N/A"),
            "fdcId": food.get("fdcId"),
            "nutrients": food.get("foodNutrients", [])[:3],
        } for food in foods]
        return results
    except requests.exceptions.RequestException as e:
        return {"error": f"Request failed: {e}"}
    except Exception as e:
        return {"error": str(e)}


def run_usda_query(user_query: str):
    """
    Smart USDA + AI combo agent.
    Falls back to AI agricultural expertise if USDA data is missing or irrelevant.
    """
    if not user_query:
        return "Please enter a valid crop or farming question."

    usda_data = fetch_usda_data(user_query)

    # Detect USDA errors or missing results
    if isinstance(usda_data, dict) and "error" in usda_data:
        usda_info = "No USDA API data was available due to an error."
    elif not usda_data:
        usda_info = "No relevant USDA data found for this topic."
    else:
        usda_info = json.dumps(usda_data, indent=2)

    # Smarter AI prompt
    ai_prompt = (
        f"You are AgriStrand — an advanced agricultural AI assistant that uses USDA knowledge, "
        f"soil science, and crop management expertise to provide accurate, practical advice.\n\n"
        f"User question: {user_query}\n\n"
        f"USDA API results (if any):\n{usda_info}\n\n"
        f"Your task:\n"
        f"- If USDA data is relevant (nutritional or crop facts), summarize it.\n"
        f"- Otherwise, explain the farming process for this crop based on USDA best practices and U.S. agricultural guidelines.\n"
        f"- Include details like soil type, pH, irrigation, fertilizer, pest/disease management, and harvest timing.\n"
        f"- Write in a clear, friendly tone suitable for a new farmer.\n"
        f"Keep your answer concise, factual, and educational."
    )

    try:
        response = agent(ai_prompt)
        return getattr(response, "content", str(response))
    except Exception as e:
        return f"AI processing failed: {str(e)}"


if __name__ == "__main__":
    print(run_usda_query("How can I start farming corn?"))
