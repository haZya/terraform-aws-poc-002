resource "aws_dynamodb_table" "uploads" {
  name         = "${var.resource_prefix}-uploads"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uploadId"

  attribute {
    name = "uploadId"
    type = "S"
  }

  attribute {
    name = "relationKey"
    type = "S"
  }

  attribute {
    name = "stagingKey"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "ByRelation"
    projection_type = "ALL"

    key_schema {
      attribute_name = "relationKey"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "ByStagingKey"
    projection_type = "ALL"

    key_schema {
      attribute_name = "stagingKey"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.resource_prefix}-uploads"
  }
}

resource "aws_dynamodb_table" "upload_relations" {
  name         = "${var.resource_prefix}-upload-relations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "relationKey"

  attribute {
    name = "relationKey"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.resource_prefix}-upload-relations"
  }
}
