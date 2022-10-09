variable "s3_bucket_name" {}
variable "aws_iam_role_name" {}
variable "external_storage_location_label" {}
variable "databricks_account_id" {}

# This resource will destroy (potentially immediately) after null_resource.next
resource "null_resource" "previous" {}

resource "time_sleep" "wait_seconds" {
  depends_on = [null_resource.previous]

  create_duration = "30s"
}

data "aws_iam_policy_document" "passrole_for_unity_catalog" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }
}

resource "aws_s3_bucket" "external" {
  bucket = "${var.s3_bucket_name}"
  acl    = "private"
  versioning {
    enabled = false
  }
  force_destroy = true
  tags = merge(local.tags, {
    Name = "${var.s3_bucket_name}"
  })
}

resource "aws_s3_bucket_public_access_block" "external" {
  bucket             = aws_s3_bucket.external.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.external]
}

resource "aws_iam_policy" "external_data_access" {
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${aws_s3_bucket.external.id}-access"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          aws_s3_bucket.external.arn,
          "${aws_s3_bucket.external.arn}/*"
        ],
        "Effect" : "Allow"
      }
    ]
  })
  tags = merge(local.tags, {
    Name = "${var.aws_iam_role_name} ${var.s3_bucket_name} access IAM policy"
  })

}

resource "aws_iam_role" "external_data_access" {
  name                = "${var.aws_iam_role_name}"
  assume_role_policy  = data.aws_iam_policy_document.passrole_for_unity_catalog.json
  managed_policy_arns = [aws_iam_policy.external_data_access.arn]
  tags = merge(local.tags, {
    Name = "${var.aws_iam_role_name} ${var.s3_bucket_name} access IAM role"
  })
}

resource "databricks_storage_credential" "external" {
  depends_on = [time_sleep.wait_seconds]
  name     = aws_iam_role.external_data_access.name
  aws_iam_role {
    role_arn = aws_iam_role.external_data_access.arn
  }
}

resource "databricks_external_location" "some" {

  name            = "${var.s3_bucket_name}"
  url             = "s3://${var.s3_bucket_name}/${var.external_storage_location_label}"
  credential_name = databricks_storage_credential.external.id
}
