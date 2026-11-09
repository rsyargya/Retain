from pathlib import Path
from typing import Any, Dict, List, Optional

import joblib
import pandas as pd
import shap  # type: ignore

BACKEND_ROOT = Path(__file__).resolve().parent.parent
MODEL_PATH = BACKEND_ROOT / "models" / "xgboost_model.pkl"
PREPROCESSOR_PATH = BACKEND_ROOT / "models" / "preprocessor.pkl"

NUMERIC_COLS = ["tenure", "MonthlyCharges", "TotalCharges"]
CATEGORICAL_COLS = ["Contract", "InternetService", "PaymentMethod"]

CRITICAL_THRESHOLD = 0.70
HIGH_THRESHOLD = 0.50

# Human-readable names for encoded features
FEATURE_DISPLAY_NAMES = {
    "tenure": "Lama Berlangganan (Tenor)",
    "MonthlyCharges": "Tagihan Bulanan",
    "TotalCharges": "Total Akumulasi Tagihan",
    "Contract_Month-to-month": "Kontrak Bulanan",
    "Contract_One year": "Kontrak 1 Tahun",
    "Contract_Two year": "Kontrak 2 Tahun",
    "InternetService_DSL": "Internet DSL",
    "InternetService_Fiber optic": "Internet Fiber Optik",
    "InternetService_No": "Tanpa Internet",
    "PaymentMethod_Bank transfer (automatic)": "Bayar via Transfer Bank",
    "PaymentMethod_Credit card (automatic)": "Bayar via Kartu Kredit",
    "PaymentMethod_Electronic check": "Bayar via Cek Elektronik",
    "PaymentMethod_Mailed check": "Bayar via Cek Pos",
}


class ModelService:
    def __init__(self) -> None:
        self.model = None
        self.scaler = None
        self.feature_columns = None
        self._explainer = None

    def load(self) -> None:
        if not MODEL_PATH.exists() or not PREPROCESSOR_PATH.exists():
            raise FileNotFoundError(
                "Model artifacts missing. Run training/train_model.py first."
            )
        self.model = joblib.load(MODEL_PATH)
        preprocessor = joblib.load(PREPROCESSOR_PATH)
        self.scaler = preprocessor["scaler"]
        self.feature_columns = preprocessor["feature_columns"]

    def _get_explainer(self) -> Any:
        if self._explainer is None:
            self._explainer = shap.TreeExplainer(self.model)
        return self._explainer

    def _rows_to_frame(self, payloads: list[Dict[str, Any]]) -> pd.DataFrame:
        frame = pd.DataFrame(
            [
                {
                    "tenure": int(payload["tenure"]),
                    "MonthlyCharges": float(payload["monthly_charges"]),
                    "TotalCharges": float(payload.get("total_charges", float(payload.get("tenure", 0)) * float(payload.get("monthly_charges", 0.0)))),
                    "Contract": payload["contract"],
                    "InternetService": payload["internet_service"],
                    "PaymentMethod": payload["payment_method"],
                }
                for payload in payloads
            ]
        )
        encoded = pd.get_dummies(frame, columns=CATEGORICAL_COLS)
        encoded = encoded.reindex(columns=self.feature_columns, fill_value=0)
        encoded[NUMERIC_COLS] = self.scaler.transform(encoded[NUMERIC_COLS])
        return encoded

    def _to_frame(self, payload: Dict[str, Any]) -> pd.DataFrame:
        return self._rows_to_frame([payload])

    def predict_proba(self, payload: Dict[str, Any]) -> float:
        encoded = self._to_frame(payload)
        probability = float(self.model.predict_proba(encoded)[0][1])
        return round(probability, 4)

    def predict_many(self, payloads: list[Dict[str, Any]]) -> list[float]:
        if not payloads:
            return []
        return [self.predict_proba(payload) for payload in payloads]

    def risk_level(self, probability: float) -> str:
        if probability >= CRITICAL_THRESHOLD:
            return "CRITICAL"
        if probability >= HIGH_THRESHOLD:
            return "HIGH"
        return "LOW"

    def top_factor(self, payload: Dict[str, Any]) -> str:
        tenure = int(payload["tenure"])
        contract = payload["contract"]
        internet = payload["internet_service"]
        payment = payload["payment_method"]
        monthly = float(payload["monthly_charges"])

        if tenure <= 6 and contract == "Month-to-month":
            return "Tenor Singkat & Kontrak Bulanan"
        if internet == "Fiber optic" and payment == "Electronic check":
            return "Fiber Optik & E-Check Manual"
        if contract == "Month-to-month":
            return "Kontrak Bulanan"
        if monthly >= 80:
            return "Tagihan bulanan tinggi"
        if tenure <= 12:
            return "Tenor pelanggan masih rendah"
        return "Profil penggunaan layanan"

    def explain(self, payload: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Return SHAP values for a single customer, sorted by absolute impact."""
        encoded = self._to_frame(payload)
        explainer = self._get_explainer()
        shap_values = explainer.shap_values(encoded)

        # shap_values shape: (1, n_features) — take first row
        values = shap_values[0]
        features = list(encoded.columns)

        contributions = []
        for feat, val in zip(features, values):
            if abs(val) < 0.001:
                continue
            display_name = FEATURE_DISPLAY_NAMES.get(feat, feat)
            contributions.append({
                "feature": display_name,
                "shap_value": round(float(val), 4),
                "impact": "increase" if val > 0 else "decrease",
            })

        contributions.sort(key=lambda x: abs(x["shap_value"]), reverse=True)
        return contributions[:8]

    def estimate_acceptance_probability(
        self,
        simulated_payload: Dict[str, Any],
        baseline_payload: Optional[Dict[str, Any]] = None,
        baseline_churn_prob: Optional[float] = None,
    ) -> float:
        """Estimate the probability that a customer will accept the proposed offer.

        The heuristic model considers:
        - Discount attractiveness: larger discounts are more appealing
        - Contract aggressiveness: jumping from monthly to 2-year is less likely
          to be accepted than monthly to 1-year
        - Customer tenure/loyalty: longer-tenured customers are more receptive
          to loyalty offers
        - Current churn risk: customers who feel pain (high risk) are more
          open to solutions
        - Payment friction reduction: switching from manual to auto-debit is
          generally welcomed
        """
        score = 50.0  # base acceptance rate 50%

        # 1. Discount factor (0-30 pts)
        if baseline_payload is not None:
            base_monthly = float(baseline_payload.get("monthly_charges", 0))
            sim_monthly = float(simulated_payload.get("monthly_charges", 0))
            if base_monthly > 0:
                discount_pct = (base_monthly - sim_monthly) / base_monthly * 100
                # Each 5% discount adds ~6 pts, cap at 30
                score += min(30.0, max(0.0, discount_pct * 1.2))
            else:
                score += 5.0
        else:
            score += 5.0

        # 2. Contract aggressiveness penalty (-20 to +5 pts)
        base_contract = (baseline_payload or {}).get("contract", "Month-to-month")
        sim_contract = simulated_payload.get("contract", base_contract)
        contract_rank = {"Month-to-month": 0, "One year": 1, "Two year": 2}
        jump = contract_rank.get(sim_contract, 0) - contract_rank.get(base_contract, 0)
        if jump == 0:
            score += 5.0   # no change is easy to accept
        elif jump == 1:
            score += 0.0   # mild step up, neutral
        elif jump >= 2:
            score -= 15.0  # big jump, customer may hesitate

        # 3. Tenure / loyalty factor (0-15 pts)
        tenure = int(simulated_payload.get("tenure", 0))
        if tenure >= 36:
            score += 15.0   # very loyal, receptive to offers
        elif tenure >= 18:
            score += 10.0
        elif tenure >= 6:
            score += 5.0
        else:
            score -= 5.0    # very new, skeptical

        # 4. Churn risk pressure factor (0-15 pts)
        if baseline_churn_prob is not None:
            if baseline_churn_prob >= 0.70:
                score += 15.0  # desperate situation, customer more open
            elif baseline_churn_prob >= 0.50:
                score += 10.0
            elif baseline_churn_prob >= 0.30:
                score += 5.0
            else:
                score -= 5.0   # low risk, why would they bother?

        # 5. Payment friction reduction bonus (0-8 pts)
        base_payment = (baseline_payload or {}).get("payment_method", "Electronic check")
        sim_payment = simulated_payload.get("payment_method", base_payment)
        manual_methods = {"Electronic check", "Mailed check"}
        auto_methods = {"Bank transfer (automatic)", "Credit card (automatic)"}
        if base_payment in manual_methods and sim_payment in auto_methods:
            score += 8.0  # removing friction is attractive
        elif base_payment in auto_methods and sim_payment in manual_methods:
            score -= 10.0  # regression, unlikely accepted

        # Clamp to [5, 95] — never 0% or 100%
        return round(min(95.0, max(5.0, score)) / 100.0, 4)

    def recommendation(self, payload: Dict[str, Any], probability: float, risk: str) -> str:
        if payload["contract"] != "Month-to-month" and risk == "LOW":
            return "Penawaran kontrak 1 tahun berhasil menekan risiko ke level Rendah."
        if payload["contract"] == "Two year":
            return "Kontrak dua tahun membantu menahan churn; pertahankan insentif loyalitas."
        if payload["contract"] == "One year":
            if risk == "LOW":
                return "Penawaran kontrak 1 tahun berhasil menekan risiko ke level Rendah."
            return "Kontrak tahunan sudah membantu; kombinasikan dengan diskon tagihan."
        if payload["payment_method"] == "Electronic check":
            return "Alihkan pembayaran ke autodebit bank/kartu untuk menurunkan risiko churn."
        if risk == "CRITICAL":
            return "Prioritaskan retensi: tawarkan upgrade kontrak dan bundling layanan."
        return "Pertahankan engagement dan tinjau ulang paket harga pelanggan."

    def score(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        probability = self.predict_proba(payload)
        risk = self.risk_level(probability)
        return {
            "churn_probability": probability,
            "risk_level": risk,
            "top_factor": self.top_factor(payload),
            "recommendation": self.recommendation(payload, probability, risk),
        }

    def baseline_payload(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        baseline = dict(payload)
        baseline["contract"] = "Month-to-month"
        baseline["payment_method"] = "Electronic check"
        return baseline

    def simulate(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        scored = self.score(payload)
        new_prob = scored["churn_probability"]

        baseline_val = payload.get("baseline_probability")
        if baseline_val is not None and float(baseline_val) > 0:
            baseline_prob = float(baseline_val)
        else:
            baseline_prob = self.predict_proba(self.baseline_payload(payload))

        if baseline_prob <= 0:
            reduction = 0.0
        else:
            reduction = max(0.0, (baseline_prob - new_prob) / baseline_prob * 100)

        # Build baseline payload for acceptance estimation
        base_pl = self.baseline_payload(payload)
        acceptance = self.estimate_acceptance_probability(
            simulated_payload=payload,
            baseline_payload=base_pl,
            baseline_churn_prob=baseline_prob,
        )

        return {
            "status": "success",
            "new_churn_probability": new_prob,
            "risk_level": scored["risk_level"],
            "risk_reduction_percentage": round(reduction, 1),
            "recommendation": scored["recommendation"],
            "acceptance_probability": acceptance,
        }

    def recommend_scenarios(self, payload: Dict[str, Any]) -> List[Dict[str, Any]]:
        current_prob = self.predict_proba(payload)
        tenure = int(payload.get("tenure", 12))
        monthly = float(payload.get("monthly_charges", 65.0))
        contract = payload.get("contract", "Month-to-month")
        internet = payload.get("internet_service", "Fiber optic")
        payment = payload.get("payment_method", "Electronic check")

        scenarios: List[Dict[str, Any]] = []

        # 1. Kontrak Bulanan -> Kontrak 1 Tahun + Diskon (Solusi Risiko Utama)
        if contract == "Month-to-month":
            p1 = dict(payload)
            p1["contract"] = "One year"
            p1["monthly_charges"] = round(monthly * 0.85, 2)
            p1["tenure"] = max(tenure, 12)
            if payment in ["Electronic check", "Mailed check"]:
                p1["payment_method"] = "Bank transfer (automatic)"
            p1["total_charges"] = round(p1["tenure"] * p1["monthly_charges"], 2)
            p1["baseline_probability"] = current_prob
            sim1 = self.simulate(p1)
            scenarios.append({
                "id": "CONTRACT_LOCK_1YR",
                "title": "Paket Komitmen Hemat 1 Tahun",
                "badge": "Solusi Risiko Utama",
                "badge_type": "primary",
                "diagnosis": "Pelanggan berada pada kontrak bulanan tanpa ikatan. Ini merupakan pendorong churn terbesar (bobot 38.4%).",
                "solution_analysis": "AI merekomendasikan komitmen 12 bulan dengan diskon 15% dan pembayaran otomatis guna menekan risiko pembatalan secara drastis.",
                "target_contract": p1["contract"],
                "target_monthly_charges": p1["monthly_charges"],
                "target_payment_method": p1["payment_method"],
                "target_internet_service": p1["internet_service"],
                "target_tenure": p1["tenure"],
                "discount_tag": "-15% Diskon",
                "projected_risk_reduction": sim1["risk_reduction_percentage"],
                "projected_churn_probability": sim1["new_churn_probability"],
                "projected_risk_level": sim1["risk_level"],
            })

        # 2. Beban Tagihan Tinggi -> Relief Tagihan & Rasionalisasi
        if monthly >= 70.0:
            p2 = dict(payload)
            p2["contract"] = "One year" if contract == "Month-to-month" else contract
            p2["monthly_charges"] = round(monthly * 0.78, 2)
            p2["tenure"] = max(tenure, 12)
            if payment in ["Electronic check", "Mailed check"]:
                p2["payment_method"] = "Bank transfer (automatic)"
            p2["total_charges"] = round(p2["tenure"] * p2["monthly_charges"], 2)
            p2["baseline_probability"] = current_prob
            sim2 = self.simulate(p2)
            scenarios.append({
                "id": "BILL_SHOCK_RELIEF",
                "title": "Relief Beban Tagihan (Anti-Bill Shock)",
                "badge": "Meredakan Beban Biaya",
                "badge_type": "warning",
                "diagnosis": f"Tagihan bulanan saat ini (${monthly:.1f}) memicu ketidakpuasan harga dan sensitivitas terhadap penawaran kompetitor.",
                "solution_analysis": "AI merekomendasikan penyesuaian tarif sebesar 22% dipadukan dengan komitmen tahunan untuk melindungi margin CLV jangka panjang.",
                "target_contract": p2["contract"],
                "target_monthly_charges": p2["monthly_charges"],
                "target_payment_method": p2["payment_method"],
                "target_internet_service": p2["internet_service"],
                "target_tenure": p2["tenure"],
                "discount_tag": "-22% Hemat",
                "projected_risk_reduction": sim2["risk_reduction_percentage"],
                "projected_churn_probability": sim2["new_churn_probability"],
                "projected_risk_level": sim2["risk_level"],
            })

        # 3. Friksi Pembayaran Manual -> Migrasi Autodebit Bank
        if payment in ["Electronic check", "Mailed check"]:
            p3 = dict(payload)
            p3["payment_method"] = "Bank transfer (automatic)"
            p3["monthly_charges"] = round(max(10.0, monthly - 5.0), 2)
            p3["total_charges"] = round(p3["tenure"] * p3["monthly_charges"], 2)
            p3["baseline_probability"] = current_prob
            sim3 = self.simulate(p3)
            scenarios.append({
                "id": "AUTODEBIT_MIGRATION",
                "title": "Migrasi Autodebit Bank + Bebas Admin",
                "badge": "Eliminasi Friksi Bayar",
                "badge_type": "success",
                "diagnosis": f"Metode bayar saat ini ({payment}) memicu friksi manual bulanan yang melipatgandakan kecenderungan churn pasif.",
                "solution_analysis": "AI menyarankan migrasi langsung ke Autodebit Bank dengan cashback potongan biaya admin $5/bln demi kelancaran penagihan.",
                "target_contract": p3["contract"],
                "target_monthly_charges": p3["monthly_charges"],
                "target_payment_method": p3["payment_method"],
                "target_internet_service": p3["internet_service"],
                "target_tenure": p3["tenure"],
                "discount_tag": "Bebas Admin",
                "projected_risk_reduction": sim3["risk_reduction_percentage"],
                "projected_churn_probability": sim3["new_churn_probability"],
                "projected_risk_level": sim3["risk_level"],
            })

        # 4. Pelanggan Lama / Veteran (Tenure >= 24) -> VIP Loyalty Lock 2 Tahun
        if tenure >= 24 or len(scenarios) < 3:
            p4 = dict(payload)
            p4["contract"] = "Two year"
            p4["monthly_charges"] = round(monthly * 0.80, 2)
            p4["tenure"] = max(tenure, 24)
            p4["payment_method"] = "Bank transfer (automatic)"
            p4["total_charges"] = round(p4["tenure"] * p4["monthly_charges"], 2)
            p4["baseline_probability"] = current_prob
            sim4 = self.simulate(p4)
            scenarios.append({
                "id": "VIP_LOYALTY_2YR",
                "title": "Program Retensi VIP 2 Tahun",
                "badge": "Apresiasi Loyalitas VIP",
                "badge_type": "purple",
                "diagnosis": f"Akun dengan loyalitas {tenure} bulan berpotensi berpindah jika tidak diberikan apresiasi atas hubungan pelanggan jangka panjang.",
                "solution_analysis": "AI merekomendasikan kontrak 2 tahun dengan diskon VIP 20% dan proteksi tarif tetap untuk mempertahankan akun bernilai tinggi.",
                "target_contract": p4["contract"],
                "target_monthly_charges": p4["monthly_charges"],
                "target_payment_method": p4["payment_method"],
                "target_internet_service": p4["internet_service"],
                "target_tenure": p4["tenure"],
                "discount_tag": "-20% VIP",
                "projected_risk_reduction": sim4["risk_reduction_percentage"],
                "projected_churn_probability": sim4["new_churn_probability"],
                "projected_risk_level": sim4["risk_level"],
            })

        # 5. Layanan Non-Fiber -> Upgrade Fiber Optic
        if internet in ["DSL", "No"] and len(scenarios) < 4:
            p5 = dict(payload)
            p5["internet_service"] = "Fiber optic"
            p5["contract"] = "One year"
            p5["monthly_charges"] = round(monthly * 0.95, 2)
            p5["tenure"] = max(tenure, 12)
            p5["payment_method"] = "Bank transfer (automatic)"
            p5["total_charges"] = round(p5["tenure"] * p5["monthly_charges"], 2)
            p5["baseline_probability"] = current_prob
            sim5 = self.simulate(p5)
            scenarios.append({
                "id": "FIBER_UPGRADE_1YR",
                "title": "Upgrade Kecepatan Fiber + Promo 1 Tahun",
                "badge": "Peningkatan Kualitas",
                "badge_type": "teal",
                "diagnosis": "Koneksi DSL/non-fiber memiliki keterbatasan bandwidth yang rentan ditinggalkan ke provider fiber berkecepatan tinggi.",
                "solution_analysis": "AI menyarankan peningkatan koneksi ke Fiber Optic berkecepatan tinggi dengan kontrak 1 tahun untuk meningkatkan kepuasan layanan.",
                "target_contract": p5["contract"],
                "target_monthly_charges": p5["monthly_charges"],
                "target_payment_method": p5["payment_method"],
                "target_internet_service": p5["internet_service"],
                "target_tenure": p5["tenure"],
                "discount_tag": "Promo Fiber",
                "projected_risk_reduction": sim5["risk_reduction_percentage"],
                "projected_churn_probability": sim5["new_churn_probability"],
                "projected_risk_level": sim5["risk_level"],
            })

        return scenarios[:4]



model_service = ModelService()


def get_model_service() -> Optional[ModelService]:
    return model_service

