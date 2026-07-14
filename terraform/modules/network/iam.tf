# SSM proxy has Session Manager permissions only. It cannot read application secrets.
resource "aws_iam_role" "ssm_proxy" {
  # Keep the legacy physical name so the role can move in state without replacement.
  name                 = "${var.project_name}-ec2-ssm-role"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-ssm-proxy-boundary"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = merge(local.tags, { Name = "${var.project_name}-ec2-ssm-role", Role = "ssm-proxy" })
}

resource "aws_iam_role_policy_attachment" "ssm_proxy_core" {
  role       = aws_iam_role.ssm_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_proxy" {
  # Keep the legacy physical name so the profile can move in state without replacement.
  name = "${var.project_name}-ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_proxy.name
  tags = merge(local.tags, { Name = "${var.project_name}-ec2-ssm-instance-profile", Role = "ssm-proxy" })
}

# Web runtime identity is separate so proxy access cannot be used to read app secrets.
resource "aws_iam_role" "web_runtime" {
  name                 = "${var.project_name}-web-runtime-role"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-web-runtime-boundary"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = merge(local.tags, { Name = "${var.project_name}-web-runtime-role", Role = "web-runtime" })
}

resource "aws_iam_role_policy_attachment" "web_ssm_core" {
  count      = var.enable_web_ssm ? 1 : 0
  role       = aws_iam_role.web_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web_runtime" {
  name = "${var.project_name}-web-runtime-profile"
  role = aws_iam_role.web_runtime.name
  tags = merge(local.tags, { Name = "${var.project_name}-web-runtime-profile", Role = "web-runtime" })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "web_runtime_secret_read" {
  name = "${var.project_name}-runtime-secret-read"
  role = aws_iam_role.web_runtime.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadRuntimeSecureString", Effect = "Allow", Action = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.demo_api_token_parameter_name}"
      },
      {
        Sid      = "ReadRuntimeSecret", Effect = "Allow", Action = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.demo_app_secret_name}-??????"
      },
    ]
  })
}
