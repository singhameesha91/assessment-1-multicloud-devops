# -------------------------------------------------------
# DynamoDB Table - Transaction data for Service A
# Creates a NoSQL table for storing financial transactions.
# Expect: 1 table with on-demand billing (PAY_PER_REQUEST)
#         so there are no provisioned capacity charges – you
#         only pay per read/write. Partition key: transaction_id.
# -------------------------------------------------------

resource "aws_dynamodb_table" "transactions" {
  name         = "${var.project_name}-${var.environment}-transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transaction_id"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-transactions"
  }
}
