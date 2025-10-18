import os
from dotenv import load_dotenv
import boto3

load_dotenv()

class Config:

    AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
    AWS_REGION = os.getenv('AWS_REGION')
    
    CUSTOM_LABEL_MODEL_ARN = os.getenv('CUSTOM_LABEL_MODEL_ARN')
    CUSTOM_MIN_CONFIDENCE = float(os.getenv('CUSTOM_MIN_CONFIDENCE'))
    MAX_CUSTOM_LABELS = int(os.getenv('MAX_CUSTOM_LABELS'))

    MONGO_URI = "mongodb+srv://mongodb:mongopassword@cluster0.0fcuzdh.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
    DB_NAME = "learn_linux"
    
    @staticmethod
    def get_rekognition_client():
        return boto3.client(
            'rekognition',
            aws_access_key_id=Config.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=Config.AWS_SECRET_ACCESS_KEY,
            region_name=Config.AWS_REGION
        )