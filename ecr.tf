
resource "aws_ecr_repository" "this" {
  #checkov:skip=CKV_AWS_136: "Ensure that ECR repositories are encrypted using KMS" https://docs.bridgecrew.io/docs/ensure-that-ecr-repositories-are-encrypted
  for_each             = toset(var.ecr_repository)
  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

}


data "aws_iam_policy_document" "pullpush_policy" {
  dynamic "statement" {
    for_each = var.ecr_iam_principal != [] ? [1] : []

    content {
      sid    = "AllowPullPush"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.ecr_iam_principal
      }
      actions = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.readonly_external_aws_iam_principals != [] ? [1] : []

    content {
      sid    = "EcrReadOnlyDevAccess"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.readonly_external_aws_iam_principals
      }
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:ListTagsForResource",
        "ecr:DescribeImageScanFindings"
      ]
    }
  }
}

/*

resource "aws_ecr_repository_policy" "pullpush" {
  for_each   = toset(var.ecr_repository)
  repository = aws_ecr_repository.this[each.key].name
  policy     = data.aws_iam_policy_document.pullpush_policy.json
}
*/
data "aws_caller_identity" "current" {}


data "aws_partition" "this" {}


data "aws_iam_policy_document" "pullthroughcache_policy" {
  dynamic "statement" {
    for_each = var.readonly_external_aws_iam_principals != [] ? [1] : []

    content {
      sid    = "AllowPullThroughCache"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.readonly_external_aws_iam_principals
      }
      actions = [
        "ecr:CreateRepository",
        "ecr:BatchImportUpstreamImage"
      ]
      resources = [
        for remote_ecr_repository in var.pullthroughcache_repositories :
        "arn:${data.aws_partition.this.partition}:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/ecr-public/${remote_ecr_repository}"
      ]
    }
  }
}

data "aws_iam_policy_document" "pullthroughcache_ecr_sharing" {
  dynamic "statement" {
    for_each = var.readonly_external_aws_iam_principals != [] ? [1] : []

    content {
      sid    = "AllowPullThroughCacheCrossAccount"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.readonly_external_aws_iam_principals
      }
      actions = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken"
      ]
    }
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = toset(values(aws_ecr_repository.this)[*].name)
  repository = each.value

  policy = <<EOF
{
  "rules": [
      {
        "rulePriority": 1,
        "description": "Expire untagged images older than 2 days",
        "selection": {
          "tagStatus": "untagged",
          "countType": "sinceImagePushed",
          "countUnit": "days",
          "countNumber": 2
        },
        "action": {
          "type": "expire"
        }
      }
    ]
}
EOF
}


resource "aws_ecr_registry_policy" "this" {
  policy = data.aws_iam_policy_document.pullthroughcache_policy.json
}

/*
resource "aws_ecr_pull_through_cache_rule" "ecr-public" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}
*/
/*
resource "aws_ecr_repository_policy" "pullthroughcache_ecr_sharing" {
  for_each   = toset(var.pullthroughcache_repositories)
  repository = "ecr-public/${each.key}"
  policy     = data.aws_iam_policy_document.pullthroughcache_ecr_sharing.json
}
*/
