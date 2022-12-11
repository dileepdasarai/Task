terraform {
    required_providers {
        aws = {
         source = "hashicorp/aws"
         version = "~> 4.0"   
        }
    }
}

#configure the AWS required_provider
provider "aws" {
    region = "ap-south-1"
}

#Creating VPC & SUBNET for provider AWS
resource "aws_vpc" "my-vpc-1" {
    cidr_block = "20.21.0.0/16"
    tags = {
        Name = "VPC_Test"
    }
}

# Public subnet for the web

resource "aws_subent" "web-subnet-1" {
    vpc_id                   =  aws_vpc.my-vpc-1.id
    cidr_block               =  "20.21.1.0/24"
    availability_zone        =  "ap-south-1a"
    map_public_ip_on_launch  =  true

    tags = {
        Name = "Web-1a"
    }
}

resource "aws_subent" "web-subnet-2" {
    vpc_id                   =  aws_vpc.my-vpc-1.id
    cidr_block               =  "20.21.2.0/24"
    availability_zone        =  "ap-south-1b"
    map_public_ip_on_launch  =  true

    tags = {
        Name = "Web-2b"
    }
}

# Private subnet for the appliction

resource "aws_subnet" "application-subnet-1" {
    vpc_id                   =  aws_vpc.my-vpc-1.id
    cidr_block               =  "20.21.50.0/24"
    availability_zone        =  "ap-south-1a"
    map_public_ip_on_launch  =  false

    tags = {
        Name = "Application-1a"
    }
}

resource "aws_subnet" "applicaiton-subnet-2" {
    vpc_id                   =  aws_vpc.my-vpc-1.id
    cidr_block               =  "20.21.51.0/24"
    availability_zone        =  "ap-south-1b"
    map_public_ip_on_launch  =  false

    tags = {
        Name = "Application-2b"
    }
}

# Database private subnet
resource "aws_subnet" "database-subnet-1" {
    vpc_id                  =  aws_vpc.my-vpc-1.id
    cidr_block              =  "20.21.60.0/24"
    availability_zone       =  "ap-south-1b"

    tags = {
        Name = "Database-1a"
    }
}

resource "aws_subnet" "database-subnet-2" {
    vpc_id                  =  aws_vpc.my-vpc-1.id
    cidr_block              =  "20.21.61.0/24"
    availablity_zone        =  "ap-south-1a"

    tags = {
        Name = "Database-2b"
    }
}

# Internet Gateway for public subnet
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.my-vpc-1.id

    tags = {
        Name = "IGW"
    }
}

# routable

resource "aws_route_table" "rt-a" {
    vpc_id = aws_vpc.my-vpc-1.id

    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "Web-rt"
    }
}

#Association of subnet to the aws_route_table
resource "aws_route_table_association" "sn-rta" {
    subnet_id      =  aws_subnet.web-subnet-1.id
    route_table_id =  aws_route_table.rt-a.id
}

resoure "aws_route_table_association" "sn-rt-b" {
    subnet_id      =  aws_subnet.web-subnet-2.id
    route_table_id =  aws_route_table.rt-a.id
}

#creating EC2 instance
resource "aws_instance" "WS-1" {
    ami                     =  "ami-"
    instance_type           =  ""
    availability_zone       =  "ap-south-1a"
    vpc_secutiry_group_ids  =  [aws_security_group.webserver-sg.id]
    subnet_id               =  ws_subnet.web-subnet-1.id
    user_data               =  file(apache_metadata.sh)

    tags = {
        Name = "web Server"
    }
}

resource "aws_instance" "WS-2" {
    ami                     =  "ami-"
    instance_type           =  ""
    availability_zone       =  "ap-south-1b"
    vpc_secutiry_group_ids  =  [aws_security_group.webserver-sg.id]
    subnet_id               =  ws_subnet.web-subnet-2.id
    user_data               =  file(apache_metadata.sh)

    tags = {
        Name = "web Server"
    }
}

#web secutiry group
resource "ws_security_group" "web-sg" {
    name         =  "Web-SG"
    description  =  "Allow HTTP inbound traffic"
    vpc_id       =  aws_vpc.myvpc-1.id

    ingress {
        description =  "HTTP from VPC"
        from_port   =  80
        to_port     =  80
        protocol    =  "tcp"
        cidr_blocks =  ["0.0.0.0/0"]
    }

    egress {
        from_port   =  0
        to_port     =  0
        protocol    =  "-1"
        cidr_blocks =  ["0.0.0.0/0"]
    }

    tags = {
        Name = "Web-SG"
    }
}

# Create Webserver Secutiry group
resource "aws_security_group" "webserver-sg" {
    name         =  "Webserver-SG"
    description  =  "Allow inbound traffic from ALB"
    vpc_id       =  aws_vpc.my-vpc-1.id

    ingress {
        description =  "Allow traffic from web layer"
        from_port   =  80
        to_port     =  80
        protocol    =  "tcp"
        security_groups  [aws_security_group.web-sg.id]
    }

    egress{
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks =  ["0.0.0.0/0"]
    }

    tags{
        Name = "webserver-SG"
    }
}

# Create Database Security Group
resource "aws_security_group" "database-sg" {
    name        = "Database-SG"
    description = "Allow inbound traffic from application layer"
    vpc_id      = aws_vpc.my-vpc.id

    ingress {
        description     = "Allow traffic from application layer"
        from_port       = 3306
        to_port         = 3306
        protocol        = "tcp"
        security_groups = [aws_security_group.webserver-sg.id]
  }

    egress {
        from_port   = 32768
        to_port     = 65535
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
  }

    tags = {
        Name = "Database-SG"
  }
}
# creting application load load_balancer

resource "aws_lb" "external-elb" {
    name               = "External-LB"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.web-sg.id]
    subnets            = [aws_subnet.web-subnet-1.id, aws_subnet.web-subnet-2.id]
}

resource "aws_lb_target_group" "external-elb" {
    name     = "ALB-TG"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.my-vpc.id
}

resource "aws_lb_target_group_attachment" "external-elb1" {
    target_group_arn = aws_lb_target_group.external-elb.arn
    target_id        = aws_instance.webserver1.id
    port             = 80

    depends_on = [
        aws_instance.webserver1,
  ]
}

resource "aws_lb_target_group_attachment" "external-elb2" {
    target_group_arn = aws_lb_target_group.external-elb.arn
    target_id        = aws_instance.webserver2.id
    port             = 80

    depends_on = [
        aws_instance.webserver2,
  ]
}

resource "aws_lb_listener" "external-elb" {
    load_balancer_arn = aws_lb.external-elb.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.external-elb.arn
  }
}

#crete an required_providers

resource "aws_db_instance" "default" {
    allocated_storage      = 10
    db_subnet_group_name   = aws_db_subnet_group.default.id
    engine                 = "mysql"
    engine_version         = "8.0.20"
    instance_class         = "db.t2.micro"
    multi_az               = true
    name                   = "mydb"
    username               = "username"
    password               = "password"
    skip_final_snapshot    = true
    vpc_security_group_ids = [aws_security_group.database-sg.id]
}

resource "aws_db_subnet_group" "default" {
    name       = "main"
    subnet_ids = [aws_subnet.database-subnet-1.id, aws_subnet.database-subnet-2.id]

    tags = {
        Name = "My DB subnet group"
  }
}
#output

output "lb_dns_name" {
    description = "The DNS name of the load balancer"
    value       = aws_lb.external-elb.dns_name
}