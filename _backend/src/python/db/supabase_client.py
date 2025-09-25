# supabase_client.py - Manage connections to Supabase
import os
import logging
from supabase import create_client, Client
from dotenv import load_dotenv
from typing import Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class SupabaseManager:
    _client: Optional[Client] = None

    @classmethod
    def get_client(cls) -> Client:

        if cls._client is None:
            logging.info("Initializing new Supabase client...")
            load_dotenv()
            
            url = os.getenv("SUPABASE_URL")
            key = os.getenv("SUPABASE_SERVICE_ROLE")

            if not url or not key:
                logging.error("❌ Supabase URL or Key is missing from .env file.")
                raise ValueError("Supabase URL or Key not found in environment variables.")

            try:
                cls._client = create_client(url, key)
                logging.info("✅ Successfully connected to Supabase!")
            except Exception as e:
                logging.error(f"❌ Failed to connect to Supabase: {e}")
                raise

        return cls._client

def get_supabase_client() -> Client:
    return SupabaseManager.get_client()

if __name__ == "__main__":
    get_supabase_client()