"""add google oauth to users

Revision ID: c3d4e5f6a7b8
Revises: a1b2c3d4e5f6
Create Date: 2026-04-09 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('google_oauth_id', sa.String(255), nullable=True),
    )
    op.create_unique_constraint('uq_users_google_oauth_id', 'users', ['google_oauth_id'])
    op.create_index('ix_users_google_oauth_id', 'users', ['google_oauth_id'])
    op.alter_column('users', 'password_hash', nullable=True)


def downgrade() -> None:
    op.alter_column('users', 'password_hash', nullable=False)
    op.drop_index('ix_users_google_oauth_id', 'users')
    op.drop_constraint('uq_users_google_oauth_id', 'users', type_='unique')
    op.drop_column('users', 'google_oauth_id')
