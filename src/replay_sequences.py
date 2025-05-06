from sqlalchemy import and_, func, or_
from db import db
from db.models import HitstunSequencesView, MoveNameMapping, CFNRawReplay, CFNReplay, ReplaySequence, SequenceStep, Sequence
import os
import tqdm

def get_hitstun_sequences(cfn_replay_id, session):
    cfn_replay = session.query(CFNReplay).filter_by(
        id=cfn_replay_id
    ).first()

    sequences = (
        session.query(HitstunSequencesView)
        .filter(HitstunSequencesView.cfn_replay_id == cfn_replay_id)
        .order_by(
            HitstunSequencesView.round_number,
            HitstunSequencesView.player_id,
            HitstunSequencesView.sequence_id
        )
        .all()
    )
    
    result = []
    
    for sequence in sequences:
        start_frame, end_frame, player_id = sequence.start_frame, sequence.end_frame, sequence.player_id
        
        move_ids_query = (
            session.query(MoveNameMapping)
            .join(
                CFNRawReplay,
                CFNRawReplay.frame.between(start_frame, end_frame)
            )
            .filter(CFNRawReplay.cfn_replay_id == cfn_replay_id)
            .filter(CFNRawReplay.round_number == sequence.round_number)
            .filter(
                MoveNameMapping.act_st == (
                    CFNRawReplay.p0_act_st if player_id == 0 else CFNRawReplay.p1_act_st
                )
            )
            .filter(
                MoveNameMapping.m_action_id == (
                    CFNRawReplay.p0_mactionid if player_id == 0 else CFNRawReplay.p1_mactionid
                )
            )
            .filter(
                MoveNameMapping.character_id == (
                    cfn_replay.player_0_character_id if player_id == 0 else cfn_replay.player_1_character_id
                )
            )
            .order_by(CFNRawReplay.frame)
        )
        moves = [{"id":row.id, "maction_id":row.m_action_id} for row in move_ids_query]
        
        result.append({
            'cfn_replay_id': sequence.cfn_replay_id,
            'round_number': sequence.round_number,
            'player_id': player_id,
            'character_id': cfn_replay.player_0_character_id if player_id==0 else cfn_replay.player_1_character_id,
            'start_frame': start_frame,
            'end_frame': end_frame,
            'moves': moves,
        })
    
    return result


def create_if_not_exists_sequence(sequence, session):
    conditions = [
        and_(
            SequenceStep.step_num == step_num,
            SequenceStep.move_id == move['id']
        )
        for step_num, move in enumerate(sequence['moves'])
    ]

    sequence_id = (
        session.query(SequenceStep.sequence_id)
        .filter(or_(*conditions))  # Use OR to combine conditions
        .group_by(SequenceStep.sequence_id)
        .having(func.count(SequenceStep.id) == len(sequence['moves'])) 
        .limit(1)
        .scalar()
    )

    if sequence_id is None:
        db_sequence = Sequence(
            starter_move_id = sequence['moves'][0]['id'],
            character_id= sequence['character_id']
        )
        session.add(db_sequence)
        session.flush()
        sequence_id = db_sequence.id

        for step_num, move in enumerate(sequence['moves']):
            sequ_step = SequenceStep(
                sequence_id=sequence_id,
                step_num=step_num,
                move_id=int(move['id'])
            )
            session.add(sequ_step)
    
    replay_sequences = ReplaySequence(
        sequence_id = sequence_id,
        cfn_replay_id = sequence['cfn_replay_id'],
        start_frame = sequence['start_frame'],
        end_frame = sequence['end_frame'],
        round_number = sequence['end_frame'],
        player_id = sequence['player_id'],
    )
    session.add(replay_sequences)

    session.flush()


def upsert_replay_sequences(cfn_replay_id):
    with (db.SessionMaker() as session):
        sequences = get_hitstun_sequences(cfn_replay_id, session)

        session.query(ReplaySequence).filter_by(
            cfn_replay_id=cfn_replay_id
        ).delete()
        session.flush()

        for sequence in sequences:
            create_if_not_exists_sequence(sequence, session)

        session.commit()


def main():
    replay_path = "C:/SteamLibrary/steamapps/common/Street Fighter 6/reframework/data/replay_capture"

    files = [f for f in os.listdir(replay_path) if os.path.isfile(os.path.join(replay_path, f))]

    for fn in tqdm.tqdm(files):
        cfn_name = fn.split('_')[0]
        if(cfn_name=='recent'):
            continue
        upsert_replay_sequences(cfn_name)

if __name__=="__main__":
    main()




