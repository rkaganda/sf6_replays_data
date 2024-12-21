import sqlalchemy
from dotenv import load_dotenv
import os 
from sqlalchemy.orm import sessionmaker

load_dotenv()

SF6_DB_PATH = os.getenv('SF6_DB_PATH')
SF6_DB_USERNAME = os.getenv('SF6_DB_USERNAME')
SF6_DB_PASSWORD = os.getenv('SF6_DB_PASSWORD')
SF6_DB_SCHEMA = os.getenv('SF6_DB_SCHEMA')

db_path = f"postgresql://{SF6_DB_USERNAME}:{SF6_DB_PASSWORD}@{SF6_DB_PATH}"

engine = sqlalchemy.create_engine(f"{db_path}", connect_args={'options': f'-csearch_path={SF6_DB_SCHEMA}'})
SessionMaker = sessionmaker(bind=engine)


