resource "aws_key_pair" "jmckinnie_key" {
  key_name   = "jmckinnie-key"
  public_key = file("${path.module}/jmckinnie.pub")

  tags = {
    Name = "jmckinnie-key"
  }
}

resource "aws_vpc" "k8s" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "k8s"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.k8s.id
  cidr_block              = "10.0.1.0/28" // 16 -5 = 11 addresses total
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "public-k8s"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.k8s.id
  availability_zone = local.availability_zone
  cidr_block        = "10.0.10.0/27" // 32 -5 = 27 addresses total
  tags = {
    Name = "private-k8s"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s.id

  tags = {
    Name = "k8s-inet-gw"
  }
}

resource "aws_eip" "natgw" {
  domain = "vpc"

  tags = {
    Name = "k8s-nat-eip"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.natgw.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "k8s-natgw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "default-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "kubeadm-private_rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion"
  vpc_id      = aws_vpc.k8s.id

  ingress {
    description = "SSH from my house only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.src_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_security_group" "control_plane" {
  name        = "k8s-control-plane-sg"
  description = "Security group for Kubernetes control plane"
  vpc_id      = aws_vpc.k8s.id

  # SSH from bastion
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Kubernetes API server
  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  # etcd server client API
  ingress {
    description = "etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  # Kubelet API
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  # kube-scheduler
  ingress {
    description = "kube-scheduler"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    self        = true
  }

  # kube-controller-manager
  ingress {
    description = "kube-controller-manager"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-control-plane-sg"
  }
}

resource "aws_security_group" "worker" {
  name        = "k8s-worker-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = aws_vpc.k8s.id

  # SSH from bastion
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Kubelet API
  ingress {
    description     = "Kubelet API from control plane"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.control_plane.id]
  }

  # NodePort Services
  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  # Pod-to-pod communication
  ingress {
    description = "Pod network"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow communication from control plane
  ingress {
    description     = "All from control plane"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.control_plane.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-worker-sg"
  }
}

resource "aws_instance" "bastion" {
  ami                    = local.ami
  instance_type          = "c6gd.medium"
  key_name               = aws_key_pair.jmckinnie_key.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options { http_tokens = "required" }

  tags = {
    Name = "k8s-bastion"
  }
}

resource "aws_instance" "control_plane" {
  ami                    = local.ami
  instance_type          = "c6gd.large"
  key_name               = aws_key_pair.jmckinnie_key.key_name
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.control_plane.id]
  iam_instance_profile   = aws_iam_instance_profile.control_plane.name

  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  metadata_options { http_tokens = "required" }

  tags = {
    Name = "k8s-control-plane"
  }
}


resource "aws_instance" "worker" {
  count                  = 3
  ami                    = local.ami
  instance_type          = "c6gd.large"
  key_name               = aws_key_pair.jmckinnie_key.key_name
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.worker.id]
  iam_instance_profile   = aws_iam_instance_profile.worker.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options { http_tokens = "required" }

  tags = {
    Name = "worker-${count.index}"
  }
}

resource "aws_iam_role" "control_plane" {
  name = "k8s-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "k8s-control-plane-role"
  }
}

resource "aws_iam_role" "worker" {
  name = "k8s-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "k8s-worker-role"
  }
}

resource "aws_iam_role_policy" "control_plane" {
  name = "k8s-control-plane-policy"
  role = aws_iam_role.control_plane.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [ // todo: narrow this down
          "ec2:*",
          "elasticloadbalancing:*",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker" {
  name = "k8s-worker-policy"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeVolumesModifications",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "us-east-1"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:us-east-1:*:volume/*",
          "arn:aws:ec2:us-east-1:*:snapshot/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "control_plane" {
  name = "k8s-control-plane-profile"
  role = aws_iam_role.control_plane.name

  tags = {
    Name = "k8s-control-plane-profile"
  }
}

resource "aws_iam_instance_profile" "worker" {
  name = "k8s-worker-profile"
  role = aws_iam_role.worker.name

  tags = {
    Name = "k8s-worker-profile"
  }
}
