from contextvars import ContextVar

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

SUPPORTED_LANGUAGES = {"en", "bg"}
DEFAULT_LANGUAGE = "en"

current_language: ContextVar[str] = ContextVar("current_language", default=DEFAULT_LANGUAGE)


class I18nMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        accept_language = request.headers.get("Accept-Language", DEFAULT_LANGUAGE)
        lang = self._parse_language(accept_language)
        token = current_language.set(lang)
        try:
            response = await call_next(request)
            response.headers["Content-Language"] = lang
            return response
        finally:
            current_language.reset(token)

    def _parse_language(self, header: str) -> str:
        for part in header.split(","):
            lang = part.split(";")[0].strip().lower()
            if lang in SUPPORTED_LANGUAGES:
                return lang
            lang_prefix = lang.split("-")[0]
            if lang_prefix in SUPPORTED_LANGUAGES:
                return lang_prefix
        return DEFAULT_LANGUAGE
