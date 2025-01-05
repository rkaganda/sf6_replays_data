import os
from alembic.config import Config
from alembic.script import ScriptDirectory
from alembic.command import revision
import re

# get the absolute path to the current script's directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# use os.path.join to construct paths and normalize them
ALEMBIC_CONFIG_PATH = os.path.abspath(os.path.join(BASE_DIR, "../../alembic.ini"))
VIEWS_DIR = os.path.abspath(os.path.join(BASE_DIR, "../views"))
MIGRATIONS_DIR = os.path.abspath(os.path.join(BASE_DIR, "../../migrations/versions"))

def get_current_head():
    """fetch the current head revision from alembic."""
    alembic_cfg = Config(ALEMBIC_CONFIG_PATH)
    script = ScriptDirectory.from_config(alembic_cfg)
    return script.get_current_head()

def create_view_migration(view_name, sql_content):
    """
    automatically creates a new migration for a view, linking it to the latest migration.
    """
    # load alembic config
    alembic_cfg = Config(ALEMBIC_CONFIG_PATH)

    # get the latest head revision
    current_head = get_current_head()

    # generate a new migration file with the correct down_revision
    alembic_cfg.attributes['down_revision'] = current_head
    slug = f"view_{view_name}"
    revision_script = revision(alembic_cfg, slug, autogenerate=False)
    revision_id = revision_script.revision

    # write the migration file
    with open(revision_script.path, "w") as migration:
        migration.write(f'''from alembic import op

# revision identifiers, used by alembic.
revision = '{revision_id}'
down_revision = '{current_head}'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # create the view
    op.execute(\"\"\"{sql_content}\"\"\")

def downgrade() -> None:
    # drop the view
    op.execute("drop view if exists {view_name};")
''')
    print(f"Migration created: {revision_script.path}")

def main():
    if not os.path.exists(VIEWS_DIR):
        raise FileNotFoundError(f"Views directory not found: {VIEWS_DIR}")

    sql_files = [f for f in os.listdir(VIEWS_DIR) if f.endswith(".sql")]

    for sql_file in sql_files:
        view_name = os.path.splitext(sql_file)[0]
        with open(os.path.join(VIEWS_DIR, sql_file), "r") as f:
            sql_content = f.read()
            create_view_migration(view_name, sql_content)

if __name__ == "__main__":
    main()
