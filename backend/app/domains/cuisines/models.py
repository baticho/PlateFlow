import enum

from sqlalchemy import Enum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Continent(str, enum.Enum):
    EUROPE = "europe"
    ASIA = "asia"
    NORTH_AMERICA = "north_america"
    SOUTH_AMERICA = "south_america"
    AFRICA = "africa"
    OCEANIA = "oceania"


class Cuisine(Base):
    __tablename__ = "cuisines"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    continent: Mapped[Continent] = mapped_column(Enum(Continent), nullable=False)
    country_code: Mapped[str] = mapped_column(String(3), nullable=False)

    translations = relationship("CuisineTranslation", back_populates="cuisine", cascade="all, delete-orphan")
    recipes = relationship("Recipe", back_populates="cuisine")


class CuisineTranslation(Base):
    __tablename__ = "cuisine_translations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    cuisine_id: Mapped[int] = mapped_column(Integer, ForeignKey("cuisines.id", ondelete="CASCADE"), nullable=False)
    language_code: Mapped[str] = mapped_column(String(5), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)

    cuisine = relationship("Cuisine", back_populates="translations")
