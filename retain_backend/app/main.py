from app.schemas import ShapContribution
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.database import Base, SessionLocal, engine, get_db, ping_database
from app.model_service import model_service
from app.models_db import ChurnLog, Customer, RetentionAction
from app.schemas import (
    AdaptiveScenariosResponse,
    ChurnAlert,
    ChurnAlertsResponse,
    HealthResponse,
    PredictResponse,
    RetentionActionCreate,
    RetentionActionItem,
    RetentionActionsResponse,
    RetentionActionUpdate,
    RetentionStats,
    ShapContribution,
    ShapExplainResponse,
    SimulateRequest,
    SimulateResponse,
)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    Base.metadata.create_all(bind=engine)
    model_service.load()
    should_seed = False
    with SessionLocal() as db:
        should_seed = db.query(Customer).first() is None
    if should_seed:
        try:
            from training.seed_db import seed

            seed(drop_existing=False)
        except Exception as e:
            print(f"Auto-seed notification: {e}")

    # Seed sample actions if empty
    with SessionLocal() as db:
        if db.query(RetentionAction).first() is None:
            sample_custs = db.query(Customer).limit(4).all()
            if sample_custs:
                actions = [
                    RetentionAction(
                        customer_id=sample_custs[0].customer_id,
                        action_type="UPGRADE_CONTRACT",
                        title="Tawarkan Kontrak 1 Tahun + Diskon 15%",
                        status="PENDING",
                        note="Prioritas tinggi: Churn risk 86%. Tawarkan via WA.",
                    ),
                    RetentionAction(
                        customer_id=sample_custs[1].customer_id,
                        action_type="SWITCH_AUTODEBIT",
                        title="Alihkan ke Pembayaran Autodebit Bank",
                        status="IN_PROGRESS",
                        note="Customer berminat, menunggu verifikasi rekening bank.",
                    ),
                    RetentionAction(
                        customer_id=sample_custs[2].customer_id,
                        action_type="CALL_FOLLOWUP",
                        title="Telepon Courtesy Call & Cek Kepuasan Layanan",
                        status="RESOLVED",
                        note="Sudah dihubungi: Pelanggan puas setelah dibantu optimasi router wifi.",
                    ),
                ]
                db.add_all(actions)
                db.commit()
    yield





app = FastAPI(title="Retain", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
def health_check():
    ping_database()
    return HealthResponse(status="ok", database="connected")


@app.get("/api/v1/churn-alerts", response_model=ChurnAlertsResponse)
def churn_alerts(
    limit: int = Query(default=20, ge=1, le=500),
    db: Session = Depends(get_db),
):
    customers = db.query(Customer).limit(limit).all()
    cust_ids = [customer.customer_id for customer in customers]
    actions = (
        db.query(RetentionAction)
        .filter(RetentionAction.customer_id.in_(cust_ids))
        .all()
        if cust_ids
        else []
    )
    action_map = {}
    for a in actions:
        if action_map.get(a.customer_id) != "RESOLVED":
            action_map[a.customer_id] = a.status

    payloads = [
        {
            "tenure": customer.tenure,
            "monthly_charges": customer.monthly_charges,
            "total_charges": customer.total_charges,
            "contract": customer.contract,
            "internet_service": customer.internet_service,
            "payment_method": customer.payment_method,
        }
        for customer in customers
    ]
    probabilities = model_service.predict_many(payloads)
    alerts = []
    logs = []
    for customer, payload, probability in zip(customers, payloads, probabilities):
        status = action_map.get(customer.customer_id)
        is_resolved = (status == "RESOLVED")
        effective_prob = 0.05 if is_resolved else probability
        risk = "LOW" if is_resolved else model_service.risk_level(probability)
        top_factor = (
            "Intervensi Retensi Berhasil (Terselamatkan)"
            if is_resolved
            else model_service.top_factor(payload)
        )

        alerts.append(
            ChurnAlert(
                customer_id=customer.customer_id,
                tenure_months=customer.tenure,
                monthly_charges=customer.monthly_charges,
                contract=customer.contract,
                internet_service=customer.internet_service,
                payment_method=customer.payment_method,
                churn_probability=effective_prob,
                risk_level=risk,
                top_factor=top_factor,
                action_status=status,
                baseline_churn_probability=probability,
            )
        )
        logs.append(
            ChurnLog(
                customer_id=customer.customer_id,
                churn_probability=effective_prob,
                risk_level=risk,
            )
        )

    alerts.sort(key=lambda item: item.churn_probability, reverse=True)
    top_ids = {alert.customer_id for alert in alerts}
    db.add_all([log for log in logs if log.customer_id in top_ids])
    db.commit()
    return ChurnAlertsResponse(
        status="success",
        total_records=len(alerts),
        data=alerts,
    )


@app.post("/api/v1/predict", response_model=PredictResponse)
@app.post("/predict", response_model=PredictResponse)
def predict(request: SimulateRequest):
    payload = request.model_dump()
    scored = model_service.score(payload)
    return PredictResponse(
        status="success",
        churn_probability=scored["churn_probability"],
        risk_level=scored["risk_level"],
        recommendation=scored.get("recommendation"),
    )


@app.post("/api/v1/explain", response_model=ShapExplainResponse)
@app.post("/explain", response_model=ShapExplainResponse)
def explain_stateless(request: SimulateRequest):
    payload = request.model_dump()
    scored = model_service.score(payload)
    contributions_data = model_service.explain(payload)
    contributions = [
        ShapContribution(
            feature=item["feature"],
            shap_value=item["shap_value"],
            impact=item["impact"],
        )
        for item in contributions_data
    ]
    return ShapExplainResponse(
        status="success",
        customer_id="payload_simulated",
        churn_probability=scored["churn_probability"],
        risk_level=scored["risk_level"],
        contributions=contributions,
    )


@app.post("/api/v1/simulate", response_model=SimulateResponse)
def simulate(request: SimulateRequest):
    result = model_service.simulate(request.model_dump())
    return SimulateResponse(**result)


@app.get("/api/v1/customers/{customer_id}/recommended-scenarios", response_model=AdaptiveScenariosResponse)
def get_customer_scenarios(customer_id: str, db: Session = Depends(get_db)):
    c = db.query(Customer).filter(Customer.customer_id == customer_id).first()
    if not c:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
    payload = {
        "tenure": c.tenure,
        "monthly_charges": c.monthly_charges,
        "total_charges": c.total_charges,
        "contract": c.contract,
        "internet_service": c.internet_service or "Fiber optic",
        "payment_method": c.payment_method or "Electronic check",
    }
    scenarios = model_service.recommend_scenarios(payload)
    return AdaptiveScenariosResponse(
        status="success",
        customer_id=customer_id,
        scenarios=scenarios,
    )


@app.post("/api/v1/scenarios/recommend", response_model=AdaptiveScenariosResponse)
def recommend_scenarios_for_payload(request: SimulateRequest):
    scenarios = model_service.recommend_scenarios(request.model_dump())
    return AdaptiveScenariosResponse(
        status="success",
        customer_id=None,
        scenarios=scenarios,
    )


@app.get("/api/v1/model-insights")
def model_insights():
    return {
        "status": "success",
        "model_name": "Extreme Gradient Boosting (XGBoost)",
        "version": "2.1.3",
        "objective": "Binary Classification (Customer Churn)",
        "metrics": {
            "accuracy": 0.7510,
            "roc_auc": 0.8370,
            "pr_auc": 0.6490,
            "f1_score": 0.6220,
            "precision": 0.5210,
            "recall": 0.7730,
            "brier_score": 0.1620,
            "holdout_samples": 1409,
            "train_samples": 5634,
        },
        "feature_importance": [
            {"feature": "Kontrak Bulanan", "importance": 0.384, "category": "Contract"},
            {"feature": "Lama Berlangganan (Tenure)", "importance": 0.215, "category": "Tenure"},
            {"feature": "Layanan Fiber Optik", "importance": 0.162, "category": "Service"},
            {"feature": "Tagihan Bulanan (Monthly)", "importance": 0.118, "category": "Billing"},
            {"feature": "Pembayaran Cek Elektronik", "importance": 0.076, "category": "Billing"},
            {"feature": "Akumulasi Total Tagihan", "importance": 0.045, "category": "Billing"},
        ],
        "training_params": {
            "n_estimators": 200,
            "max_depth": 4,
            "learning_rate": 0.1,
            "scale_pos_weight": 2.768,
        },
    }


def generate_phone(customer_id: str) -> str:
    """Menghasilkan nomor telepon dummy (+62800-xxxx-xxxx) agar aman dan tidak memakai nomor asli siapapun."""
    digits = "".join([c for c in customer_id if c.isdigit()])
    if len(digits) < 4:
        digits = str(abs(hash(customer_id)) % 10000).zfill(4)
    suffix = str(abs(hash(customer_id)) % 10000).zfill(4)
    return f"+62800{digits[:4]}{suffix}"


@app.get("/api/v1/customers/{customer_id}/actions", response_model=RetentionActionsResponse)
def get_customer_actions(customer_id: str, db: Session = Depends(get_db)):
    actions = (
        db.query(RetentionAction)
        .filter(RetentionAction.customer_id == customer_id)
        .order_by(RetentionAction.id.desc())
        .all()
    )
    c = db.query(Customer).filter(Customer.customer_id == customer_id).first()
    items = []
    for a in actions:
        items.append(
            RetentionActionItem(
                id=a.id,
                customer_id=a.customer_id,
                phone_number=generate_phone(a.customer_id),
                action_type=a.action_type,
                title=a.title,
                status=a.status,
                note=a.note,
                created_at=a.created_at.strftime("%Y-%m-%d %H:%M") if a.created_at else None,
                tenure_months=c.tenure if c else None,
                monthly_charges=c.monthly_charges if c else None,
                contract=c.contract if c else None,
                internet_service=c.internet_service if c else None,
            )
        )
    return RetentionActionsResponse(
        status="success",
        total_records=len(items),
        data=items,
    )


@app.get("/api/v1/actions", response_model=RetentionActionsResponse)
def get_actions(db: Session = Depends(get_db)):
    actions = db.query(RetentionAction).order_by(RetentionAction.id.desc()).all()
    cust_ids = [a.customer_id for a in actions]
    cust_map = {c.customer_id: c for c in db.query(Customer).filter(Customer.customer_id.in_(cust_ids)).all()} if cust_ids else {}

    items = []
    for a in actions:
        c = cust_map.get(a.customer_id)
        items.append(
            RetentionActionItem(
                id=a.id,
                customer_id=a.customer_id,
                phone_number=generate_phone(a.customer_id),
                action_type=a.action_type,
                title=a.title,
                status=a.status,
                note=a.note,
                created_at=a.created_at.strftime("%Y-%m-%d %H:%M") if a.created_at else None,
                tenure_months=c.tenure if c else None,
                monthly_charges=c.monthly_charges if c else None,
                contract=c.contract if c else None,
                internet_service=c.internet_service if c else None,
            )
        )
    return RetentionActionsResponse(
        status="success",
        total_records=len(items),
        data=items,
    )


@app.post("/api/v1/actions", response_model=RetentionActionItem)
def create_action(payload: RetentionActionCreate, db: Session = Depends(get_db)):
    action = RetentionAction(
        customer_id=payload.customer_id,
        action_type=payload.action_type,
        title=payload.title,
        status=payload.status,
        note=payload.note,
    )
    db.add(action)
    db.commit()
    db.refresh(action)
    c = db.query(Customer).filter(Customer.customer_id == action.customer_id).first()
    return RetentionActionItem(
        id=action.id,
        customer_id=action.customer_id,
        phone_number=generate_phone(action.customer_id),
        action_type=action.action_type,
        title=action.title,
        status=action.status,
        note=action.note,
        created_at=action.created_at.strftime("%Y-%m-%d %H:%M") if action.created_at else None,
        tenure_months=c.tenure if c else None,
        monthly_charges=c.monthly_charges if c else None,
        contract=c.contract if c else None,
        internet_service=c.internet_service if c else None,
    )


@app.patch("/api/v1/actions/{action_id}", response_model=RetentionActionItem)
def update_action(action_id: int, payload: RetentionActionUpdate, db: Session = Depends(get_db)):
    action = db.query(RetentionAction).filter(RetentionAction.id == action_id).first()
    if not action:
        raise HTTPException(status_code=404, detail="Action not found")
    action.status = payload.status
    if payload.note is not None:
        action.note = payload.note
    db.commit()
    db.refresh(action)
    c = db.query(Customer).filter(Customer.customer_id == action.customer_id).first()
    return RetentionActionItem(
        id=action.id,
        customer_id=action.customer_id,
        phone_number=generate_phone(action.customer_id),
        action_type=action.action_type,
        title=action.title,
        status=action.status,
        note=action.note,
        created_at=action.created_at.strftime("%Y-%m-%d %H:%M") if action.created_at else None,
        tenure_months=c.tenure if c else None,
        monthly_charges=c.monthly_charges if c else None,
        contract=c.contract if c else None,
        internet_service=c.internet_service if c else None,
    )


@app.get("/api/v1/actions/stats", response_model=RetentionStats)
def get_action_stats(db: Session = Depends(get_db)):
    actions = db.query(RetentionAction).all()
    total = len(actions)
    pending = sum(1 for a in actions if a.status == "PENDING")
    in_progress = sum(1 for a in actions if a.status == "IN_PROGRESS")
    resolved = sum(1 for a in actions if a.status == "RESOLVED")
    success_rate = round((resolved / total * 100), 1) if total > 0 else 0.0

    resolved_cust_ids = [a.customer_id for a in actions if a.status == "RESOLVED"]
    active_cust_ids = [a.customer_id for a in actions if a.status in ["PENDING", "IN_PROGRESS"]]

    saved_monthly = 0.0
    if resolved_cust_ids:
        resolved_custs = db.query(Customer).filter(Customer.customer_id.in_(resolved_cust_ids)).all()
        saved_monthly = sum(float(c.monthly_charges or 0.0) for c in resolved_custs)

    at_risk_monthly = 0.0
    if active_cust_ids:
        active_custs = db.query(Customer).filter(Customer.customer_id.in_(active_cust_ids)).all()
        at_risk_monthly = sum(float(c.monthly_charges or 0.0) for c in active_custs)

    return RetentionStats(
        total_actions=total,
        pending_count=pending,
        in_progress_count=in_progress,
        resolved_count=resolved,
        success_rate=success_rate,
        revenue_saved_monthly=round(saved_monthly, 2),
        revenue_saved_annual=round(saved_monthly * 12, 2),
        revenue_at_risk=round(at_risk_monthly, 2),
    )


@app.get("/api/v1/customers/{customer_id}/explain", response_model=ShapExplainResponse)
def get_customer_explain(customer_id: str, db: Session = Depends(get_db)):
    c = db.query(Customer).filter(Customer.customer_id == customer_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="Customer not found")

    payload = {
        "tenure": c.tenure,
        "monthly_charges": c.monthly_charges,
        "total_charges": c.total_charges,
        "contract": c.contract,
        "internet_service": c.internet_service,
        "payment_method": c.payment_method,
    }
    scored = model_service.score(payload)
    contributions_data = model_service.explain(payload)

    contributions = [
        ShapContribution(
            feature=item["feature"],
            shap_value=item["shap_value"],
            impact=item["impact"],
        )
        for item in contributions_data
    ]

    return ShapExplainResponse(
        status="success",
        customer_id=c.customer_id,
        churn_probability=scored["churn_probability"],
        risk_level=scored["risk_level"],
        contributions=contributions,
    )
