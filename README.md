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
- auto_replay_capture.lua 
    - opens replay
    - captures replay data and savess as jason
    - closes replay
    - navigates to next replay

- replay_capture.ua
    - detects when replay is running
    - captures replay data and saves as json

- flow_control.lua
    - allows control and reading of SF6 state via json files

- sf6_obs_replay_capture.py
    - detects when replay is running via flow_control.lua
    - communicate with OBS via websocket to capture replay

## Settings
- .env (python)
    - ```LOG_PATH```
    - ```REFAMEWORK_PATH```
    - ```OBS_HOST```
    - ```OBS_PORT```
    - ```OBS_PASSWORD```

- paths.lua



