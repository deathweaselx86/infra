resource "aws_key_pair" "jmckinnie_key" {
  key_name   = "jmckinnie-key"
  public_key = file("~/.ssh/id_ed25519.pub")

  tags = {
    Name = "jmckinnie-key"
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

  metadata_options {
    http_tokens = "required"
  }

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
  user_data              = data.local_file.cloudinit.content

  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

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
  user_data              = data.local_file.cloudinit.content

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "worker-${count.index}"
  }
}

resource "aws_instance" "burstable_worker" {
  count                  = 1
  ami                    = local.burstable_ami
  instance_type          = "t3.large"
  key_name               = aws_key_pair.jmckinnie_key.key_name
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.worker.id]
  iam_instance_profile   = aws_iam_instance_profile.burstable_worker.name
  user_data              = data.local_file.cloudinit.content

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "burstable-worker-${count.index}"
  }
}
