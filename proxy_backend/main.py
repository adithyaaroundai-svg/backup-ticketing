"""FastAPI proxy for the TARS /ask endpoint.

This proxy enforces the strict response contract expected by the Flutter
frontend while remaining transparent to the upstream AI service.
"""
from __future__ import annotations

import json
import os
import re
from enum import Enum
from typing import Dict, List, Optional, Sequence, TypedDict

import httpx
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

UPSTREAM_ASK_URL = os.getenv("UPSTREAM_ASK_URL", "https://tars-jdno.onrender.com/ask")
HTTP_TIMEOUT_SECONDS = float(os.getenv("UPSTREAM_TIMEOUT_SECONDS", "90"))
MANUAL_PATH = os.getenv(
    "TALLY_MANUAL_PATH",
    os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "tally_manual.json")),
)
MANUAL_MAX_SNIPPET_CHARS = 1800
ESCALATION_MESSAGE = (
    "This issue needs review by a support executive to ensure it’s resolved correctly. "
    "I’ve noted this under your ticket, and our support team will assist you shortly."
)
REQUIRED_SECTION_HEADERS = [
    "Issue Acknowledgement:",
    "Clarifying Question:",
    "Solution:",
]
CUSTOMER_ISSUE_PATTERN = re.compile(r"Customer issue:\s*(.+)", re.IGNORECASE | re.DOTALL)
DEFAULT_ISSUE_SUMMARY = "your issue"
SYSTEM_KEYWORDS = {
    "not opening",
    "won't open",
    "wont open",
    "unable to start",
    "startup",
    "crash",
    "crashing",
    "freezing",
    "freeze",
    "license",
    "licence",
    "activation",
    "blank screen",
    "install",
    "installation",
    "system",
    "login",
    "password",
    "error",
    "500",
    "access",
    "slow",
}
FUNCTIONAL_KEYWORDS = {
    "invoice",
    "gst",
    "tax",
    "ledger",
    "report",
    "reconcile",
    "recon",
    "stock",
    "inventory",
    "discount",
    "entry",
    "voucher",
    "sales",
    "purchase",
    "bill",
    "receipt",
    "bank",
    "import",
    "export",
    "screen",
    "flicker",
    "flickering",
    "display",
    "button",
}


class ManualSnippet(TypedDict):
    title: str
    learning: str
    score: int


class IssueCategory(str, Enum):
    """High-level issue types used to steer deterministic responses."""

    FUNCTIONAL = "KNOWN_TALLY_FUNCTIONAL"
    SYSTEM = "SYSTEM_OR_ENVIRONMENT"
    UNKNOWN = "UNKNOWN_OR_INSUFFICIENT"


class ScreenContext(BaseModel):
    screen_name: Optional[str] = Field(default=None, alias="screen_name")
    active_field: Optional[str] = Field(default=None, alias="active_field")
    field_values: Dict[str, str] = Field(default_factory=dict, alias="field_values")

    class Config:
        populate_by_name = True


class AskRequest(BaseModel):
    context: Optional[ScreenContext] = None
    question: str
    persona_prompt: Optional[str] = Field(default=None, alias="persona_prompt")
    image_base64: Optional[str] = Field(default=None, alias="image_base64")

    class Config:
        populate_by_name = True


class AskResponse(BaseModel):
    answer: str

    class Config:
        extra = "allow"


app = FastAPI(title="TARS Structured Proxy", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/ask", response_model=AskResponse)
async def proxy_ask(payload: AskRequest) -> AskResponse:
    """Proxy the /ask call while enforcing structured responses."""

    issue_text = extract_issue_text(payload)
    manual_context = search_manual_snippet(issue_text)
    try:
        upstream_answer = await fetch_upstream_answer(payload, manual_context)
    except httpx.ReadTimeout as exc:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="The AI is taking longer than expected to respond. Please try again shortly.",
        ) from exc
    except httpx.HTTPStatusError as exc:
        response = exc.response
        if response is not None and response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Upstream could not process the question: {response.text}",
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=(
                f"Upstream error {response.status_code if response else 'unknown'}: "
                f"{response.text if response else exc}"
            ),
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Upstream request failed: {exc}",
        ) from exc
    normalized_answer = normalize_response(issue_text, upstream_answer, manual_context)
    return AskResponse(answer=normalized_answer)


async def fetch_upstream_answer(payload: AskRequest, manual_context: Optional[ManualSnippet]) -> str:
    """Call the upstream AI service and extract the answer string."""

    upstream_payload = {
        "question": _attach_manual_context(payload.question, manual_context),
    }
    if payload.image_base64:
        upstream_payload["image"] = payload.image_base64

    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT_SECONDS) as client:
        response = await client.post(
            UPSTREAM_ASK_URL,
            json=upstream_payload,
        )
    print("Upstream payload:", upstream_payload)
    print("Upstream status:", response.status_code)
    response.raise_for_status()

    try:
        data = response.json()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Upstream response was not valid JSON.",
        ) from exc

    answer = data.get("answer")
    if not isinstance(answer, str) or not answer.strip():
        # Fall back to an empty string so the normalizer rebuilds the response.
        return ""
    return answer.strip()


def extract_issue_text(payload: AskRequest) -> str:
    """Heuristically pull the customer's issue text from the request payload."""

    def _issue_from_source(source: Optional[str]) -> Optional[str]:
        if not source:
            return None
        match = CUSTOMER_ISSUE_PATTERN.search(source)
        if match:
            candidate = match.group(1).strip()
            if candidate:
                return sanitize_issue(candidate)
        return None

    # Prefer explicit "Customer issue:" hints from either the wrapped question or persona prompt.
    issue = _issue_from_source(payload.question) or _issue_from_source(payload.persona_prompt)
    if issue:
        return issue

    # If persona_prompt itself is short, treat it as the issue description.
    if payload.persona_prompt:
        sanitized_persona = sanitize_issue(payload.persona_prompt)
        if sanitized_persona and len(sanitized_persona.split()) <= 16:
            return sanitized_persona

    # Fall back to any user-facing context the UI might have sent along.
    if payload.context and payload.context.field_values:
        for key in ("issue", "title", "description", "problem", "summary"):
            value = payload.context.field_values.get(key)
            if value:
                return sanitize_issue(value)

    return DEFAULT_ISSUE_SUMMARY


def sanitize_issue(issue: str) -> str:
    """Clean up noisy whitespace and trailing punctuation."""

    compact = re.sub(r"\s+", " ", issue).strip()
    return compact.rstrip(" :") or DEFAULT_ISSUE_SUMMARY


def normalize_response(
    issue_text: str,
    raw_answer: str,
    manual_context: Optional[ManualSnippet],
) -> str:
    """Ensure the answer conforms to the mandatory section contract."""

    answer = (raw_answer or "").strip()
    if answer and has_required_sections(answer) and sections_non_empty(answer):
        return answer

    category = classify_issue(issue_text)
    builders = {
        IssueCategory.SYSTEM: _build_system_response,
        IssueCategory.FUNCTIONAL: _build_functional_response,
        IssueCategory.UNKNOWN: _build_unknown_response,
    }
    builder = builders.get(category, _build_unknown_response)
    return _append_manual_reference(builder(issue_text), manual_context)


def has_required_sections(answer: str) -> bool:
    """Check whether all required headings exist in the payload."""

    return all(section in answer for section in REQUIRED_SECTION_HEADERS)


def sections_non_empty(answer: str) -> bool:
    """Verify every mandatory section has non-empty content."""

    lowered_answer = answer
    for index, section in enumerate(REQUIRED_SECTION_HEADERS):
        start = lowered_answer.find(section)
        if start == -1:
            return False
        start += len(section)
        end_candidates: List[int] = []
        for next_section in REQUIRED_SECTION_HEADERS[index + 1 :]:
            next_pos = lowered_answer.find(next_section, start)
            if next_pos != -1:
                end_candidates.append(next_pos)
        end = min(end_candidates) if end_candidates else len(lowered_answer)
        content = lowered_answer[start:end].strip()
        if not content:
            return False
    return True


def classify_issue(issue_text: str) -> IssueCategory:
    """Rough classification used to steer the normalized template."""

    normalized = issue_text.lower()
    if not normalized or len(normalized) < 12:
        return IssueCategory.UNKNOWN

    if any(keyword in normalized for keyword in SYSTEM_KEYWORDS):
        return IssueCategory.SYSTEM

    if any(keyword in normalized for keyword in FUNCTIONAL_KEYWORDS):
        return IssueCategory.FUNCTIONAL

    return IssueCategory.UNKNOWN


def _build_functional_response(issue_text: str) -> str:
    """Structured reply for functional issues grounded in the reported context."""

    issue_summary = issue_text or "the issue you reported"
    acknowledgement = (
        "Issue Acknowledgement:\n"
        f"• I understand you're facing an issue with {issue_summary} and need functional guidance."
    )
    clarifying = (
        "Clarifying Question:\n"
        f"• When {issue_summary} shows up, does it happen while:\n"
        f"  A) You're entering or saving the data that leads to {issue_summary}\n"
        f"  B) You're reviewing, exporting, or sharing an existing record/report affected by {issue_summary}"
    )
    solution = (
        "Solution:\n"
        "If A):\n"
        f"- Step 1: Re-open the exact form that led to {issue_summary} and validate every ledger, stock item, and tax field.\n"
        "- Step 2: Remove any highlighted rows, re-enter the values slowly, and confirm numbering/rounding rules.\n"
        "- Step 3: Save again and capture any precise error wording so I can escalate if it repeats.\n\n"
        "If B):\n"
        f"- Step 1: Open the saved document/report tied to {issue_summary} and confirm totals and filters look correct.\n"
        "- Step 2: Export to PDF first; if the export works but print/email fails, reset the print/report profile.\n"
        "- Step 3: Refresh or re-sync data and grab the exact error so we can trace it further."
    )
    return "\n\n".join([acknowledgement, clarifying, solution]).strip()


# ---------------------------------------------------------------------------
# Tally manual ingestion utilities
# ---------------------------------------------------------------------------
MANUAL_DATA: Dict[str, Sequence[Dict[str, str]]] = {"tutorials": []}


def _load_manual_data() -> None:
    global MANUAL_DATA
    if not MANUAL_PATH:
        return
    try:
        with open(MANUAL_PATH, "r", encoding="utf-8") as manual_file:
            parsed = json.load(manual_file)
        if isinstance(parsed, dict) and "tutorials" in parsed:
            MANUAL_DATA = parsed
            print(f"[manual] Loaded {len(parsed.get('tutorials', []))} tutorials from {MANUAL_PATH}")
    except FileNotFoundError:
        print(f"[manual] File not found at {MANUAL_PATH}. Skipping manual grounding.")
    except Exception as exc:  # pragma: no cover - defensive logging
        print(f"[manual] Failed to load manual: {exc}")


def search_manual_snippet(query: Optional[str]) -> Optional[ManualSnippet]:
    if not query:
        return None

    tutorials = MANUAL_DATA.get("tutorials", [])
    if not tutorials:
        return None

    normalized = query.lower().strip()
    if len(normalized) < 4:
        return None
    terms = [term for term in re.split(r"[\\s,./]+", normalized) if len(term) > 2]
    if not terms:
        return None

    best: Optional[Dict[str, str]] = None
    best_score = 0
    best_term = ""

    for tutorial in tutorials:
        title = tutorial.get("title", "")
        learning = tutorial.get("learning", "")
        if not learning:
            continue
        score = 0
        matched_term = ""
        lowered_title = title.lower()
        lowered_learning = learning.lower()

        for term in terms:
            if term in lowered_title:
                score += 6
                matched_term = term
            if term in lowered_learning:
                score += 1
                if not matched_term:
                    matched_term = term

        if score > best_score:
            best_score = score
            best = tutorial
            best_term = matched_term

    if not best or best_score <= 0:
        return None

    snippet = _trim_manual_snippet(best.get("learning", ""), best_term)
    if not snippet:
        return None

    return ManualSnippet(
        title=best.get("title", "Tally Manual"),
        learning=snippet,
        score=best_score,
    )


def _trim_manual_snippet(text: str, term: str) -> str:
    cleaned = text.strip()
    if not cleaned:
        return ""
    if len(cleaned) <= MANUAL_MAX_SNIPPET_CHARS:
        return cleaned

    focus = cleaned.lower()
    if term:
        idx = focus.find(term.lower())
    else:
        idx = len(cleaned) // 2
    if idx == -1:
        idx = len(cleaned) // 2

    half_window = MANUAL_MAX_SNIPPET_CHARS // 2
    start = max(0, idx - half_window)
    end = min(len(cleaned), start + MANUAL_MAX_SNIPPET_CHARS)
    snippet = cleaned[start:end]
    if start > 0:
        snippet = "..." + snippet
    if end < len(cleaned):
        snippet = snippet + "..."
    return snippet


def _attach_manual_context(question: str, manual_context: Optional[ManualSnippet]) -> str:
    if not manual_context:
        return question
    question = (question or "").rstrip()
    snippet = manual_context["learning"].strip()
    if not snippet:
        return question
    title = manual_context["title"]
    return (
        f"{question}\n\n"
        "---\n"
        "You also have access to the following verified knowledge from the official Tally manual.\n"
        f"Title: {title}\n"
        f"Excerpt:\n{snippet}\n"
        "---\n"
        "Ground every factual statement in this knowledge excerpt when it is relevant, and prefer escalation if the excerpt does not answer the question."
    )


_load_manual_data()


def _append_manual_reference(answer: str, manual_context: Optional[ManualSnippet]) -> str:
    if not manual_context:
        return answer
    snippet = manual_context["learning"].strip()
    if not snippet:
        return answer
    title = manual_context["title"]
    reference = (
        "\n\n"
        "Reference Knowledge:\n"
        f"• Source: {title}\n"
        f"{snippet}"
    )
    return f"{answer.rstrip()}{reference}"


def _build_system_response(issue_text: str) -> str:
    """Structured reply for environment/system issues."""

    issue_summary = issue_text or "the issue you reported"
    acknowledgement = (
        "Issue Acknowledgement:\n"
        f"• I understand you're facing an issue with {issue_summary}, which points to a system or environment concern."
    )
    clarifying = (
        "Clarifying Question:\n"
        f"• When {issue_summary} happens, which scenario matches best?\n"
        f"  A) Tally never launches or stays stuck/blank while you're dealing with {issue_summary}\n"
        f"  B) Tally opens but immediately throws an error, freezes, or forces a login failure around {issue_summary}"
    )
    solution = (
        "Solution:\n"
        "If A):\n"
        f"- Step 1: Close Tally, restart Windows, and try launching again to rule out a locked session behind {issue_summary}.\n"
        "- Step 2: Attempt opening in educational mode; if that also fails, the installation or license needs inspection.\n"
        f"- Step 3: {ESCALATION_MESSAGE}\n\n"
        "If B):\n"
        f"- Step 1: Capture the exact error, login prompt, or crash message shown during {issue_summary}.\n"
        "- Step 2: Avoid repeated retries so the current logs remain intact for diagnosis.\n"
        f"- Step 3: {ESCALATION_MESSAGE}"
    )
    return "\n\n".join([acknowledgement, clarifying, solution]).strip()


def _build_unknown_response(issue_text: str) -> str:
    """Fallback structured reply when details are insufficient."""

    issue_summary = issue_text or "the issue you reported"
    acknowledgement = (
        "Issue Acknowledgement:\n"
        f"• I understand you're seeing {issue_summary}, but the details are limited."
    )
    clarifying = (
        "Clarifying Question:\n"
        f"• To help with {issue_summary}, could you clarify whether:\n"
        "  A) A specific in-app action immediately triggers it\n"
        "  B) The issue appears intermittently and you’re unsure what led to it"
    )
    solution = (
        "Solution:\n"
        "If A):\n"
        "- Step 1: Share any on-screen error text or recent configuration/data changes before the issue occurred.\n"
        "- Step 2: Reproduce it once more, noting the exact menu path so I can replicate.\n"
        f"- Step 3: {ESCALATION_MESSAGE}\n\n"
        "If B):\n"
        "- Step 1: Provide the ticket ID plus what you’ve already tried so we don’t repeat steps.\n"
        "- Step 2: Let me know if this blocks daily work so we can prioritize escalation.\n"
        f"- Step 3: {ESCALATION_MESSAGE}"
    )
    return "\n\n".join([acknowledgement, clarifying, solution]).strip()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "proxy_backend.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        reload=os.getenv("ENV", "development") == "development",
    )
