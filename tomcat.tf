provider "aws" {
    access_key  = "${var.access_key}"
    secret_key  = "${var.secret_key}"
    region      = "${var.aws_region}"
}

resource "aws_vpc" "tomcat-vpc" {
  cidr_block = "10.0.1.0/24"
  tags = {
      Name = "Tomcat-Server-Load"
  }
}

resource "aws_internet_gateway" "public-gw" {
  vpc_id = "${aws_vpc.tomcat-vpc.id}"
}

resource "aws_route_table" "pre-prod-route-table" {
  vpc_id = "${aws_vpc.tomcat-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0" #default route
    gateway_id = "${aws_internet_gateway.public-gw.id}"
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = "${aws_internet_gateway.public-gw.id}"
  }
    tags = {
      Name ="Tomcat-Route-Table"
  }
}

resource "aws_subnet" "tomcat-subnet" {
  vpc_id     = "${aws_vpc.tomcat-vpc.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Tomcat-Web-Open"
  }
}

# 5 . Associate subnet with route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.tomcat-subnet.id
  route_table_id = aws_route_table.pre-prod-route-table.id
}

resource "aws_security_group" "devops-sec-group" {
  name        = "allow_web_traffice"
  description = "Allow web traffic"
  vpc_id      = "${aws_vpc.tomcat-vpc.id}"

  ingress {
    description = "Open Tomcat Traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = " SSH web traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = "${aws_subnet.tomcat-subnet.id}"
  private_ips     = ["10.0.1.50"]
  security_groups = ["${aws_security_group.devops-sec-group.id}"]
}

##depends on the internet gateway
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = "${aws_network_interface.web-server-nic.id}"
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.public-gw]
}

resource "aws_instance" "tomcatserver-main" {
    ami = "ami-0cff7528ff583bf9a"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "JenkinAccess"

    network_interface {
      device_index = 0
      network_interface_id =  "${aws_network_interface.web-server-nic.id}"
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo amazon-linux-extras install epel
                sudo amazon-linux-extras install epel -y
                sudo yum upgrade -y
                sudo amazon-linux-extras install java-openjdk11 -y
                cd /opt
                sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.65/bin/apache-tomcat-9.0.65.tar.gz
                sudo tar -xvzf apache-tomcat-9.0.65.tar.gz
                sudo mv "apache-tomcat-9.0.65" tomcat
                cd /opt/tomcat/bin
                sudo ./startup.sh
                ps -ef | grep tomcat > /root/tomcat_start.log
                EOF
    tags = {

      ## /usr/lib/jvm/java-11-openjdk-11.0.13.0.8-1.amzn2.0.3.x86_64

        Name = "Tomcat-Server-Nera"
    }
}






# 1 . Create a vpc
# 2 . Create IGN
# 3 . Create Custom Route Table
# 4 . Create a Subnet
# 5 . Associate subnet with route Table
# 6 . Create security group to allow port 22,443, 80
# 7 . Create a network interface with an IP in the subnet that was created in step 4
# 8 . Assign an elastic IP to the network interface created in step 7
# 9 . Create Ubuntu server and install apache 2 