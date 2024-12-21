local paths = {}

paths.replay_path = "replay_capture/"
paths.in_out_path = "state_status/"
paths.in_state_path = paths.in_out_path.."sf6_state_status_in.json"
paths.out_state_path = paths.in_out_path.."sf6_state_status_out.json"
paths.error_log_path = "ui_interact_log.json"

return paths