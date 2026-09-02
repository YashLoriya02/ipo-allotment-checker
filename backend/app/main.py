from fastapi import FastAPI

from app.models import AllotmentCheckRequest, AllotmentCheckResponse, AllotmentStatus
from app.registrars.kfin import check_kfin

app = FastAPI(
    title="IPO Allotment Checker API",
    version="1.0.0",
    description="Stateless registrar allotment-checking API.",
)


@app.get("/health")
def health():
    return {"status": "ok", "service": "ipo-allotment-checker"}


@app.post("/v1/allotment/check", response_model=AllotmentCheckResponse)
def check_allotment(payload: AllotmentCheckRequest) -> AllotmentCheckResponse:
    registrar = payload.registrar.upper()

    if registrar not in {"KFIN", "KFINTECH", "K FINTECH", "KFIN TECHNOLOGIES", "KFIN TECHNOLOGIES LIMITED"}:
        return AllotmentCheckResponse(
            status=AllotmentStatus.UNSUPPORTED_REGISTRAR,
            registrar=registrar,
            ipoName=payload.ipoName,
            message=f"Registrar '{registrar}' is not supported yet.",
        )

    result = check_kfin(ipo_name=payload.ipoName, pan=payload.pan)

    return AllotmentCheckResponse(
        status=result.status,
        registrar="KFIN",
        ipoName=payload.ipoName,
        sharesAllotted=result.shares_allotted,
        applicationNumber=result.application_number,
        message=result.message,
    )
