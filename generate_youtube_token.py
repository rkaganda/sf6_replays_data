import os
from dotenv import load_dotenv
from google_auth_oauthlib.flow import InstalledAppFlow

load_dotenv()

def main():    
    YOUTUBE_SECRET_PATH = os.getenv('YOUTUBE_SECRET_PATH')
    YOUTUBE_TOKEN_PATH = os.getenv('YOUTUBE_TOKEN_PATH')

    SCOPES = ["https://www.googleapis.com/auth/youtube.upload",
              "https://www.googleapis.com/auth/youtube.readonly"]

    flow = InstalledAppFlow.from_client_secrets_file(
        YOUTUBE_SECRET_PATH, SCOPES
    )
    credentials = flow.run_local_server(port=0)

    with open(YOUTUBE_TOKEN_PATH, "w") as token_file:
        token_file.write(credentials.to_json())
    print(f"Token saved to {YOUTUBE_TOKEN_PATH}")

if __name__=="__main__":
    main()