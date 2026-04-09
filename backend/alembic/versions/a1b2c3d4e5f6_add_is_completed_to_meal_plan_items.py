"""add is_completed to meal_plan_items

Revision ID: a1b2c3d4e5f6
Revises: 77c04ec41c3d
Create Date: 2026-04-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '77c04ec41c3d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'meal_plan_items',
        sa.Column('is_completed', sa.Boolean(), server_default='false', nullable=False),
    )


def downgrade() -> None:
    op.drop_column('meal_plan_items', 'is_completed')
