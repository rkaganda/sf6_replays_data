from db import db
from db.models import ActStName, Base, MActionName, SF6Character, StanceName
from db.db import engine
import os
import json
import sys

def create_tables():
    print("Creating tables...")
    Base.metadata.create_all(engine)
    print("Created tables.")


def populate_stances():
    print("Populating stances...")
    file_path = "data/enums/stance.json"
    stance_names = {}

    with open(file_path, "r") as file:
        stance_names = json.load(file)
        
    for stance_id, stance_name in stance_names.items():
        with (db.SessionMaker() as session):
            try:
                stance = session.query(StanceName).filter_by(
                    id=stance_id
                ).first()

                if not stance:
                    stance = StanceName(
                        id=stance_id,
                        name=stance_name
                    )
                    session.add(stance)
            except Exception as e:
                session.rollback()
                raise e
            session.commit()
    print("Done.")


def populate_act_sts():
    print("Populating act_st...")
    file_path = "data/enums/act_st.json"
    act_st_names = {}

    with open(file_path, "r") as file:
        act_st_names = json.load(file)
        
    for act_st_id, act_st_name in act_st_names.items():
        with (db.SessionMaker() as session):
            try:
                act_st = session.query(ActStName).filter_by(
                    id=act_st_id
                ).first()

                if not act_st:
                    act_st = ActStName(
                        id=act_st_id,
                        name=act_st_name
                    )
                    session.add(act_st)
            except Exception as e:
                session.rollback()
                raise e
            session.commit()
    print("Done.")


def populate_character_names():
    print("Populating mactions...")
    character_path = "data/enums/characters"

    characters_actions = []

    for filename in os.listdir(character_path):
        if filename.endswith("_mactions.json"):
            print(f"{filename}")
            filename_split = filename.split("_")
            character_name = filename_split[0]
            character_id = filename_split[1]
            filepath = os.path.join(character_path, filename)
            try:
                with open(filepath, "r") as file:
                    file_content = json.load(file)
                    characters_actions.append({
                        "name": character_name,
                        "id": character_id,
                        "names": file_content 
                    })
            except (json.JSONDecodeError, IOError) as e:
                print(f"Error processing file {filename}: {e}")
        with (db.SessionMaker() as session):
            try:
                for char_actions in characters_actions:
                    character = session.query(SF6Character).filter_by(
                        name=char_actions['name']
                    ).first()

                    if not character:
                        character =SF6Character(
                            name=char_actions['name'],
                            id=char_actions['id']
                        )
                        session.add(character)
                        session.flush()
                    
                    for maction_id, maction_name in char_actions['names'].items():
                        m_action = session.query(MActionName).filter_by(
                            m_action_id=int(maction_id),
                            character_id=character.id
                        ).first()

                        if not m_action:
                            m_action=MActionName(
                                m_action_id=int(maction_id),
                                character_id=character.id,
                                name=maction_name
                            )
                            session.add(m_action)
                session.commit()
            except Exception as e:
                session.rollback()
                raise e
    print("Done.")
                    

def main():
    options = ['create_tables', 'update_sf6_data']

    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == 'create_tables':
            create_tables()
        elif command == 'update_sf6_data':
            populate_stances()
            populate_act_sts()
            populate_character_names()
        else:
            print(f"Unknown option: {command}. Available options: {', '.join(options)}")
    else:
        print(f"Usage: python setup_db.py [ {' | '.join(options)} ]")


if __name__=="__main__":
    main()