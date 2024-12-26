from sqlalchemy import BigInteger, Column, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import declarative_base

Base = declarative_base()

class SF6Character(Base):
    __tablename__ = "sf6_characters"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False, unique=True)

class ActStName(Base):
    __tablename__ = "act_st_names"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)

class StanceName(Base):
    __tablename__ = "stance_names"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)

class MActionName(Base):
    __tablename__ = "m_action_names"
    id= Column(Integer, primary_key=True, autoincrement=True)
    m_action_id = Column(Integer, nullable=False)
    character_id = Column(Integer, ForeignKey('sf6_characters.id', ondelete='CASCADE'))
    name = Column(String, nullable=False)

class MoveNameMapping(Base):
    __tablename__ = "move_name_mappings"
    id = Column(Integer, primary_key=True, autoincrement=True)
    character_id = Column(Integer, ForeignKey('sf6_characters.id', ondelete='CASCADE'))
    act_st = Column(Integer, nullable=False)
    m_action_id = Column(Integer, nullable=False)
    move_name = Column(String, nullable=False)
    __table_args__ = (
        UniqueConstraint('character_id', 'm_action_id', 'act_st',name='uix_character_id_m_action_id_act_st'),
    )



class CFNUser(Base):
    __tablename__ = "cfn_users"
    id = Column(BigInteger, primary_key=True)

class CFNUserName(Base):
    __tablename__ = "cfn_user_names"
    id = Column(Integer, primary_key=True, autoincrement=True)
    cfn_name = Column(String, primary_key=True)
    cfn_user_id = Column(BigInteger, ForeignKey('cfn_users.id', ondelete='CASCADE'), primary_key=True)
    __table_args__ = (
        UniqueConstraint('cfn_name', 'cfn_user_id', name='uix_cfn_name_cfn_user_id'),
    )

class CFNReplayRound(Base):
    __tablename__ = "cfn_replay_rounds"
    id = Column(Integer, primary_key=True, autoincrement=True)
    cfn_replay_id = Column(String, ForeignKey('cfn_replays.id', ondelete='CASCADE'), nullable=False)
    round_number = Column(Integer, nullable=False) 
    winner = Column(String, nullable=False) 
    finish_type = Column(Integer, nullable=False)  

class CFNRawReplay(Base):
    __tablename__="cfn_raw_replays"
    id = Column(Integer, primary_key=True, autoincrement=True)
    cfn_replay_id = Column(String, ForeignKey('cfn_replays.id', ondelete='CASCADE'), nullable=False)
    frame = Column(Integer, nullable=False)
    round_timer = Column(Integer, nullable=False)
    round_number = Column(Integer, nullable=False)

    p0_hp_cap = Column(Float, nullable=False)
    p0_hp_cooldown = Column(Float, nullable=False)
    p0_absolute_range = Column(Float, nullable=False)
    p0_act_st = Column(Integer, nullable=False)
    p0_current_hp = Column(Float, nullable=False)
    p0_drive = Column(Float, nullable=False)
    p0_drive_cooldown = Column(Float, nullable=False)
    p0_input_data = Column(Integer, nullable=False)
    p0_input_side = Column(Integer, nullable=False)
    p0_mactionframe = Column(Integer, nullable=False)
    p0_mactionid = Column(Integer, nullable=False)
    p0_stance = Column(Integer, nullable=False)
    p0_posx = Column(Float, nullable=False)
    p0_posy = Column(Float, nullable=False)
    p0_super = Column(Float, nullable=False)
    p0_hitstun = Column(Integer, nullable=False)
    p0_blockstun = Column(Integer, nullable=False)

    p1_hp_cap = Column(Float, nullable=False)
    p1_hp_cooldown = Column(Float, nullable=False)
    p1_absolute_range = Column(Float, nullable=False)
    p1_act_st = Column(Integer, nullable=False)
    p1_current_hp = Column(Float, nullable=False)
    p1_drive = Column(Float, nullable=False)
    p1_drive_cooldown = Column(Float, nullable=False)
    p1_input_data = Column(Integer, nullable=False)
    p1_input_side = Column(Integer, nullable=False)
    p1_mactionframe = Column(Integer, nullable=False)
    p1_mactionid = Column(Integer, nullable=False)
    p1_stance = Column(Integer, nullable=False)
    p1_posx = Column(Float, nullable=False)
    p1_posy = Column(Float, nullable=False)
    p1_super = Column(Float, nullable=False)
    p1_hitstun = Column(Integer, nullable=False)
    p1_blockstun = Column(Integer, nullable=False)


class CFNReplay(Base):
    __tablename__ = "cfn_replays"
    id = Column(String, primary_key=True)
    player_0_id = Column(BigInteger, ForeignKey('cfn_users.id', ondelete='CASCADE'), nullable=False)
    player_1_id = Column(BigInteger, ForeignKey('cfn_users.id', ondelete='CASCADE'), nullable=False)
    player_0_character_id = Column(Integer, ForeignKey('sf6_characters.id', ondelete='CASCADE'), nullable=False)
    player_1_character_id = Column(Integer, ForeignKey('sf6_characters.id', ondelete='CASCADE'), nullable=False)
    player_one_input_type = Column(Integer, nullable=False)
    player_two_input_type = Column(Integer, nullable=False)
    replay_battle_type = Column(Integer, nullable=False)


class VideoReplayTiming(Base):
    __tablename__ = "video_replay_timings"
    id = Column(Integer, primary_key=True, autoincrement=True)
    cfn_replay_id = Column(String, ForeignKey('cfn_replays.id', ondelete='CASCADE'), nullable=False)
    round_number = Column(Integer, nullable=False)
    round_start_time_seconds = Column(Float, nullable=False)
    __table_args__ = (
        UniqueConstraint('cfn_replay_id', 'round_number', name='uix_cfn_replay_id_round_number_timing'),
    )


class YoutubeReplayVideo(Base):
    __tablename__ = "youtube_video_replay"
    id = Column(Integer, primary_key=True, autoincrement=True)
    youtube_video_id = Column(String, nullable=False, unique=True)
    cfn_replay_id = Column(String, ForeignKey('cfn_replays.id', ondelete='CASCADE'), nullable=False, unique=True)
    __table_args__ = (
        UniqueConstraint('cfn_replay_id', 'youtube_video_id', name='uix_youtube_video_replay_cfn_replay_id_youtube_video_id'),
    )


