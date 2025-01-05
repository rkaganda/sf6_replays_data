# SF6 data replay capture

### requires
- [REframework](https://github.com/praydog/REFramework) 
    - lua scripts that export SF6 replay data to json
    - allows control of SF6 via Python

- Python 3.11.x 
    - interface between REframework scripts and OBS
    - parse json replays

- OBS (with websocket)
    - captures SF6 replay video 

## Files

#### SF6 Replay Capture
- auto_replay_capture.lua 
    - opens replay
    - captures replay data and saves as jason
    - closes replay
    - navigates to next replay
    - (repeats)

- replay_capture.lua
    - detects when replay is running
    - captures replay data and saves as json

- flow_control.lua
    - allows control and reading of SF6 state via json files

- sf6_obs_replay_capture.py
    - detects when replay is running via flow_control.lua
    - communicate with OBS via websocket to capture replay


#### Replay Data Storage
- upload_replay_db.py
    - uploads replay and cfn data from the replay to db

- upload_replay_youtube.py
    - detects round starts and stores them in db
    - uploads replay to youtube

#### src
- replay_timing.py
    - update_timing - detects round start and round end, stores round start and round end in db

### data
- enums
    - characters - mactionid -> name
    - act_s id -> str
    - stance id -> str
    - img_templates - used for round start, round end detection ```replay_timing.py```

## Setup
- export_names.lua 
    - pulls act_st and stance from SF6, stores json in ```data\enum\```
- export_actions.lua 
    - pulls character mActionNames for characters play, stores json in ```data\enum\characters```
- db/scripts/create_view_migrations
    - creates migrations for views
- setup_db.py
    - ```create_tables``` creates tables to store replay data, suggest using ```alembic upgrade head``` instead as this WILL NOT create the views
    - ```update_sf6_data``` populates db with sf6 data from data\enum


- generate_youtube_token.py
    - creates token required for youtube uploads



## Config Files
- .env (python)
    - ```LOG_PATH```
    - ```REFAMEWORK_PATH```
    - ```OBS_HOST```
    - ```OBS_PORT```
    - ```OBS_PASSWORD```
    - ```SF6_DB_PATH```
    - ```SF6_DB_USERNAME```
    - ```SF6_DB_PASSWORD```
    - ```SF6_DB_SCHEMA```
    - ```YOUTUBE SECRET```
    - ```YOUTUBE TOKEN```

- paths.lua (reframework lua scripts)




