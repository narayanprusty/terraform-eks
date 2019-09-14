data "aws_caller_identity" "current" {}

resource "aws_dynamodb_table" "locking" {
  name           = "${data.aws_caller_identity.current.account_id}-${local.name}"
  read_capacity  = "20"
  write_capacity = "20"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_s3_bucket" "state" {
  bucket = "${data.aws_caller_identity.current.account_id}-${local.name}"
  region = "${local.region}"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

output "BACKEND_BUCKET_NAME" {
  value = "${aws_s3_bucket.state.bucket}"
}

output "BACKEND_TABLE_NAME" {
  value = "${aws_dynamodb_table.locking.name}"
}

output "BACKEND_REGION" {
  value = "${local.region}"
}