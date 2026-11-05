"""add households.invite_code

Revision ID: b8c9d0e1f2a3
Revises: a7b8c9d0e1f2
"""
import sqlalchemy as sa
from alembic import op

revision = "b8c9d0e1f2a3"
down_revision = "a7b8c9d0e1f2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("households", sa.Column("invite_code", sa.String(16), nullable=True))
    op.create_unique_constraint("uq_households_invite_code", "households", ["invite_code"])


def downgrade() -> None:
    op.drop_constraint("uq_households_invite_code", "households", type_="unique")
    op.drop_column("households", "invite_code")
