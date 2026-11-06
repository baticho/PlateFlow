"""add nutrition per serving to recipes

Revision ID: a9b8c7d6e5f4
Revises: b8c9d0e1f2a3
Create Date: 2026-11-06 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a9b8c7d6e5f4'
down_revision: Union[str, None] = 'b8c9d0e1f2a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

COLUMNS = ('calories', 'protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'saturated_fat_g', 'sodium_mg')


def upgrade() -> None:
    for name in COLUMNS:
        op.add_column('recipes', sa.Column(name, sa.Numeric(8, 2), nullable=True))


def downgrade() -> None:
    for name in COLUMNS:
        op.drop_column('recipes', name)
