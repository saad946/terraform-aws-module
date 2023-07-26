
# Create a security group for the bastion hosts
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion hosts"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create a launch configuration for the bastion hosts
resource "aws_launch_configuration" "bastion_lc" {
  name                        = "${var.cluster_name}-bastion-lc"
  image_id                    = data.aws_ami.bastion.id
  instance_type               = var.eks_jumphost_instance_type
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jump_server_profile.name
  spot_price                  = "0.01"


  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.bastion.id]

  root_block_device {
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/jumphost_user_data.sh.tpl", {
    kubectl_version = "1.23.0",
    cluster_name    = "${var.env}-${var.cluster_name}",
    jumphost_role   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/system-apps-jumphost-asg-role"
  }))

}

# Create an auto scaling group for the bastion hosts
resource "aws_autoscaling_group" "bastion_asg" {
  name                 = "${var.cluster_name}-bastion"
  min_size             = var.jumphost_min_size
  max_size             = var.jumphost_max_size
  desired_capacity     = var.jumphost_desired_capacity
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.bastion_lc.name
  vpc_zone_identifier  = data.aws_subnet_ids.public_1.ids

  tags = [
    {
      key                 = "kubernetes.io/cluster/${var.cluster_name}"
      value               = "owned"
      propagate_at_launch = true
    }
  ]
}
data "aws_ami" "bastion" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = var.cluster_name
  public_key = var.ec2-key-public-key
}

data "aws_subnet_ids" "public_1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-public-ap-southeast-1a"
  }
}

resource "aws_iam_role" "jump_server" {
  name = "system-apps-jumphost-asg-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sts:AssumeRole"
        ],
        "Principal" : {
          "Service" : [
            "ec2.amazonaws.com"
          ]
        }
      }
    ]
  })

}


# Attach the AdministratorAccess policy to jump server role
resource "aws_iam_role_policy_attachment" "jump_server_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jump_server.name
}

resource "aws_iam_role_policy_attachment" "jump_server__eksaccess" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/eksaccess"
  role       = aws_iam_role.jump_server.name
}
resource "aws_iam_role_policy_attachment" "jump_server__ekspolicy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ekspolicy"
  role       = aws_iam_role.jump_server.name
}

# Define iam instance profile for ec2 instance of the message transmission service
resource "aws_iam_instance_profile" "jump_server_profile" {
  name = "jump-server-profile"
  role = aws_iam_role.jump_server.name

}

