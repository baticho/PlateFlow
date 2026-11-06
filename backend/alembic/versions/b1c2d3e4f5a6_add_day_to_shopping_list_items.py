"""add day_of_week to shopping list items (split the list by plan day)

Revision ID: b1c2d3e4f5a6
Revises: a9b8c7d6e5f4
Create Date: 2026-11-06 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b1c2d3e4f5a6'
down_revision: Union[str, None] = 'a9b8c7d6e5f4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 0 = Monday … 6 = Sunday of the list's week; NULL for rows added before this change
    op.add_column('shopping_list_items', sa.Column('day_of_week', sa.SmallInteger(), nullable=True))


def downgrade() -> None:
    op.drop_column('shopping_list_items', 'day_of_week')
