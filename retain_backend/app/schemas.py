from typing import List, Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str
    database: str


class SimulateRequest(BaseModel):
    tenure: int = Field(..., ge=0, le=72)
    monthly_charges: float = Field(..., ge=0)
    total_charges: float = Field(..., ge=0)
    contract: str
    internet_service: str
    payment_method: str
    baseline_probability: Optional[float] = None


class SimulateResponse(BaseModel):
    status: str
    new_churn_probability: float
    risk_level: str
    risk_reduction_percentage: float
    recommendation: str
    acceptance_probability: Optional[float] = None


class PredictResponse(BaseModel):
    status: str
    churn_probability: float
    risk_level: str
    recommendation: Optional[str] = None


class ChurnAlert(BaseModel):
    customer_id: str
    tenure_months: int
    monthly_charges: float
    contract: str
    internet_service: Optional[str] = None
    payment_method: Optional[str] = None
    churn_probability: float
    risk_level: str
    top_factor: str
    action_status: Optional[str] = None
    baseline_churn_probability: Optional[float] = None


class ChurnAlertsResponse(BaseModel):
    status: str
    total_records: int
    data: List[ChurnAlert]


class FeaturePayload(BaseModel):
    tenure: int
    monthly_charges: float
    total_charges: float
    contract: str
    internet_service: str
    payment_method: str
    customer_id: Optional[str] = None


class RetentionActionCreate(BaseModel):
    customer_id: str
    action_type: str = "OFFER_DISCOUNT"
    title: str
    status: str = "PENDING"
    note: Optional[str] = None


class RetentionActionUpdate(BaseModel):
    status: str
    note: Optional[str] = None


class RetentionActionItem(BaseModel):
    id: int
    customer_id: str
    phone_number: str
    action_type: str
    title: str
    status: str
    note: Optional[str] = None
    created_at: Optional[str] = None
    tenure_months: Optional[int] = None
    monthly_charges: Optional[float] = None
    contract: Optional[str] = None
    internet_service: Optional[str] = None


class RetentionActionsResponse(BaseModel):
    status: str
    total_records: int
    data: List[RetentionActionItem]


class ShapContribution(BaseModel):
    feature: str
    shap_value: float
    impact: str  # "increase" or "decrease"


class ShapExplainResponse(BaseModel):
    status: str
    customer_id: str
    churn_probability: float
    risk_level: str
    contributions: List[ShapContribution]


class RetentionStats(BaseModel):
    total_actions: int
    pending_count: int
    in_progress_count: int
    resolved_count: int
    success_rate: float  # percentage
    revenue_saved_monthly: float  # sum of monthly_charges for resolved
    revenue_saved_annual: float
    revenue_at_risk: float  # sum of monthly_charges for non-resolved


class AdaptiveScenarioItem(BaseModel):
    id: str
    title: str
    badge: str
    badge_type: str
    diagnosis: str
    solution_analysis: str
    target_contract: str
    target_monthly_charges: float
    target_payment_method: str
    target_internet_service: str
    target_tenure: int
    discount_tag: str
    projected_risk_reduction: float
    projected_churn_probability: float
    projected_risk_level: str


class AdaptiveScenariosResponse(BaseModel):
    status: str
    customer_id: Optional[str] = None
    scenarios: List[AdaptiveScenarioItem]

