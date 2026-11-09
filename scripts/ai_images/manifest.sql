-- One JSON line per published recipe with a photo: id, English title, main ingredients, current image path.
-- Pantry staples (salt, pepper, oil, broth...) are dropped so the prompt names what you actually see.
select json_build_object(
  'id', r.id,
  'title', t.title,
  'image_url', r.image_url,
  'ingredients', (
    select string_agg(lower(it.name), ', ' order by ri.id)
    from recipe_ingredients ri
    join ingredient_translations it on it.ingredient_id = ri.ingredient_id and it.language_code = 'en'
    where ri.recipe_id = r.id
      and lower(it.name) !~ '(^salt$|black pepper|olive oil|vegetable oil|canola oil|^water$|broth|stock|^flour$|^sugar$|baking)'
  )
)
from recipes r
join recipe_translations t on t.recipe_id = r.id and t.language_code = 'en'
where r.image_url is not null and r.status::text ilike 'published'
order by r.id;
