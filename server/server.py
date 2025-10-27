
from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import tempfile
import os
import json
from dotenv import load_dotenv
from groq import Groq
from groq import RateLimitError, APIError
import logging
from transformers import BlipProcessor, BlipForConditionalGeneration
from PIL import Image
import torch
import io

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

app = FastAPI(title="ClassEcho")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

device = "cuda" if torch.cuda.is_available() else "cpu"
processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-large")
model = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-large").to(device)

@app.post("/caption")
async def generate_caption(file: UploadFile = File(...)):
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")

    inputs = processor(images=image, return_tensors="pt").to(device)

    out = model.generate(**inputs, max_length=30)
    caption = processor.decode(out[0], skip_special_tokens=True)

    return {"caption": caption}

# ==========================================
# GROQ API KEY ROTATION MANAGER
# ==========================================
class GroqKeyManager:
    def __init__(self):
        # Load all available API keys from environment
        self.api_keys = []
        self.current_key_index = 0
        
        # Load keys in order: GROQ_API_KEY, GROQ_API_KEY1, GROQ_API_KEY2, etc.
        base_key = os.environ.get("GROQ_API_KEY")
        if base_key:
            self.api_keys.append(base_key)
            logger.info(f"Loaded GROQ_API_KEY")
        
        # Load numbered keys
        i = 1
        while True:
            key = os.environ.get(f"GROQ_API_KEY{i}")
            if key:
                self.api_keys.append(key)
                logger.info(f"Loaded GROQ_API_KEY{i}")
                i += 1
            else:
                break
        
        if not self.api_keys:
            raise ValueError("No Groq API keys found in environment variables!")
        
        logger.info(f"Total API keys loaded: {len(self.api_keys)}")
        
        # Initialize client with first key
        self.client = Groq(api_key=self.api_keys[self.current_key_index])
    
    def get_client(self):
        """Get current Groq client"""
        return self.client
    
    def rotate_key(self):
        """Rotate to next available API key"""
        if len(self.api_keys) <= 1:
            logger.error("No backup keys available!")
            raise HTTPException(
                status_code=503,
                detail="All API keys exhausted. Please try again later."
            )
        
        self.current_key_index = (self.current_key_index + 1) % len(self.api_keys)
        self.client = Groq(api_key=self.api_keys[self.current_key_index])
        logger.warning(f"Rotated to API key #{self.current_key_index + 1}")
        return self.client
    
    async def execute_with_retry(self, func, *args, max_retries=None, **kwargs):
        """
        Execute a function with automatic key rotation on rate limit
        
        Args:
            func: The function to execute
            max_retries: Maximum number of key rotations (default: number of keys)
            *args, **kwargs: Arguments to pass to the function
        """
        if max_retries is None:
            max_retries = len(self.api_keys)
        
        last_error = None
        
        for attempt in range(max_retries):
            try:
                # Execute the function with current client
                result = await func(self.get_client(), *args, **kwargs)
                return result
                
            except RateLimitError as e:
                last_error = e
                logger.warning(f"Rate limit hit on key #{self.current_key_index + 1}: {str(e)}")
                
                if attempt < max_retries - 1:
                    # Rotate to next key
                    self.rotate_key()
                    logger.info(f"Retrying with key #{self.current_key_index + 1}...")
                else:
                    logger.error("All API keys exhausted!")
                    
            except APIError as e:
                # For other API errors, don't retry
                logger.error(f"API Error: {str(e)}")
                raise HTTPException(status_code=500, detail=f"API Error: {str(e)}")
            
            except Exception as e:
                logger.error(f"Unexpected error: {str(e)}")
                raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
        
        # If we exhausted all retries
        raise HTTPException(
            status_code=429,
            detail=f"All {len(self.api_keys)} API keys are rate limited. Please try again later."
        )

# Initialize key manager
key_manager = GroqKeyManager()

# ==========================================
# ENDPOINTS
# ==========================================

@app.get("/")
def home():
    return {
        "message": "Welcome to RESQ API",
        "available_keys": len(key_manager.api_keys),
        "current_key": key_manager.current_key_index + 1
    }

@app.get("/api-status")
def api_status():
    """Check API key status"""
    return {
        "total_keys": len(key_manager.api_keys),
        "current_key_index": key_manager.current_key_index + 1,
        "keys_remaining": len(key_manager.api_keys) - key_manager.current_key_index
    }




async def get_user_intent(client: Groq, text: str) -> dict:
    """
    Identifies user intent from spoken or written request using Groq API
    
    Args:
        client: Groq client instance
        text: User's spoken or written input
        
    Returns:
        dict: Intent detection result with fields:
              - intent, listen_back, contact_option, want_to_call, want_to_share, response
    """
    
    prompt = f"""
You are an AI assistant that identifies the user's intent based on their spoken or written request.

From the following text, extract exactly ONE intent from these ten options:
1. connect_glasses
2. object_detection
3. scene_description
4. ocr
5. navigation
6. list_contacts
7. call_contact
8. list_share_contacts
9. share_location
10. yes_no_response
11. emergency


Text: "{text}"

Return the result in the following strict JSON format:

{{
  "intent": "<one_of_the_above_ten>",
  "listen_back": true/false,
  "contact_option": null or <integer>,
  "want_to_call": true/false,
  "want_to_share": true/false,
  "response": "yes" or "no" or null
}}

Rules:
- Do NOT add explanations or extra keys.
- Choose ONLY the most relevant intent based on the text.
- For all values, use lowercase: true, false, null
- response field is ONLY used for yes_no_response intent
- want_to_share field is used for share_location intent

INTENT RULES:
- If the user wants to connect to glasses, or identify connection → use "connect_glasses"
- If the user is asking to read, extract text, or identify letters/boards → use "ocr"
- If they want to know what is happening in the surroundings → use "scene_description"
- If they are asking about a specific item or thing → use "object_detection"
- If they want directions, movement, or path guidance → use "navigation"
- If the user asks for emergency or alert to family → use "emergenecy" 

YES/NO RESPONSE RULES:
- If the user simply says "yes", "yeah", "sure", "okay", "yep", "absolutely" → use "yes_no_response" with response: "yes"
- If the user simply says "no", "nope", "nah", "not now", "don't", "cancel" → use "yes_no_response" with response: "no"
- Set all other fields to null/false for yes_no_response

CALL CONTACT RULES:
- If the user asks "what are my contacts", "list my contacts", "show my contacts", "who can I call" → use "list_contacts" with listen_back: true, want_to_call: false
- If the user says "I want to call", "call someone", "make a call", "call a contact" → use "list_contacts" with listen_back: true, want_to_call: false
- If the user specifies "call option 1", "call option 2", "call the first", "dial option 1", etc. → use "call_contact" with listen_back: false, contact_option: <number>, want_to_call: false
- If the user confirms a call after hearing the contact → use "call_contact" with listen_back: false, contact_option: <last_heard_option>, want_to_call: true
- listen_back: true means ask for confirmation before proceeding
- listen_back: false means directly process the call
- want_to_call: true when user explicitly confirms they want to call; false otherwise

SHARE LOCATION RULES (NEW):
- If the user asks "share my location", "share location", "/share", "share my current location", "send my location", "share where I am" → use "list_share_contacts" with listen_back: true, want_to_share: false
- If the user says "I want to share", "share with someone", "share location with contacts", "send my location to contacts" → use "list_share_contacts" with listen_back: true, want_to_share: false
- If the user specifies "share with option 1", "share to option 2", "share with the first", "send to option 1", etc. → use "share_location" with listen_back: false, contact_option: <number>, want_to_share: false
- If the user confirms sharing after hearing the contact → use "share_location" with listen_back: false, contact_option: <last_heard_option>, want_to_share: true
- If the user says "share with all" or "share with everyone" → use "share_location" with listen_back: false, contact_option: -1 (represents all contacts), want_to_share: true
- listen_back: true means ask for confirmation before sharing
- listen_back: false means directly process the share
- want_to_share: true when user explicitly confirms they want to share; false otherwise
- contact_option: -1 means share with all contacts; positive integer (1, 2, 3...) means specific contact

EXAMPLES:
1. User: "Show me my contacts"
   Response: {{"intent": "list_contacts", "listen_back": true, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": null}}

2. User: "I want to call someone"
   Response: {{"intent": "list_contacts", "listen_back": true, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": null}}

3. User: "Call option number 1"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 1, "want_to_call": true, "want_to_share": false, "response": null}}
4. User: "Call option number 2"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 2, "want_to_call": true, "want_to_share": false, "response": null}}
5. User: "Call option number 3"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 3, "want_to_call": true, "want_to_share": false, "response": null}}

6. User: "Call option number 4"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 4, "want_to_call": true, "want_to_share": false, "response": null}}

7. User: "Yes"
   Response: {{"intent": "yes_no_response", "listen_back": false, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": "yes"}}

8. User: "No"
   Response: {{"intent": "yes_no_response", "listen_back": false, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": "no"}}

9. User: "Yes, call the first contact"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 1, "want_to_call": true, "want_to_share": false, "response": null}}

10. User: "Yes, call the second contact"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 2, "want_to_call": true, "want_to_share": false, "response": null}}

11. User: "Yes, call the third contact"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 3, "want_to_call": true, "want_to_share": false, "response": null}}

12. User: "Yes, call the fourth contact"
   Response: {{"intent": "call_contact", "listen_back": false, "contact_option": 4, "want_to_call": true, "want_to_share": false, "response": null}}

13. User: "Share my location"
   Response: {{"intent": "list_share_contacts", "listen_back": true, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": null}}

14. User: "/share"
   Response: {{"intent": "list_share_contacts", "listen_back": true, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": null}}

15. User: "Share location with option 1"
   Response: {{"intent": "share_location", "listen_back": false, "contact_option": 1, "want_to_call": false, "want_to_share": true, "response": null}}

16. User: "Share location with option number 2"
   Response: {{"intent": "share_location", "listen_back": false, "contact_option": 2, "want_to_call": false, "want_to_share": true, "response": null}}

17. User: "Share location with option 3"
   Response: {{"intent": "share_location", "listen_back": false, "contact_option": 3, "want_to_call": false, "want_to_share": true, "response": null}}

18. User: "Share location with option 4"
   Response: {{"intent": "share_location", "listen_back": false, "contact_option": 4, "want_to_call": false, "want_to_share": true, "response": null}}

19. User: "Share with all contacts"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": -1, "want_to_call": false, "want_to_share": true, "response": null}}

20. User: "Yes, share my location to option 1"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 1, "want_to_call": false, "want_to_share": true, "response": null}}


21. User: "Yes, share my location to option 2"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 2, "want_to_call": false, "want_to_share": true, "response": null}}

22. User: "Yes, share my location to option 3"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 3, "want_to_call": false, "want_to_share": true, "response": null}}

23. User: "Yes, share my location to option 4"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 4, "want_to_call": false, "want_to_share": true, "response": null}}

24. User: "Send my location to option 1"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 1, "want_to_call": false, "want_to_share": false, "response": null}}

25. User: "Send my location to option 2"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 2, "want_to_call": false, "want_to_share": false, "response": null}}

26. User: "Send my location to option 3"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 3, "want_to_call": false, "want_to_share": false, "response": null}}

27. User: "Send my location to option 4"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": 4, "want_to_call": false, "want_to_share": false, "response": null}}

28. User: "Yes, I want to share"
    Response: {{"intent": "share_location", "listen_back": false, "contact_option": null, "want_to_call": false, "want_to_share": true, "response": null}}

29. User: "No, don't share"
    Response: {{"intent": "yes_no_response", "listen_back": false, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": "no"}}

30. User: "Navigate to home"
    Response: {{"intent": "navigation", "listen_back": false, "contact_option": null, "want_to_call": false, "want_to_share": false, "response": "home"}}

31. User: "I need help"
    Response: {{"intent": "emergency", "listen_back": false, "contact_option": 1, "want_to_call": true, "want_to_share": true, "response": "emergency"}}

32. User: "Help me"
    Response: {{"intent": "emergency", "listen_back": false, "contact_option": 1, "want_to_call": true, "want_to_share": true, "response": "emergency"}}

33. User: "It’s an emergency"
    Response: {{"intent": "emergency", "listen_back": false, "contact_option": 1, "want_to_call": true, "want_to_share": true, "response": "emergency"}}

34. User: "ALERT FAMILY"
    Response: {{"intent": "emergency", "listen_back": false, "contact_option": 1, "want_to_call": true, "want_to_share": true, "response": "emergency"}}
"""
    
    try:
        # Call Groq API
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            response_format={"type": "json_object"}
        )

        raw_output = response.choices[0].message.content.strip()
        print(f"Raw API Response: {raw_output}")

        # Try to parse JSON
        try:
            intent_data = json.loads(raw_output)
        except json.JSONDecodeError:
            # Fallback: extract JSON from response if it contains extra text
            print("⚠️ JSON parsing failed, attempting to extract JSON from response...")
            start = raw_output.find("{")
            end = raw_output.rfind("}") + 1
            
            if start != -1 and end > start:
                json_str = raw_output[start:end]
                intent_data = json.loads(json_str)
            else:
                print("❌ Could not extract valid JSON")
                return {
                    "intent": "unknown",
                    "listen_back": False,
                    "contact_option": None,
                    "want_to_call": False,
                    "want_to_share": False,
                    "response": None
                }

        # Validate required fields
        required_fields = ["intent", "listen_back", "contact_option", "want_to_call", "want_to_share", "response"]
        for field in required_fields:
            if field not in intent_data:
                intent_data[field] = None

        print(f"✅ Parsed Intent Data: {intent_data}")
        print(f"📊 Intent Type: {intent_data.get('intent', 'unknown')}")
        
        return intent_data

    except Exception as e:
        print(f"❌ Error in get_user_intent: {e}")
        return {
            "intent": "error",
            "listen_back": False,
            "contact_option": None,
            "want_to_call": False,
            "want_to_share": False,
            "response": None
        }





@app.post("/get_user_intent")
async def get_intent(request: Request):
    try:
        data = await request.json()
        audioText = data.get("audioText", "").strip()
        print("Received audioText:", audioText)
        logger.info("Starting intent Processing")

        intent_result = await key_manager.execute_with_retry(
            get_user_intent,
            audioText
        )

        logger.info("Intent generation was success", intent_result)
        return JSONResponse(content=intent_result)
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
        