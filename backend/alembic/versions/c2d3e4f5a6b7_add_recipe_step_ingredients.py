"""per-step ingredient amounts (\"28 g parmesan\" shown under a step)

Revision ID: c2d3e4f5a6b7
Revises: b1c2d3e4f5a6
Create Date: 2026-11-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c2d3e4f5a6b7'
down_revision: Union[str, None] = 'b1c2d3e4f5a6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'recipe_step_ingredients',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('step_id', sa.Integer(), sa.ForeignKey('recipe_steps.id', ondelete='CASCADE'), nullable=False),
        sa.Column('recipe_ingredient_id', sa.Integer(),
                  sa.ForeignKey('recipe_ingredients.id', ondelete='CASCADE'), nullable=False),
        sa.Column('quantity', sa.Numeric(10, 3), nullable=False),
        sa.Column('unit', sa.String(20), nullable=False),
    )
    op.create_index('ix_recipe_step_ingredients_step_id', 'recipe_step_ingredients', ['step_id'])


def downgrade() -> None:
    op.drop_index('ix_recipe_step_ingredients_step_id', table_name='recipe_step_ingredients')
    op.drop_table('recipe_step_ingredients')
