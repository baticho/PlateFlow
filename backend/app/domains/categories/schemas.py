from pydantic import BaseModel


class TranslationSchema(BaseModel):
    language_code: str
    name: str

    model_config = {"from_attributes": True}


class CategoryResponse(BaseModel):
    id: int
    slug: str
    icon_url: str | None
    translations: list[TranslationSchema]

    model_config = {"from_attributes": True}


class CategoryCreateRequest(BaseModel):
    slug: str
    icon_url: str | None = None
    translations: list[TranslationSchema]


class CategoryUpdateRequest(BaseModel):
    slug: str | None = None
    icon_url: str | None = None
    translations: list[TranslationSchema] | None = None
