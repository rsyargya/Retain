from pathlib import Path

import joblib
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

BACKEND_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = BACKEND_ROOT / "data" / "WA_Fn-UseC_-Telco-Customer-Churn.csv"
MODELS_DIR = BACKEND_ROOT / "models"

FEATURE_COLS = [
    "tenure",
    "MonthlyCharges",
    "TotalCharges",
    "Contract",
    "InternetService",
    "PaymentMethod",
]
CATEGORICAL_COLS = ["Contract", "InternetService", "PaymentMethod"]
NUMERIC_COLS = ["tenure", "MonthlyCharges", "TotalCharges"]
SCALE_POS_WEIGHT = 2.768


def load_and_clean() -> pd.DataFrame:
    df = pd.read_csv(CSV_PATH)
    df["TotalCharges"] = (
        df["TotalCharges"].astype(str).str.strip().replace({"": "0", " ": "0"})
    )
    df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce").fillna(0.0)
    df["Churn"] = (df["Churn"] == "Yes").astype(int)
    return df


def main() -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    df = load_and_clean()
    X = df[FEATURE_COLS].copy()
    y = df["Churn"]

    X = pd.get_dummies(X, columns=CATEGORICAL_COLS)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    scaler = StandardScaler()
    X_train[NUMERIC_COLS] = scaler.fit_transform(X_train[NUMERIC_COLS])
    X_test[NUMERIC_COLS] = scaler.transform(X_test[NUMERIC_COLS])

    model = XGBClassifier(
        scale_pos_weight=SCALE_POS_WEIGHT,
        n_estimators=200,
        max_depth=4,
        learning_rate=0.1,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        n_jobs=-1,
        eval_metric="logloss",
    )
    model.fit(X_train, y_train)
    accuracy = (model.predict(X_test) == y_test).mean()

    joblib.dump(model, MODELS_DIR / "xgboost_model.pkl")
    joblib.dump(
        {
            "scaler": scaler,
            "feature_columns": list(X_train.columns),
            "numeric_cols": NUMERIC_COLS,
        },
        MODELS_DIR / "preprocessor.pkl",
    )
    print(f"Saved model artifacts to {MODELS_DIR}")
    print(f"Holdout accuracy: {accuracy:.4f}")
    print(f"scale_pos_weight={SCALE_POS_WEIGHT}")


if __name__ == "__main__":
    main()
