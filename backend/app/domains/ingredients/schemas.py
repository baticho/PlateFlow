from pydantic import BaseModel


class TranslationSchema(BaseModel):
    language_code: str
    name: str

    model_config = {"from_attributes": True}


class IngredientResponse(BaseModel):
    id: int
    default_unit: str
    category: str
    calories_per_100g: float | None
    protein_per_100g: float | None
    carbs_per_100g: float | None
    fat_per_100g: float | None
    translations: list[TranslationSchema]

    model_config = {"from_attributes": True}


class IngredientCreateRequest(BaseModel):
    default_unit: str = "g"
    category: str = "other"
    calories_per_100g: float | None = None
    protein_per_100g: float | None = None
    carbs_per_100g: float | None = None
    fat_per_100g: float | None = None
    translations: list[TranslationSchema]
