# PlateFlow 🌿

A modern meal planning app — Mealime competitor with multilingual support, metric/imperial system, admin panel, and store/delivery integration.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend API | Python · FastAPI · PostgreSQL · Redis |
| Mobile | Flutter (iOS + Android) · Riverpod |
| Admin Panel | React · Vite · Ant Design |
| Infrastructure | Docker Compose |

## Quick Start

```bash
# 1. Copy environment file
cp .env.example .env

# 2. Start all services
docker-compose up --build

# 3. Run database migrations (in another terminal)
docker-compose exec backend alembic upgrade head

# 4. Seed database
docker-compose exec backend python -m scripts.seed
```

| Service | URL |
|---------|-----|
| API | http://localhost:8000 |
| API Docs (Swagger) | http://localhost:8000/docs |
| Admin Panel | http://localhost:3000 |

**Default Admin:** `admin@plateflow.com` / `admin123`

## Project Structure

```
PlateFlow/
├── docker-compose.yml
├── .env.example
├── backend/              # FastAPI + PostgreSQL
│   ├── app/
│   │   ├── domains/      # auth, users, recipes, categories, cuisines, ...
│   │   ├── admin/        # admin API endpoints
│   │   ├── core/         # JWT, security, dependencies
│   │   └── middleware/   # i18n, rate limiting
│   ├── alembic/          # database migrations
│   └── scripts/seed.py   # seed data
├── admin/                # React + Ant Design admin panel
│   └── src/
│       ├── pages/        # Dashboard, Users, Recipes, Categories, ...
│       ├── api/          # API endpoints
│       └── contexts/     # Auth context
└── mobile/               # Flutter app
    └── lib/
        ├── core/         # router, theme, API client, localization
        └── features/     # auth, home, explore, recipe, meal_plan, ...
```

## Features

- 🌍 **Multilingual** — English + Bulgarian (extensible)
- 📏 **Metric/Imperial** — user preference, client-side conversion
- 🔍 **Smart Search** — by ingredients, cuisine, category, cook time
- 📅 **Meal Planning** — weekly calendar with breakfast/lunch/dinner/snack
- 🛒 **Shopping Lists** — auto-generated from meal plan
- ❤️ **Favorites** — save and revisit loved recipes
- 📊 **Admin Panel** — full CRUD for all entities, statistics dashboard
- 👥 **Admin Roles** — super_admin, content_manager, support
- 💳 **Subscription Plans** — Free / Trial / Premium (payment integration pending)
- 🚚 **Store Integration** — structure ready for delivery providers

## Development

### Backend only
```bash
cd backend
pip install -e ".[dev]"
uvicorn app.main:app --reload
```

### Admin panel only
```bash
cd admin
npm install
npm run dev
```

### Flutter mobile
```bash
cd mobile
flutter pub get
flutter run
```
