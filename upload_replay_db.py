import json
from db.models import CFNReplayRound, CFNUserName, CFNRawReplay, CFNUser, CFNReplay
from db import db
import sys


def create_cfn_users_if_not_exists(session, replay_data):
    cfn_users = {}

    for p in [0,1]:
        cfn_users[p] = session.query(CFNUser).filter_by(
            id=replay_data['player_data'][f'player_{p+1}_cfn_id'],
        ).first()
        
        if not cfn_users[p]:
            cfn_users[p] = CFNUser(
                id=replay_data['player_data'][f'player_{p+1}_cfn_id'],
            )
            session.add(cfn_users[p])
            session.flush()
            
    return cfn_users


def create_cfn_user_names_if_not_exists(session, replay_data):
    cfn_user_names = {}

    for p in [0,1]:
        cfn_user_name = session.query(CFNUserName).filter_by(
            cfn_user_id=replay_data['player_data'][f'player_{p+1}_cfn_id'],
            cfn_name= replay_data['player_data'][f'player_{p+1}_cfn']
        ).first()

        if not cfn_user_name:
            cfn_user_name = CFNUserName(
                cfn_user_id=replay_data['player_data'][f'player_{p+1}_cfn_id'],
                cfn_name= replay_data['player_data'][f'player_{p+1}_cfn']
            )
            session.add(cfn_user_name)
            session.flush()

    return cfn_user_names


def create_cfn_replay_if_not_exists(session, replay_data):
    cfn_replay = session.query(CFNReplay).filter_by(
        id = replay_data['replay_id']
    ).first()

    if not cfn_replay:
        cfn_replay = CFNReplay(
            id = replay_data['replay_id'],
            player_0_id = replay_data['player_data']['player_1_cfn_id'],
            player_1_id = replay_data['player_data']['player_2_cfn_id'],
            player_0_character_id = replay_data['player_data']['player_0_id'],
            player_1_character_id = replay_data['player_data']['player_0_id'],
            player_one_input_type = replay_data['player_data']['player_1_input_type'],
            player_two_input_type = replay_data['player_data']['player_2_input_type'],
            replay_battle_type = replay_data['replay_battle_type']
        )
        session.add(cfn_replay)
        session.flush()

    return cfn_replay


def upsert_cfn_replay_rounds(session, replay_data):
    round_result = {}

    cfn_replay = session.query(CFNReplay).filter_by(
        id=replay_data['replay_id']
    ).first()

    if not cfn_replay:
        raise Exception(f"No CFN replay {replay_data['replay_id']}.")
    
    # rounds with finish_type == 0 are invalid
    round_numbers = [
        round_number 
        for round_number, round_result in replay_data['round_results'].items() 
        if round_result['finish_type'] != 0
    ]  

    for round_number in round_numbers:
        round_result = replay_data['round_results'][round_number]

        existing_round = session.query(CFNReplayRound).filter_by(
            cfn_replay_id=replay_data['replay_id'],
            round_number=round_number
        ).first()

        if existing_round:
            existing_round.winner = round_result['win_type']
            existing_round.finish_type = round_result['finish_type']
            round_result[round_number] = existing_round
        else:
            new_round = CFNReplayRound(
                cfn_replay_id=replay_data['replay_id'],
                round_number=round_number,
                winner=round_result['win_type'],
                finish_type=round_result['finish_type']
            )
            session.add(new_round)
            round_result[round_number] = new_round

        session.flush()

    return round_result


def bulk_insert_rounds(session, replay_data):
    cfn_replay = session.query(CFNReplay).filter_by(
        id=replay_data['replay_id']
    ).first()

    if not cfn_replay:
        raise Exception(f"No CFN replay {replay_data['replay_id']}.")
    
    session.query(CFNRawReplay).filter_by(cfn_replay_id=replay_data['replay_id']).delete()
    session.flush() 
    
    bulk_data = []

    # rounds with finish_type == 0 are invalid
    round_numbers = [
        round_number 
        for round_number, round_result in replay_data['round_results'].items() 
        if round_result['finish_type'] != 0
    ]      
    for round_number in round_numbers:
        for frame, frame_data in replay_data[round_number].items():
            row = {
                "cfn_replay_id": replay_data['replay_id'],
                "frame": frame,
                "round_timer": frame_data['round_stats']['round_timer'],
                "round_number": round_number
            }

            for player_tag in ['p1','p2']:
                try:
                    player_num = int(player_tag[1])-1
                    row[f'p{player_num}_hp_cap'] = frame_data[player_tag]['HP_cap']
                    row[f'p{player_num}_hp_cooldown'] = frame_data[player_tag]['HP_cooldown']
                    row[f'p{player_num}_absolute_range'] = frame_data[player_tag]['absolute_range']
                    row[f'p{player_num}_act_st'] = frame_data[player_tag]['act_st']
                    row[f'p{player_num}_current_hp'] = frame_data[player_tag]['current_HP']
                    row[f'p{player_num}_drive'] = frame_data[player_tag]['drive']
                    row[f'p{player_num}_drive_cooldown'] = frame_data[player_tag]['drive_cooldown']
                    row[f'p{player_num}_input_data'] = frame_data[player_tag]['input_data']
                    row[f'p{player_num}_input_side'] = frame_data[player_tag]['input_side']
                    row[f'p{player_num}_mactionframe'] = frame_data[player_tag]['mActionFrame']
                    row[f'p{player_num}_mactionid'] = frame_data[player_tag]['mActionId']
                    row[f'p{player_num}_stance'] = frame_data[player_tag]['stance']
                    row[f'p{player_num}_posx'] = frame_data[player_tag]['posX']
                    row[f'p{player_num}_posy'] = frame_data[player_tag]['posY']
                    row[f'p{player_num}_super'] = frame_data[player_tag]['super']
                except ValueError as v:
                    print(f"frame_data={frame_data}")
                    raise v
            bulk_data.append(row)
    
    session.bulk_insert_mappings(CFNRawReplay, bulk_data)

def upload_replay_to_db(file_path):
    replay_data = None

    try:
        with open(f"{file_path}", 'r',encoding='utf-8') as f:
            replay_data = json.load(f)
    except Exception as e:
        raise e

    with (db.SessionMaker() as session):
        try:
            create_cfn_users_if_not_exists(session,replay_data)
            create_cfn_user_names_if_not_exists(session,replay_data)
            create_cfn_replay_if_not_exists(session, replay_data)
            upsert_cfn_replay_rounds(session, replay_data)
            bulk_insert_rounds(session, replay_data)

            session.commit()

        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()
            
def main():
    if len(sys.argv) < 2:
        print("python upload_replay_db.py 'replay.json'")
        return
    print("Uploading replay...")
    upload_replay_to_db(sys.argv[1])
    print(f"Done.")

if __name__=="__main__":
    main()