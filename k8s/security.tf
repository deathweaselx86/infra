
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

  # VXLAN overlay network for Cilium
  ingress {
    description = "VXLAN overlay network"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
  }

  # Cilium health checks from self
  ingress {
    description = "Cilium health checks"
    from_port   = 4240
    to_port     = 4240
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

  lifecycle {
    ignore_changes = [ingress, egress]
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

  ingress {
    description = "VXLAN between worker nodes"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
  }

  # Cilium health checks between workers
  ingress {
    description = "Cilium health checks between workers"
    from_port   = 4240
    to_port     = 4240
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
    Name = "k8s-worker-sg"
  }
}

# had to split out these sg rules to avoid a cycle
resource "aws_security_group_rule" "vxlan_workers_to_cp" {
  type                     = "ingress"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.worker.id
  description              = "VXLAN from workers to control plane"
}

resource "aws_security_group_rule" "cilium_health_workers_to_cp" {
  type                     = "ingress"
  from_port                = 4240
  to_port                  = 4240
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.worker.id
  description              = "Cilium health checks from workers to control plane"
}

resource "aws_security_group_rule" "workers_to_cp_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.worker.id
  description              = "All from workers to control plane"
}
