import sys
import cv2
from dotenv import load_dotenv
from db import db
from db.models import CFNReplay, YoutubeReplayVideo
from replay_timing import update_timing
import os
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2.credentials import Credentials

load_dotenv()


def upload_replay_to_youtube(video_path, replay_id):
    youtube_video_id = None
    YOUTUBE_TOKEN_PATH = os.getenv('YOUTUBE_TOKEN_PATH')

    SCOPES = ["https://www.googleapis.com/auth/youtube.upload",
              "https://www.googleapis.com/auth/youtube.readonly"]

    if os.path.exists(YOUTUBE_TOKEN_PATH):
        credentials = Credentials.from_authorized_user_file(YOUTUBE_TOKEN_PATH, SCOPES)
        if credentials and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
            with open(YOUTUBE_TOKEN_PATH, "w") as token:
                token.write(credentials.to_json())

    youtube_service = build("youtube", "v3", credentials=credentials)

    try:
        with (db.SessionMaker() as session):
            cfn_replay = session.query(CFNReplay).filter_by(
                id=replay_id
            ).first()

            if not cfn_replay:
                raise Exception(f"No CFN replay {replay_id}.")

            request = youtube_service.search().list(
                part="id,snippet",
                forMine=True,
                type="video",
                q=replay_id,
                maxResults=50
            )
            response = request.execute()

            for item in response.get("items", []):
                if item["snippet"]["title"] == replay_id:
                    youtube_video_id = item["id"]["videoId"]
                    break

            if youtube_video_id:
                print(f"Video already exists with ID: {youtube_video_id}")
                youtube_replay_video = session.query(YoutubeReplayVideo).filter_by(
                    cfn_replay_id=cfn_replay.id
                ).first()

                if not youtube_replay_video:
                    youtube_replay_video = YoutubeReplayVideo(
                        cfn_replay_id=cfn_replay.id,
                        youtube_video_id=youtube_video_id
                    )
                    session.add(youtube_replay_video)
                else:
                    youtube_replay_video.youtube_video_id = youtube_video_id

            else:
                print("Video does not exist. Proceeding to upload.")
                request_body = {
                    "snippet": {
                        "title": replay_id,
                        "description": f"{replay_id}",
                        "tags": [],
                        "categoryId": "20"  # gaming
                    },
                    "status": {
                        "privacyStatus": "unlisted",
                        "madeForKids": False
                    }
                }
                media = MediaFileUpload(video_path, chunksize=-1, resumable=True)

                request = youtube_service.videos().insert(
                    part="snippet,status",
                    body=request_body,
                    media_body=media
                )
                print("Uploading video...")
                response = request.execute()
                youtube_video_id = response['id']
                print(f"Video uploaded OK. Video ID: {youtube_video_id}")

                youtube_replay_video = YoutubeReplayVideo(
                    cfn_replay_id=cfn_replay.id,
                    youtube_video_id=youtube_video_id
                )
                session.add(youtube_replay_video)

            session.flush()
            session.commit()

    except Exception as e:
        print("rollback")
        session.rollback()
        raise e
    finally:
        session.close()

def upload_replay(video_path):
    template_path = "data/fight_region_div32_11_7_4_4.png"

    print(f"video_path={video_path}")
    replay_id = os.path.splitext(os.path.basename(video_path))[0]
    print(f"replay_id={replay_id}")

    video_cap = cv2.VideoCapture(video_path)
    template_image = cv2.imread(template_path)

    if not video_cap.isOpened():
        print("No file")
        exit()
    
    upload_replay_to_youtube(video_path, replay_id)
    update_timing(video_path)
    video_cap.release()
    print(f"Done.")
 

def main():
    if len(sys.argv) < 2:
        print("python upload_replay_db.py 'replay.json'")
        return
    
    video_path = sys.argv[1]
    upload_replay_to_youtube(video_path)
    

if __name__=="__main__":
    main()


