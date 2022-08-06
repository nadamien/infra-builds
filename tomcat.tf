resource "aws_vpc" "tomcat-vpc" {
  cidr_block = "10.0.2.0/24"
  tags = {
      Name = "Tomcat-Server-Connect"
  }
}

resource "aws_internet_gateway" "public-gw-tomcat" {
  vpc_id = "${aws_vpc.tomcat-vpc.id}"
}

resource "aws_route_table" "route-for-tomcat" {
  vpc_id = "${aws_vpc.tomcat-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0" #default route
    gateway_id = "${aws_internet_gateway.public-gw-tomcat.id}"
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = "${aws_internet_gateway.public-gw-tomcat.id}"
  }
    tags = {
      Name ="Tomcat-Route-Table"
  }
}

resource "aws_subnet" "tomcat-subnet" {
  vpc_id     = "${aws_vpc.tomcat-vpc.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Tomcat-Web-Open"
  }
}

# 5 . Associate subnet with route Table

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.tomcat-subnet.id
  route_table_id = aws_route_table.route-for-tomcat.id
}

resource "aws_security_group" "devops-sec-group" {
  name        = "devops-sec-group"
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
    Name = "devops-sec-group"
  }
}

resource "aws_network_interface" "tomcat-nic" {
  subnet_id       = "${aws_subnet.tomcat-subnet.id}"
  private_ips     = ["10.0.2.60"]
  security_groups = ["${aws_security_group.devops-sec-group.id}"]
}

##depends on the internet gateway
resource "aws_eip" "two" {
  vpc                       = true
  network_interface         = "${aws_network_interface.tomcat-nic.id}"
  associate_with_private_ip = "10.0.2.60"
  depends_on = [aws_internet_gateway.public-gw-tomcat]
}

resource "aws_instance" "tomcatserver-main" {
    ami = "ami-0cff7528ff583bf9a"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "JenkinAccess"

    network_interface {
      device_index = 0
      network_interface_id =  "${aws_network_interface.tomcat-nic.id}"
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
                chmod +x /opt/tomcat/bin/startup.sh
                chmod +x /opt/tomcat/bin/shutdown.sh
                ##create softlinks for up/down
                ln -s /opt/tomcat/bin/startup.sh /usr/local/bin/tomcatup
                ln -s /opt/tomcat/bin/shutdown.sh /usr/local/bin/tomcatdown
                ##tomcat softlink test
                tomcatup > /root/tomcat_start_stop.log && ps -ef | grep tomcat >> /root/tomcat_start_stop.log
                tomcatdown > /root/tomcat_start_stop.log && ps -ef | grep tomcat >> /root/tomcat_start_stop.log
                tomcatup > /root/tomcat_start.log && ps -ef | grep tomcat >> /root/tomcat_start.log

                sudo mv /tmp/context_updated.xml /opt/tomcat/webapps/host-manager/META-INF/context.xml
                sudo mv /tmp/context_updated_meta.xml /opt/tomcat/webapps/manager/META-INF/context.xml
                sudo mv /tmp/tomcat-users_updated.xml /opt/tomcat/conf/tomcat-users.xml

                tomcatdown > /root/tomcat_start_stop.log && ps -ef | grep tomcat >> /root/tomcat_start_stop.log
                tomcatup > /root/tomcat_start.log && ps -ef | grep tomcat >> /root/tomcat_start.log

                EOF
    tags = {

      ## /usr/lib/jvm/java-11-openjdk-11.0.13.0.8-1.amzn2.0.3.x86_64

        Name = "Tomcat-Server-Nera"
    }
}


resource "null_resource" "copyfiles" {
  
    connection {
    type = "ssh"
    host = aws_instance.tomcatserver-main.public_ip
    user = "ec2-user"
    private_key = file("JenkinAccess.pem")
    }
  
  provisioner "file" {
    source      = "/Users/pasindu/ci-cd/main-proj/conf-tc/context_updated_meta.xml"
    destination = "/tmp/context_updated_meta.xml"
  }

    provisioner "file" {
    source      = "/Users/pasindu/ci-cd/main-proj/conf-tc/context_updated.xml"
    destination = "/tmp/context_updated.xml"
  }

    provisioner "file" {
    source      = "/Users/pasindu/ci-cd/main-proj/conf-tc/tomcat-users_updated.xml"
    destination = "/tmp/tomcat-users_updated.xml"
  }
  
  depends_on = [ aws_instance.tomcatserver-main ]
  
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