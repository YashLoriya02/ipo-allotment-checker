from __future__ import annotations

import os
import re

from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Optional

from playwright.sync_api import (
    TimeoutError as PlaywrightTimeoutError,
    sync_playwright,
)

from app.models import AllotmentStatus


KFIN_URL = "https://ipostatus.kfintech.com/"

HEADLESS = os.getenv(
    "KFIN_HEADLESS",
    "true",
).strip().lower() not in {
    "0",
    "false",
    "no",
}

DEBUG = os.getenv(
    "KFIN_DEBUG",
    "false",
).strip().lower() in {
    "1",
    "true",
    "yes",
}


@dataclass
class KfinResult:
    status: AllotmentStatus
    shares_allotted: Optional[int] = None
    application_number: Optional[str] = None
    message: Optional[str] = None


# ============================================================
# BASIC HELPERS
# ============================================================

def _clean_text(value: str) -> str:
    return re.sub(
        r"\s+",
        " ",
        value or "",
    ).strip()


def _redact_pan(
    text: str,
    pan: str,
) -> str:

    if not text:
        return text

    return text.replace(
        pan,
        "*****" + pan[-4:],
    )


# ============================================================
# IPO NAME MATCHING
# ============================================================

def _normalize_ipo_name(
    name: str,
) -> str:
    """
    Normalize IPO names from Upstox/KFin so minor naming
    differences don't prevent matching.

    Examples:

    Upstox:
        MILKY MIST DAIRY FOOD IPO

    KFin:
        MILKY MIST DAIRY FOOD LIMITED IPO

    or:

        ABC TECHNOLOGIES LTD.
        ABC TECHNOLOGIES LIMITED IPO
    """

    value = (name or "").upper().strip()

    # Standardize ampersands.
    value = value.replace(
        "&",
        " AND ",
    )

    # Remove punctuation.
    value = re.sub(
        r"[^A-Z0-9\s]",
        " ",
        value,
    )

    # Standardize LTD → LIMITED.
    value = re.sub(
        r"\bLTD\b",
        "LIMITED",
        value,
    )

    # IPO itself does not help identify the company.
    value = re.sub(
        r"\bIPO\b",
        " ",
        value,
    )

    # Collapse whitespace.
    value = re.sub(
        r"\s+",
        " ",
        value,
    )

    return value.strip()


def _find_best_ipo_option(
    options: list[str],
    requested_name: str,
) -> Optional[str]:
    """
    Match Upstox's IPO name against KFin dropdown names.

    Matching order:

    1. normalized exact match
    2. containment/includes
    3. conservative fuzzy match
    """

    requested = _normalize_ipo_name(
        requested_name
    )

    if not requested:
        return None

    normalized_options = [
        (
            original,
            _normalize_ipo_name(original),
        )
        for original in options
    ]

    # --------------------------------------------------------
    # 1. Normalized exact
    # --------------------------------------------------------

    for original, normalized in normalized_options:

        if normalized == requested:

            if DEBUG:
                print(
                    "IPO matched using "
                    "normalized exact match."
                )

            return original

    # --------------------------------------------------------
    # 2. Includes / containment
    # --------------------------------------------------------

    containment_matches: list[
        tuple[str, str]
    ] = []

    for original, normalized in normalized_options:

        if (
            requested in normalized
            or normalized in requested
        ):
            containment_matches.append(
                (original, normalized)
            )

    # If only one contains-match exists,
    # it is reasonably safe.
    if len(containment_matches) == 1:

        if DEBUG:
            print(
                "IPO matched using "
                "containment match."
            )

        return containment_matches[0][0]

    # If several options match by containment,
    # use the most similar one.
    if len(containment_matches) > 1:

        best_option = None
        best_score = 0.0

        for original, normalized in containment_matches:

            score = SequenceMatcher(
                None,
                requested,
                normalized,
            ).ratio()

            if score > best_score:
                best_score = score
                best_option = original

        if (
            best_option is not None
            and best_score >= 0.82
        ):

            if DEBUG:
                print(
                    "IPO matched using containment "
                    f"+ similarity: {best_score:.3f}"
                )

            return best_option

    # --------------------------------------------------------
    # 3. Conservative fuzzy match
    # --------------------------------------------------------

    best_option = None
    best_score = 0.0

    for original, normalized in normalized_options:

        if not normalized:
            continue

        score = SequenceMatcher(
            None,
            requested,
            normalized,
        ).ratio()

        if score > best_score:
            best_score = score
            best_option = original

    # Keep this threshold conservative so we don't
    # accidentally query the wrong IPO.
    if (
        best_option is not None
        and best_score >= 0.82
    ):

        if DEBUG:
            print(
                "IPO matched using fuzzy match: "
                f"{best_score:.3f}"
            )

        return best_option

    if DEBUG:
        print(
            "Unable to safely match IPO. "
            f"Best fuzzy score: {best_score:.3f}"
        )

    return None


# ============================================================
# RESULT EXTRACTION
# ============================================================

def _extract_int_after_labels(
    text: str,
    labels: list[str],
) -> Optional[int]:
    """
    Extract integer appearing after one of the supplied labels.

    Example:

        Allotted:
        107

    or:

        Shares Allotted: 107
    """

    for label in labels:

        pattern = (
            rf"{re.escape(label)}"
            rf"\s*[:\-]?\s*"
            rf"([0-9][0-9,]*)"
        )

        match = re.search(
            pattern,
            text,
            re.IGNORECASE,
        )

        if match:

            try:

                return int(
                    match.group(1).replace(
                        ",",
                        "",
                    )
                )

            except ValueError:
                continue

    return None


def _extract_application_number(
    text: str,
) -> Optional[str]:

    patterns = [
        (
            r"application\s*"
            r"(?:no|number|#)"
            r"\s*[:\-]?\s*"
            r"([A-Z0-9\/\-]+)"
        ),
        (
            r"application\s*id"
            r"\s*[:\-]?\s*"
            r"([A-Z0-9\/\-]+)"
        ),
    ]

    for pattern in patterns:

        match = re.search(
            pattern,
            text,
            re.IGNORECASE,
        )

        if match:
            return (
                match
                .group(1)
                .strip()
            )

    return None


# ============================================================
# KFIN RESULT PARSER
# ============================================================

def _parse_result(
    body_text: str,
    pan: str,
) -> KfinResult:

    safe_text = _redact_pan(
        body_text,
        pan,
    )

    text = _clean_text(
        safe_text
    )

    lower = text.lower()

    # ========================================================
    # HUMAN VERIFICATION
    # ========================================================

    human_phrases = (
        "captcha",
        "verify you are human",
        "human verification",
        "security verification",
    )

    if any(
        phrase in lower
        for phrase in human_phrases
    ):

        return KfinResult(
            status=AllotmentStatus.HUMAN_REQUIRED,
            message=(
                "KFin requires human verification."
            ),
        )

    # ========================================================
    # INVALID INPUT
    # ========================================================

    invalid_phrases = (
        "invalid pan",
        "please enter valid pan",
        "invalid input",
    )

    if any(
        phrase in lower
        for phrase in invalid_phrases
    ):

        return KfinResult(
            status=AllotmentStatus.UNKNOWN,
            message=(
                "KFin rejected the submitted "
                "PAN or input."
            ),
        )

    # ========================================================
    # NO RECORD FOUND
    # ========================================================

    no_record_phrases = (
        "your allotment status was not found",
        "allotment status was not found",
        "allotment status not found",
    )

    if any(
        phrase in lower
        for phrase in no_record_phrases
    ):

        return KfinResult(
            status=AllotmentStatus.NO_RECORD,
            message=(
                "No allotment record was found "
                "for this PAN and IPO."
            ),
        )

    # ========================================================
    # RESULT NOT LIVE
    # ========================================================

    not_live_phrases = (
        "allotment status is not available",
        "allotment details are not available",
        "allotment not available",
        "result not available",
        "data not found",
        "no data found",
        "details not found",
    )

    if any(
        phrase in lower
        for phrase in not_live_phrases
    ):

        return KfinResult(
            status=AllotmentStatus.NOT_LIVE,
            message=(
                "Allotment result is "
                "not available yet."
            ),
        )

    # ========================================================
    # APPLICATION NUMBER
    # ========================================================

    application_number = (
        _extract_application_number(
            text
        )
    )

    # ========================================================
    # SHARES ALLOTTED
    # ========================================================

    shares = _extract_int_after_labels(
        text,
        [
            # Actual current KFin format:
            "Allotted",

            # Additional known/possible formats:
            "Shares Allotted",
            "Share Allotted",
            "Allotted Shares",
            "Allotted Quantity",
            "Allotment Quantity",
            "Qty Allotted",
            "Quantity Allotted",
            "Securities Allotted",
            "No. of Shares Allotted",
            "Number of Shares Allotted",
        ],
    )

    if DEBUG:
        print(
            f"Parsed application number: "
            f"{application_number}"
        )
        print(
            f"Parsed allotted shares: "
            f"{shares}"
        )

    # ========================================================
    # EXPLICIT NEGATIVE RESULT
    # ========================================================

    negative_phrases = (
        "not allotted",
        "not been allotted",
        "no shares allotted",
        "no allotment",
        "unsuccessful",
    )

    if any(
        phrase in lower
        for phrase in negative_phrases
    ):

        return KfinResult(
            status=(
                AllotmentStatus.NOT_ALLOTTED
            ),
            shares_allotted=0,
            application_number=(
                application_number
            ),
            message=(
                "No shares were allotted."
            ),
        )

    # ========================================================
    # ZERO ALLOTMENT
    # ========================================================

    if shares == 0:

        return KfinResult(
            status=(
                AllotmentStatus.NOT_ALLOTTED
            ),
            shares_allotted=0,
            application_number=(
                application_number
            ),
            message=(
                "No shares were allotted."
            ),
        )

    # ========================================================
    # POSITIVE ALLOTMENT
    # ========================================================

    if (
        shares is not None
        and shares > 0
    ):

        return KfinResult(
            status=AllotmentStatus.ALLOTTED,
            shares_allotted=shares,
            application_number=(
                application_number
            ),
            message=(
                "Shares allotted successfully."
            ),
        )

    # ========================================================
    # TEXTUAL ALLOTTED FALLBACK
    # ========================================================

    positive_phrases = (
        "shares have been allotted",
        "shares allotted",
        "allotment successful",
        "allotted successfully",
    )

    if any(
        phrase in lower
        for phrase in positive_phrases
    ):

        return KfinResult(
            status=AllotmentStatus.ALLOTTED,
            shares_allotted=shares,
            application_number=(
                application_number
            ),
            message="Allotment found.",
        )

    # ========================================================
    # UNKNOWN
    # ========================================================

    return KfinResult(
        status=AllotmentStatus.UNKNOWN,
        application_number=(
            application_number
        ),
        message=(
            "KFin returned a result page, "
            "but its status could not be "
            "parsed confidently."
        ),
    )


# ============================================================
# MAIN KFIN CHECKER
# ============================================================

def check_kfin(
    ipo_name: str,
    pan: str,
) -> KfinResult:

    browser = None

    try:

        with sync_playwright() as p:

            if DEBUG:
                print(
                    "1. Starting Chromium..."
                )

            browser = p.chromium.launch(
                headless=HEADLESS,
            )

            page = browser.new_page(
                viewport={
                    "width": 1400,
                    "height": 900,
                },
            )

            # =================================================
            # OPEN KFIN
            # =================================================

            if DEBUG:
                print(
                    "2. Opening KFin..."
                )

            page.goto(
                KFIN_URL,
                wait_until="domcontentloaded",
                timeout=30_000,
            )

            # =================================================
            # OPEN IPO DROPDOWN
            # =================================================

            dropdown = page.locator(
                "#demo-multiple-name"
            )

            dropdown.wait_for(
                state="visible",
                timeout=30_000,
            )

            dropdown.click()

            option_locator = (
                page.get_by_role("option")
            )

            option_locator.first.wait_for(
                state="visible",
                timeout=10_000,
            )

            # =================================================
            # READ IPO OPTIONS
            # =================================================

            option_names = (
                option_locator
                .all_inner_texts()
            )

            if DEBUG:

                print(
                    f"3. KFin has "
                    f"{len(option_names)} IPO options."
                )

                print(
                    f"Requested IPO: {ipo_name}"
                )

            # =================================================
            # MATCH IPO
            # =================================================

            selected_option = (
                _find_best_ipo_option(
                    option_names,
                    ipo_name,
                )
            )

            if selected_option is None:

                if DEBUG:
                    print(
                        "No suitable IPO match found."
                    )

                return KfinResult(
                    status=(
                        AllotmentStatus.NOT_LIVE
                    ),
                    message=(
                        "Could not match this IPO "
                        "with KFin's available IPO list."
                    ),
                )

            if DEBUG:

                print(
                    f"Matched KFin IPO: "
                    f"{selected_option}"
                )

            # =================================================
            # CLICK MATCHED IPO
            # =================================================

            page.get_by_role(
                "option",
                name=selected_option,
                exact=True,
            ).click()

            # =================================================
            # SELECT PAN
            # =================================================

            page.locator(
                'input[type="radio"][value="PAN"]'
            ).check()

            # =================================================
            # ENTER PAN
            # =================================================

            pan_input = page.locator(
                "#outlined-start-adornment"
            )

            pan_input.fill(
                pan
            )

            # Keep the state before submit so
            # we can detect React's result update.
            before_submit_text = (
                page
                .locator("body")
                .inner_text()
            )

            # =================================================
            # SUBMIT
            # =================================================

            if DEBUG:
                print(
                    "4. Submitting..."
                )

            page.get_by_role(
                "button",
                name="Submit",
                exact=True,
            ).click()

            loading_text = (
                "Please wait we are fetching "
                "your allotment status..."
            )

            # =================================================
            # WAIT FOR LOADER
            # =================================================

            try:

                page.get_by_text(
                    loading_text,
                    exact=False,
                ).wait_for(
                    state="visible",
                    timeout=5_000,
                )

                if DEBUG:
                    print(
                        "5. KFin loading "
                        "state detected..."
                    )

            except PlaywrightTimeoutError:

                # It may have loaded too fast
                # to observe the loader.
                if DEBUG:
                    print(
                        "5. Loader did not appear "
                        "or disappeared quickly."
                    )

            # =================================================
            # WAIT FOR FINAL RESULT
            # =================================================

            if DEBUG:
                print(
                    "6. Waiting for "
                    "allotment result..."
                )

            try:

                page.wait_for_function(
                    """
                    ([beforeText, loadingText]) => {

                        const bodyText =
                            document.body.innerText || '';

                        const changed =
                            bodyText.trim() !==
                            beforeText.trim();

                        const stillLoading =
                            bodyText.includes(
                                loadingText
                            );

                        return (
                            changed &&
                            !stillLoading
                        );
                    }
                    """,
                    arg=[
                        before_submit_text,
                        loading_text,
                    ],
                    timeout=30_000,
                )

            except PlaywrightTimeoutError:

                return KfinResult(
                    status=(
                        AllotmentStatus
                        .TEMPORARY_ERROR
                    ),
                    message=(
                        "KFin is taking too long "
                        "to return the allotment result."
                    ),
                )

            # Tiny render buffer.
            page.wait_for_timeout(
                500
            )

            # =================================================
            # READ RESULT
            # =================================================

            body_text = (
                page
                .locator("body")
                .inner_text()
            )

            # Defensive check.
            if (
                loading_text.lower()
                in body_text.lower()
            ):

                return KfinResult(
                    status=(
                        AllotmentStatus
                        .TEMPORARY_ERROR
                    ),
                    message=(
                        "KFin is still processing "
                        "the allotment request."
                    ),
                )

            # =================================================
            # DEBUG RESULT
            # =================================================

            if DEBUG:

                safe_body_text = (
                    _redact_pan(
                        body_text,
                        pan,
                    )
                )

                print(
                    "\n"
                    "========== "
                    "KFIN RESULT TEXT "
                    "=========="
                )

                print(
                    safe_body_text
                )

                print(
                    "=============================="
                    "============\n"
                )

            # =================================================
            # PARSE RESULT
            # =================================================

            return _parse_result(
                body_text,
                pan,
            )

    # ========================================================
    # PLAYWRIGHT TIMEOUT
    # ========================================================

    except PlaywrightTimeoutError:

        return KfinResult(
            status=(
                AllotmentStatus.TEMPORARY_ERROR
            ),
            message=(
                "KFin took too long to respond."
            ),
        )

    # ========================================================
    # GENERIC ERROR
    # ========================================================

    except Exception as e:

        if DEBUG:

            import traceback

            print(
                "\n"
                "========== KFIN ERROR "
                "=========="
            )

            print(
                f"Type: "
                f"{type(e).__name__}"
            )

            print(
                f"Error: {e}"
            )

            traceback.print_exc()

            print(
                "=============================="
                "==\n"
            )

        # Never expose raw Playwright errors or
        # potentially sensitive request information.
        return KfinResult(
            status=(
                AllotmentStatus.TEMPORARY_ERROR
            ),
            message=(
                "KFin could not be "
                "checked right now."
            ),
        )

    # ========================================================
    # CLEANUP
    # ========================================================

    finally:

        if browser is not None:

            try:
                browser.close()

            except Exception:
                pass