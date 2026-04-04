from pydantic import BaseModel


class TranslationSchema(BaseModel):
    language_code: str
    name: str

    model_config = {"from_attributes": True}


class CuisineResponse(BaseModel):
    id: int
    continent: str
    country_code: str
    translations: list[TranslationSchema]

    model_config = {"from_attributes": True}


class CuisineCreateRequest(BaseModel):
    continent: str
    country_code: str
    translations: list[TranslationSchema]
