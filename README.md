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

- sf6_obs_replay_capture.py
    - detects when replay is running via flow_control.lua
    - communicate with OBS via websocket to capture replay 
    - renames saved video to cfn id after replay is complete

#### Replay Data Storage
- create_db_tables.py
    - creates tables to store replay data

- upload_replay_db.py
    - uploads replay and cfn data from the replay to db


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

- paths.lua (reframework lua scripts)



