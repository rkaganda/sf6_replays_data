import sys
import cv2
from dotenv import load_dotenv
from db import db
from db.models import CFNReplay, VideoReplayTiming, YoutubeReplayVideo
import os
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2.credentials import Credentials

load_dotenv()

def capture_frame(video_cap, frame_number):
    video_cap.set(cv2.CAP_PROP_POS_FRAMES, frame_number)
    position_msec = video_cap.get(cv2.CAP_PROP_POS_MSEC)
    position_sec = position_msec / 1000 
    print(position_sec)

    ret, frame = video_cap.read()

    if not ret:
        return
    
    width = int(video_cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    x_sub = int(width/32)
    y_sub = int(width/32)
    x, y, w, h = x_sub*11, y_sub*7, x_sub*4, y_sub*4

    region = frame[y:y+h, x:x+w]

    return region


def get_round_starts(video_cap, template_image):
    print("Checking for round starts...")
    video_cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
    fps = video_cap.get(cv2.CAP_PROP_FPS)
    frame_num = 0
    compare_threshold = .65

    # capture region
    width = int(video_cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    x_sub = int(width/32)
    y_sub = int(width/32)
    x, y, w, h = x_sub*11, y_sub*7, x_sub*4, y_sub*4
    
    prev_frame_matched = False
    best_regions = []

    while True:
        ret, frame = video_cap.read()

        if not ret:
            break

        region = frame[y:y+h, x:x+w]

        ncc_score = cv2.matchTemplate(region, template_image, cv2.TM_CCOEFF_NORMED)
        highest_ncc = [-1,-1]
        min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(ncc_score)
        if (max_val>highest_ncc[0]):
            highest_ncc[0] = max_val
            highest_ncc[1] = frame_num

        if(max_val > compare_threshold and not prev_frame_matched) :
            print(f"match on {frame_num} ncc_score={max_val}")
            best_regions.append({
                "best_start": frame_num,
                "best_start_score": max_val,
                "seconds_time":  frame_num/fps
            })
            prev_frame_matched = True
        elif max_val <= compare_threshold:
            if prev_frame_matched:
                best_regions[-1]['best_end'] = frame_num
                best_regions[-1]['best_end_score'] = max_val
            prev_frame_matched = False
        frame_num +=1

    round_starts = []
    last_time_seconds = 0
    seconds_margin = 5
    if len(best_regions) == 0:
        print(f"NO ROUNDS! {highest_ncc}")
    for best in best_regions:
        if best['seconds_time'] - last_time_seconds > seconds_margin:
            round_starts.append(int(best['seconds_time']+1))
            last_time_seconds = best['seconds_time']
        print(best)
        print(f"best length={best['best_end']-best['best_start']}")
    
    return round_starts
    
    
def store_round_starts_in_db(round_starts, cfn_replay_id):
    with (db.SessionMaker() as session):
        try:
            cfn_replay = session.query(CFNReplay).filter_by(
                id=cfn_replay_id
            ).first()

            if not cfn_replay:
                raise Exception(f"No CFN replay {cfn_replay_id}.")
            
            session.query(VideoReplayTiming).filter_by(
                cfn_replay_id=cfn_replay_id
            ).delete()
            
            for round_number, round_start in enumerate(round_starts):
                video_replay_timing = VideoReplayTiming(
                    cfn_replay_id=cfn_replay.id,
                    round_number=round_number,
                    round_start_time_seconds=round_start
                )
                session.add(video_replay_timing)

            session.commit()

        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()


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
    
    round_starts = get_round_starts(video_cap, template_image)
    store_round_starts_in_db(round_starts, replay_id)
    upload_replay_to_youtube(video_path, replay_id)
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


