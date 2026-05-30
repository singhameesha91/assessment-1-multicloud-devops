"""Service A - Transaction API (Python/FastAPI)
A microservice that handles transaction data via AWS DynamoDB.
"""

import os
import uuid
from datetime import datetime, timezone

import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Service A - Transaction API", version="1.0.0")

# Configuration from environment variables
AWS_REGION = os.getenv("AWS_REGION", "ap-southeast-2")
DYNAMODB_TABLE = os.getenv("DYNAMODB_TABLE", "app-transactions")
DYNAMODB_ENDPOINT = os.getenv("DYNAMODB_ENDPOINT")  # Set for local DynamoDB

# DynamoDB client (singleton)
dynamo_kwargs: dict = {"region_name": AWS_REGION}
if DYNAMODB_ENDPOINT:
    dynamo_kwargs["endpoint_url"] = DYNAMODB_ENDPOINT
dynamodb = boto3.resource("dynamodb", **dynamo_kwargs)
table = dynamodb.Table(DYNAMODB_TABLE)


class TransactionCreate(BaseModel):
    user_id: str
    amount: float
    description: str


class TransactionResponse(BaseModel):
    transaction_id: str
    user_id: str
    amount: float
    description: str
    created_at: str


@app.on_event("startup")
def ensure_table():
    """Create the DynamoDB table if it doesn't exist (for local dev)."""
    if not DYNAMODB_ENDPOINT:
        return
    try:
        table.table_status  # noqa: B018 – triggers DescribeTable
    except Exception:
        dynamodb.create_table(
            TableName=DYNAMODB_TABLE,
            KeySchema=[{"AttributeName": "transaction_id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "transaction_id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        table.wait_until_exists()


@app.get("/health")
def health_check():
    """Health check endpoint for ALB target group."""
    return {"status": "healthy", "service": "service-a", "timestamp": datetime.now(timezone.utc).isoformat()}


@app.get("/")
def root():
    """Root endpoint."""
    return {"service": "service-a", "version": "1.0.0", "description": "Transaction API"}


@app.post("/transactions", response_model=TransactionResponse, status_code=201)
def create_transaction(transaction: TransactionCreate):
    """Create a new transaction record in DynamoDB."""
    transaction_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()

    item = {
        "transaction_id": transaction_id,
        "user_id": transaction.user_id,
        "amount": str(transaction.amount),
        "description": transaction.description,
        "created_at": created_at,
    }

    try:
        table.put_item(Item=item)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create transaction: {str(e)}")

    return TransactionResponse(
        transaction_id=transaction_id,
        user_id=transaction.user_id,
        amount=transaction.amount,
        description=transaction.description,
        created_at=created_at,
    )


@app.get("/transactions/{transaction_id}", response_model=TransactionResponse)
def get_transaction(transaction_id: str):
    """Retrieve a transaction by ID."""
    try:
        response = table.get_item(Key={"transaction_id": transaction_id})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve transaction: {str(e)}")

    item = response.get("Item")
    if not item:
        raise HTTPException(status_code=404, detail="Transaction not found")

    return TransactionResponse(
        transaction_id=item["transaction_id"],
        user_id=item["user_id"],
        amount=float(item["amount"]),
        description=item["description"],
        created_at=item["created_at"],
    )


@app.get("/transactions")
def list_transactions(user_id: str | None = None):
    """List transactions, optionally filtered by user_id."""
    try:
        if user_id:
            response = table.scan(
                FilterExpression="user_id = :uid",
                ExpressionAttributeValues={":uid": user_id},
            )
        else:
            response = table.scan()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list transactions: {str(e)}")

    items = response.get("Items", [])
    return {
        "transactions": [
            {
                "transaction_id": item["transaction_id"],
                "user_id": item["user_id"],
                "amount": float(item["amount"]),
                "description": item["description"],
                "created_at": item["created_at"],
            }
            for item in items
        ],
        "count": len(items),
    }
