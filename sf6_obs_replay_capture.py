import time
import json
import logging
from typing import Dict
import multiprocessing
from ctypes import c_bool
import obsws_python as obs
import os
import json
from dotenv import load_dotenv

load_dotenv()

LOG_PATH = os.getenv('LOG_PATH')
REFRAMEWORK_PATH = os.getenv('REFRAMEWORK_PATH')
OBS_HOST = os.getenv('OBS_HOST')
OBS_PORT = os.getenv('OBS_PORT')
OBS_PASSWORD = os.getenv('OBS_PASSWORD')

logger = logging.getLogger('sf6_replay_video_capture')
logger.setLevel(logging.DEBUG)
handler = logging.FileHandler(LOG_PATH, encoding='utf-8', mode='a')
handler.setFormatter(logging.Formatter('%(asctime)s:%(levelname)s:%(name)s: %(message)s'))
logger.addHandler(handler)

out_status_path = f"{REFRAMEWORK_PATH}/data/state_status/sf6_state_status_out.json"

def get_sf6_out_status() -> Dict[str, str]:
    sf6_status = None  

    while sf6_status is None:
        try:
            with open(out_status_path) as file:
                sf6_status = json.load(file)
        except json.decoder.JSONDecodeError:  
            pass
    return sf6_status

def capture_replay(cfn_replay_id):
    replay_running = multiprocessing.Value(c_bool, True)
    process = multiprocessing.Process(target=capture_video, args=(cfn_replay_id, replay_running))
    process.start()
    print("Started capture process...")

    while "ReplayPlaying" == get_sf6_out_status()['current_ui_state_name']:
        time.sleep(0.1)

    replay_running.value = False
    process.join()
    print("Capture process finished.")


def rename_file_with_timeout(old_name, new_name, timeout=30):
    start_time = time.time()
    while True:
        try:
            os.rename(old_name, new_name)
            print(f"Renamed: {new_name}")
            break  
        except OSError as e:
            if "used by another process" in str(e).lower():
                elapsed_time = time.time() - start_time
                if elapsed_time > timeout:
                    raise TimeoutError(f"File is in use. Could not rename within {timeout} seconds.") from e
                time.sleep(1)  
            else:
                raise


def capture_video(video_title, replay_running):
    print(f"cfn_replay_id={video_title}")
    cl = obs.ReqClient(host=OBS_HOST, port=OBS_PORT, password=OBS_PASSWORD)
    resp = cl.get_version()

    try:    
        cl.send("StartRecord", raw=False)
        print("Recording started")

        while replay_running.value:
            time.sleep(0.1)

        resp = cl.send("StopRecord", raw=True)
        print("Recording stopped")
        
        old_name = resp['outputPath']
        old_path = "/".join(resp['outputPath'].split('/')[:-1])
        type = resp['outputPath'].split('/')[-1].split(".")[-1]
        new_file = f"{old_path}/{video_title}.{type}"
        rename_file_with_timeout(old_name,new_file)
        
    except Exception as e:
        print(e)
        logger.error(f"{e}")


def main():
    last_state_name = ""
    while True:
        current_state_name = get_sf6_out_status()['current_ui_state_name']
        if last_state_name != current_state_name:
            last_state_name = current_state_name
            print(f"SF6 state={last_state_name}")
        if "ReplayPlaying" == current_state_name:
            cfn_replay_id = get_sf6_out_status()['cfn_replay_id']
            capture_replay(cfn_replay_id)
            

if __name__ == "__main__":
    main()
