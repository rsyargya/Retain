from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from app.database import Base


class Customer(Base):
    __tablename__ = "customers"

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(String, unique=True, nullable=False, index=True)
    tenure = Column(Integer, nullable=False)
    monthly_charges = Column(Float, nullable=False)
    total_charges = Column(Float, nullable=False)
    contract = Column(String, nullable=False)
    internet_service = Column(String, nullable=False)
    payment_method = Column(String, nullable=False)
    churn_historical = Column(Integer, nullable=False)

    churn_logs = relationship("ChurnLog", back_populates="customer", cascade="all, delete-orphan")


class ChurnLog(Base):
    __tablename__ = "churn_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(String, ForeignKey("customers.customer_id"), nullable=False, index=True)
    churn_probability = Column(Float, nullable=False)
    risk_level = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.current_timestamp())

    customer = relationship("Customer", back_populates="churn_logs")


class RetentionAction(Base):
    __tablename__ = "retention_actions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(String, ForeignKey("customers.customer_id"), nullable=False, index=True)
    action_type = Column(String, nullable=False)
    title = Column(String, nullable=False)
    status = Column(String, default="PENDING", nullable=False)
    note = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.current_timestamp())

    customer = relationship("Customer")


