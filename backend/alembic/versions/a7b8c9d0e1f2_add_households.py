"""add households (family accounts)

Revision ID: a7b8c9d0e1f2
Revises: f1a2b3c4d5e6
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "a7b8c9d0e1f2"
down_revision = "f1a2b3c4d5e6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "households",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.add_column("users", sa.Column("household_id", sa.Integer(), nullable=True))
    op.create_foreign_key("fk_users_household_id", "users", "households", ["household_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_users_household_id", "users", ["household_id"])


def downgrade() -> None:
    op.drop_index("ix_users_household_id", table_name="users")
    op.drop_constraint("fk_users_household_id", "users", type_="foreignkey")
    op.drop_column("users", "household_id")
    op.drop_table("households")
