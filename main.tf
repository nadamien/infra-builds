provider "aws" {
    access_key  = "${var.access_key}"
    secret_key  = "${var.secret_key}"
    region      = "${var.aws_region}"
}

resource "aws_vpc" "jenkins-vpc" {
  cidr_block = "10.0.1.0/24"
  tags = {
      Name = "Jenkins-Connect"
  }
}

resource "aws_internet_gateway" "public-gw" {
  vpc_id = "${aws_vpc.jenkins-vpc.id}"
}

resource "aws_route_table" "pre-prod-route-table" {
  vpc_id = "${aws_vpc.jenkins-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0" #default route
    gateway_id = "${aws_internet_gateway.public-gw.id}"
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = "${aws_internet_gateway.public-gw.id}"
  }
    tags = {
      Name ="Pre-Prod-Route-Table"
  }
}

resource "aws_subnet" "pre-prod-subnet" {
  vpc_id     = "${aws_vpc.jenkins-vpc.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Pre-Prod-Level-Subnet"
  }
}

# 5 . Associate subnet with route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.pre-prod-subnet.id
  route_table_id = aws_route_table.pre-prod-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffice"
  description = "Allow web traffic"
  vpc_id      = "${aws_vpc.jenkins-vpc.id}"

  ingress {
    description = "Jenkins Traffic"
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
  subnet_id       = "${aws_subnet.pre-prod-subnet.id}"
  private_ips     = ["10.0.1.50"]
  security_groups = ["${aws_security_group.allow_web.id}"]
}

##depends on the internet gateway
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = "${aws_network_interface.web-server-nic.id}"
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.public-gw]
}

resource "aws_instance" "jenkins-main" {
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
                sudo apt update -y
                sudo amazon-linux-extras install epel
                sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
                sudo amazon-linux-extras install epel -y
                sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
                sudo yum upgrade -y
                sudo amazon-linux-extras install java-openjdk11 -y
                sudo yum install jenkins -y
                sudo systemctl enable jenkins
                sudo systemctl start jenkins
                sudo touch /etc/install-banner
                sudo sed -i 's/#Banner none/Banner /' /etc/ssh/sshd_config
                sudo sed -i 's|Banner| Banner /etc/install-banner|g' /etc/ssh/sshd_config
                sudo yum install git -y
                sudo echo "*************************************************************" >> /etc/install-banner
                sudo echo "Install Summary" >> /etc/install-banner
                sudo echo "Your Jenkin Server with Maven Installation is Ready" >> /etc/install-banner
                sudo echo "*************************************************************" >> /etc/install-banner
                sudo echo " " >> /etc/install-banner
                sudo git --version >> /etc/install-banner
                sudo echo " " >> /etc/install-banner
                cd /opt
                sudo wget https://dlcdn.apache.org/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz
                sudo tar -xvzf apache-maven-3.8.6-bin.tar.gz
                sudo rm apache-maven-3.8.6-bin.tar.gz
                sudo mv apache-maven-3.8.6 maven
                echo "PATH=$PATH:$HOME/bin:/usr/lib/jvm/java-11-openjdk-11.0.13.0.8-1.amzn2.0.3.x86_64:/opt/maven:/opt/maven/bin" >> ~/.bash_profile
                echo "export PATH" >> ~/.bash_profile
                source ~/.bash_profile
                sudo mvn -v >> /etc/install-banner

                EOF
    tags = {

      ## /usr/lib/jvm/java-11-openjdk-11.0.13.0.8-1.amzn2.0.3.x86_64

        Name = "Jenkin-Pipeline-Nera"
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