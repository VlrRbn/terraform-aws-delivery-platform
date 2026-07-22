#--- Derived subnet maps and helper lists ---
locals {
  az_letters = ["a", "b", "c", "d", "e", "f"]
  azs        = var.availability_zones

  public_subnet_map = {
    for idx, cidr in var.public_subnet_cidrs :
    local.az_letters[idx] => { cidr = cidr, az = var.availability_zones[idx] }
  }

  private_subnet_map = {
    for idx, cidr in var.private_subnet_cidrs :
    local.az_letters[idx] => { cidr = cidr, az = var.availability_zones[idx] }
  }

  private_subnet_ids = [
    for key in sort(keys(aws_subnet.private_subnet)) :
    aws_subnet.private_subnet[key].id
  ]

  private_endpoint_services = toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
    "secretsmanager",
    "sts",
  ])

  required_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "delivery-platform"
  }

  # Required tags come last so callers can add metadata but cannot override governance tags.
  tags = merge(var.common_tags, local.required_tags)
}
