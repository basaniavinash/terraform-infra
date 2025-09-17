data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.subjects
    }
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.assume.json
  name               = var.role_name
}

resource "aws_iam_policy" "inline" {
  count  = var.policy_json == null ? 0 : 1
  name   = "${var.role_name}-inline"
  policy = var.policy_json
}

resource "aws_iam_role_policy_attachment" "attach_inline" {
  count      = var.policy_json == null ? 0 : 1
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.inline[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

output "role_arn" {
  value = aws_iam_role.this.arn
}
