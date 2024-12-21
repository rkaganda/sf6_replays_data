from db.models import Base
from db.db import engine

if __name__=="__main__":
    print("Creating tables...")
    Base.metadata.create_all(engine)
    print("Created tables.")