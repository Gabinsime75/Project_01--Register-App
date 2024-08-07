# Define environments
locals {
  environments = ["dev", "staging", "prod"]
}

variable "vpc_ids" {
  description = "List of VPC IDs for each environment"
  type        = map(string)
  default = {
    dev     = "vpc-059d4b31f1de1190d"
    staging = "vpc-0947844a078ae4993"
    prod    = "vpc-003d2d7e6751f34bc"
  }
}

variable "subnet_ids" {
  description = "Map of subnet IDs for each environment"
  type        = map(list(string))
  default = {
    dev     = ["subnet-0f0d253cdf1976b2d", "subnet-0f6538a966c357210", "subnet-0b4ea204d6b368bdd"]
    staging = ["subnet-0689c037daf15f1f3", "subnet-07c34c488ab608d5b", "subnet-004d394ab2cc45aa6"]
    prod    = ["subnet-0aea028f6c00994ba", "subnet-0db5d1f7b0ac3ca26", "subnet-0818fe97f3223e3f0"]
  }
}

# IAM Policy Document for EKS Cluster Role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  for_each           = toset(local.environments)
  name               = "${each.key}-eks-cluster-cloud"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach EKS Cluster Policy to IAM Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  for_each   = toset(local.environments)
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role[each.key].name
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  for_each = toset(local.environments)
  name     = "${each.key}-EKS_CLOUD"
  role_arn = aws_iam_role.eks_cluster_role[each.key].arn

  vpc_config {
    subnet_ids = var.subnet_ids[each.key]
  }
}

# IAM Role for Node Group
resource "aws_iam_role" "node_group_role" {
  for_each = toset(local.environments)
  name     = "${each.key}-eks-node-group-cloud"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Attach necessary policies to the node group role
resource "aws_iam_role_policy_attachment" "worker_node_policy_attachment" {
  for_each   = toset(local.environments)
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role[each.key].name
}

resource "aws_iam_role_policy_attachment" "cni_policy_attachment" {
  for_each   = toset(local.environments)
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role[each.key].name
}

resource "aws_iam_role_policy_attachment" "registry_read_only_policy_attachment" {
  for_each   = toset(local.environments)
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role[each.key].name
}

# Launch Configuration
resource "aws_launch_configuration" "node_group" {
  for_each      = toset(local.environments)
  name          = "${each.key}-launch-configuration"
  image_id      = "ami-04a81a99f5ec58529" # Replace with a valid AMI ID
  instance_type = "t2.medium"
}

# Auto Scaling Group
resource "aws_autoscaling_group" "node_group" {
  for_each             = toset(local.environments)
  launch_configuration = aws_launch_configuration.node_group[each.key].id
  min_size             = 1
  max_size             = 3
  desired_capacity     = 2
  vpc_zone_identifier  = var.subnet_ids[each.key]

  tag {
    key                 = "Name"
    value               = "${each.key}-node-group"
    propagate_at_launch = true
  }
}

# Create Node Group
resource "aws_eks_node_group" "node_group" {
  for_each        = toset(local.environments)
  cluster_name    = aws_eks_cluster.eks_cluster[each.key].name
  node_group_name = "${each.key}-Node-cloud"
  node_role_arn   = aws_iam_role.node_group_role[each.key].arn
  subnet_ids      = var.subnet_ids[each.key]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  instance_types = ["t2.medium"]
}

# Auto Scaling Policy for scale out
resource "aws_autoscaling_policy" "scale_out" {
  for_each               = toset(local.environments)
  name                   = "${each.key}-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.node_group[each.key].name
}

# Auto Scaling Policy for scale in
resource "aws_autoscaling_policy" "scale_in" {
  for_each               = toset(local.environments)
  name                   = "${each.key}-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.node_group[each.key].name
}

# CloudWatch Alarm for CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  for_each            = toset(local.environments)
  alarm_name          = "${each.key}-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.node_group[each.key].name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out[each.key].arn]
  ok_actions    = [aws_autoscaling_policy.scale_in[each.key].arn]
}

# CloudWatch Alarm for Memory Utilization
resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  for_each            = toset(local.environments)
  alarm_name          = "${each.key}-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors EC2 memory utilization"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.node_group[each.key].name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out[each.key].arn]
  ok_actions    = [aws_autoscaling_policy.scale_in[each.key].arn]
}
