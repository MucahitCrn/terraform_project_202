
data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

data "aws_ami" "amazon-linux-2" {
    owners = ["amazon"]
    most_recent = true
    filter {
        name   = "name"
        values = ["amzn2-ami-kernel-5.10*"]
  }
}

resource "aws_launch_template" "AWS-LT" {
    name = "phonebook-lt"
    image_id = data.aws_ami.amazon-linux-2.id
    instance_type = "t2.micro"
    key_name = "write-here-keyname"
    vpc_security_group_ids = [aws_security_group.server-sg.id]
    user_data = filebase64("${abspath(path.module)}/user-data.sh")
    depends_on = [github_repository_file.dbendpoint]

    tag_specifications {
      resource_type = "instance"
    
      tags = {
        Name = "Phonebook-app"
    } 
  } 
}

resource "aws_alb_target_group" "AWS-TG" {
    name = "phonebook-lb-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default_vpc.id
    target_type = "instance"

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 3
    }  
}

resource "aws_alb" "phonebook-LB" {
    name = "phonebook-lb-tf"
    ip_address_type = "ipv4"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb-sg.id]
    subnets = data.aws_subnets.subnets.ids
}


resource "aws_alb_listener" "phonebook-LISTENER" {
    load_balancer_arn = aws_alb.phonebook-LB.arn
    port = 80
    protocol = "HTTP"
    default_action {
      type = "forward"
      target_group_arn = aws_alb_target_group.AWS-TG.arn
    }
}

resource "aws_autoscaling_group" "phonebook-ASG" {
    max_size = 3
    min_size = 1
    desired_capacity = 1
    name = "phonebook-ASG"
    health_check_grace_period = 100
    health_check_type = "ELB"
    target_group_arns = [aws_alb_target_group.AWS-TG.arn]
    vpc_zone_identifier = aws_alb.phonebook-LB.subnets
    launch_template {
      id = aws_launch_template.AWS-LT.id
      version = aws_launch_template.AWS-LT.latest_version
    }
}


resource "aws_db_instance" "db_server" {
  instance_class = "db.t2.micro"
  allocated_storage = 20
  vpc_security_group_ids = [aws_security_group.db-sg.id]
  allow_major_version_upgrade = false
  auto_minor_version_upgrade = true
  backup_retention_period = 0
  identifier = "phonebook-db"
  name = "phonebook"
  engine = "mysql"
  engine_version = "8.0.23"
  username = "admin"
  password = "write-here-password"
  monitoring_interval = 0
  multi_az = false
  port = 3306
  publicly_accessible = false
  skip_final_snapshot = true
}

resource "github_repository_file" "dbendpoint" {
  content = aws_db_instance.db_server.address
  file = "dbserver.endpoint"
  repository = "phonebook"
  overwrite_on_create = true
  branch = "main"
}