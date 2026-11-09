from pathlib import Path

import pandas as pd
from sqlalchemy.orm import Session

from app.database import Base, SessionLocal, engine
from app.models_db import Customer

BACKEND_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = BACKEND_ROOT / "data" / "WA_Fn-UseC_-Telco-Customer-Churn.csv"


def load_customers() -> pd.DataFrame:
    df = pd.read_csv(CSV_PATH)
    df["TotalCharges"] = (
        df["TotalCharges"].astype(str).str.strip().replace({"": "0", " ": "0"})
    )
    df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce").fillna(0.0)
    df["churn_historical"] = (df["Churn"] == "Yes").astype(int)
    return df


def seed(drop_existing: bool = False) -> None:
    if drop_existing:
        Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    df = load_customers()
    db: Session = SessionLocal()
    try:
        records = [
            Customer(
                customer_id=row["customerID"],
                tenure=int(row["tenure"]),
                monthly_charges=float(row["MonthlyCharges"]),
                total_charges=float(row["TotalCharges"]),
                contract=row["Contract"],
                internet_service=row["InternetService"],
                payment_method=row["PaymentMethod"],
                churn_historical=int(row["churn_historical"]),
            )
            for _, row in df.iterrows()
        ]
        db.bulk_save_objects(records)
        db.commit()
        db_type = "PostgreSQL" if "postgresql" in engine.url.drivername else "SQLite"
        print(f"Seeded {len(records)} customers into {db_type}")
    finally:
        db.close()


if __name__ == "__main__":
    seed(drop_existing=True)

