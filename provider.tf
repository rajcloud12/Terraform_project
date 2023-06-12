terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"
}

#VPC 
resource "aws_vpc" "main" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "2TierArchitecture"
  }
}

#AWS instance - linux

resource "aws_instance" "web_tier1" {
  ami                         = "ami-09988af04120b3591"
  key_name                    = "Project4EC2"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public1.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.web_tier.id]
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Welcome to AWS WebTier One 2023! Powered byTerraform 
        </h1></body></html>" > /var/www/html/index.html
        EOF
}

resource "aws_instance" "web_tier2" {
  ami                         = "ami-09988af04120b3591"
  key_name                    = "Project4EC2"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public2.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.web_tier.id]
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Welcome to AWS WebTier Two 2023!!! Powered by Terrafrom 
        </h1></body></html>" > /var/www/html/index.html
        EOF
}

#create Load Balancer
resource "aws_lb" "myalb" {
  name               = "2TierApplicationLoadBalancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
  security_groups    = [aws_security_group.albsg.id]
}

#create Security group 
resource "aws_security_group" "albsg" {
  name        = "albsg"
  description = "security group for alb"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#create Target group

resource "aws_lb_target_group" "tg" {
  name     = "projecttg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  depends_on = [aws_vpc.main]
}

#attaches an EC2 instance to an Elastic Load Balancing (ELB) target group

resource "aws_lb_target_group_attachment" "tgattach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_tier1.id
  port             = 80

  depends_on = [aws_instance.web_tier1]
}

#attaches an EC2 instance to an Elastic Load Balancing (ELB) target group

resource "aws_lb_target_group_attachment" "tgattach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_tier2.id
  port             = 80

  depends_on = [aws_instance.web_tier2]
}

#Elastic Load Balancing (ELB) listener.
resource "aws_lb_listener" "listenerlb" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

#public subnets

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public2"
  }
}

#private subnets

resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private2"
  }
}

#Rational Database Service (RDS)

resource "aws_db_subnet_group" "sub_4_db" {
  name       = "sub_4_db"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
  tags = {
    Name = "My DB subnet group"
  }
}

#IGW Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "InternetGateway2023"
  }
}

#route table

resource "aws_route_table" "Web_Tier" {
  tags = {
    Name = "Web_Tier"
  }
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#associate route table with the subnet
resource "aws_route_table_association" "Web_tier" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.Web_Tier.id
}

resource "aws_route_table_association" "Web_tier2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.Web_Tier.id
}

#create another route table

resource "aws_route_table" "DabaseTier" {
  tags = {
    Name = "DatabaseTier"
  }
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#create Elastic ip
resource "aws_eip" "nat_eip" {
  vpc = true
}

#Create a NAT gateway
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public2.id
}

#creates a route table in VPC and associates it with a NAT gateway
resource "aws_route_table" "my_public2_nated" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }

  tags = {
    Name = "Main Route Table for NAT- subnet"
  }
}

#Terrafrom resource associates two subnets in VPC with a route table that is configured for NAT.

resource "aws_route_table_association" "my_public2_nated1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.my_public2_nated.id
}
resource "aws_route_table_association" "my_public2_nated2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.my_public2_nated.id
}

# Terraform resource creates a security group in an Amazon Web Services (AWS) VPC and allows inbound 
#traffic on ports 22 (SSH) and 80 (HTTP).

resource "aws_security_group" "web_tier" {
  name        = "web_tier"
  description = "web and SSH allowed"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Terraform resource creates a security group in an Amazon Web Services (AWS) VPC and allows inbound traffic 
#on port 3306 (MySQL) from the web tier security group and on port 22 (SSH) from anywhere. 

resource "aws_security_group" "db_tier" {
  name        = "Database SecurityGroup 2023"
  description = "allow traffic from Web Tier & SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["10.10.0.0/16"]
    security_groups = [aws_security_group.web_tier.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

#Terraform configuration that defines an Amazon Relational Database Service (RDS) database instance

resource "aws_db_instance" "the_db" {
  allocated_storage      = 10
  db_name                = "mydb"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  db_subnet_group_name   = aws_db_subnet_group.sub_4_db.id
  vpc_security_group_ids = [aws_security_group.db_tier.id]
  username               = "admin"
  password               = "admin"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
}
