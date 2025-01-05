import sys
import cv2
from dotenv import load_dotenv
from db import db
from db.models import CFNReplay, VideoReplayTiming
import os

load_dotenv()


def store_round_timings_in_db(round_timings, cfn_replay_id):
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
            
            for round_number, round_timing in enumerate(round_timings):
                video_replay_timing = VideoReplayTiming(
                    cfn_replay_id=cfn_replay.id,
                    round_number=round_number,
                    round_start_time_seconds=round_timing['start_time'],
                    round_end_time_seconds=round_timing.get('end_time',0)
                )
                session.add(video_replay_timing)

            session.commit()

        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()


def check_threshold(
        region, 
        compare_threshold, 
        frame_num, 
        fps,
        template_image, 
        best_regions,
        prev_frame_matched,
        display_after=sys.maxsize
    ):
    ncc_score = cv2.matchTemplate(region, template_image, cv2.TM_CCOEFF_NORMED)
    highest_ncc = [-1,-1]
    min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(ncc_score)
    if (max_val>highest_ncc[0]):
        highest_ncc[0] = max_val
        highest_ncc[1] = frame_num
    
    if display_after < frame_num:
        print(f"{frame_num} {max_val}")

    if(max_val > compare_threshold and not prev_frame_matched) :
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

    return best_regions, prev_frame_matched


def get_round_starts(video_cap, fight_template_image, ko_template_image, p_ko_template_image):
    print("Checking for round starts...")
    video_cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
    fps = video_cap.get(cv2.CAP_PROP_FPS)
    frame_num = 0
    fight_compare_threshold = .65
    ko_compare_threshold = .65

    # capture region
    width = int(video_cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    x_sub = int(width/64)
    y_sub = int(width/64)
    x_fight, y_fight, w_fight, h_fight = x_sub*22, y_sub*14, x_sub*8, y_sub*8

    x_ko, y_ko, w_ko, h_ko = x_sub*21, y_sub*12, x_sub*7, y_sub*12
    
    fight_prev_frame_matched = False
    ko_prev_frame_matched = False
    fight_best_regions = []
    ko_best_regions = []

    while True:
        ret, frame = video_cap.read()

        if not ret:
            break

        fight_region = frame[y_fight:y_fight+h_fight, x_fight:x_fight+w_fight]
        ko_region = frame[y_ko:y_ko+h_ko, x_ko:x_ko+w_ko]

        fight_best_regions, fight_prev_frame_matched = check_threshold(
            fight_region, 
            fight_compare_threshold, 
            frame_num, 
            fps,
            fight_template_image, 
            fight_best_regions,
            fight_prev_frame_matched
        )
        ko_best_regions, ko_prev_frame_matched = check_threshold(
            ko_region, 
            ko_compare_threshold, 
            frame_num, 
            fps,
            ko_template_image, 
            ko_best_regions,
            ko_prev_frame_matched,
        )
        ko_best_regions, ko_prev_frame_matched = check_threshold(
            ko_region, 
            ko_compare_threshold, 
            frame_num, 
            fps,
            p_ko_template_image, 
            ko_best_regions,
            ko_prev_frame_matched,
        )
        frame_num +=1

    rounds = []
    fight_last_time_seconds = 0
    seconds_margin = 5
    round_min_time = 5

    if len(fight_best_regions) == 0:
        print(f"FIGHT NO ROUNDS!")
    last_fight_index = 0
    for best in fight_best_regions:
        if best['seconds_time'] - fight_last_time_seconds > seconds_margin:
            round_time = {}
            round_time['start_time'] = int(best['seconds_time']+1)
            fight_last_time_seconds = best['seconds_time']
            print(f"{round_time['start_time']}")
            for end_idx in range(last_fight_index, len(ko_best_regions)):
                ko_best = ko_best_regions[end_idx]
                print(f"checking {end_idx} {ko_best}")
                print(f"{ko_best['seconds_time']-round_time['start_time']} > round_min_time")
                if ko_best['seconds_time'] - round_time['start_time'] > round_min_time:
                    print(f"last_fight_index={end_idx}")
                    round_time['end_time'] = ko_best['seconds_time']
                    last_fight_index = end_idx+1
                    break
            rounds.append(round_time)
    print(rounds)
    
    return rounds
    



def update_timing(video_path):
    fight_template_path = "data/img_templates/fight_region_div32_11_7_4_4.png"
    ko_template_path = "data/img_templates/ko_region_div64_21_12_7_12.png"
    p_ko_template_path = "data/img_templates/p_ko_region_div64_21_12_7_12.png"

    print(f"video_path={video_path}")
    replay_id = os.path.splitext(os.path.basename(video_path))[0]
    print(f"replay_id={replay_id}")

    video_cap = cv2.VideoCapture(video_path)
    fight_template_image = cv2.imread(fight_template_path)
    ko_template_image = cv2.imread(ko_template_path)
    p_ko_template_image = cv2.imread(p_ko_template_path)

    if not video_cap.isOpened():
        print("No file")
    
    rounds = get_round_starts(video_cap, fight_template_image, ko_template_image, p_ko_template_image)
    store_round_timings_in_db(rounds, replay_id)
    print(f"rounds={rounds}")
 

def main():
    pass

if __name__=="__main__":
    main()


