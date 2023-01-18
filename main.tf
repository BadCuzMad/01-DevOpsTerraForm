resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "knm_default_terraform_key"
  //subnet_id                   = "subnet-08cc83fbae517191c"
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = ["sg-0544ee87deea6c46d"]
  associate_public_ip_address = "true"

  user_data = file("script.sh")
  tags = {
    Name = "RemoteTF"
  }
}

data "aws_subnet" "selected" {
  filter {
    name   = "tag:Name"
    values = ["public"]
  }
}

locals {
  docker_provision_script = [
    "TIMEOUT=20",
    "TIME_SPENT=0",
    "echo \"debug\"",
    "set -x",
    "until docker ps ; do",
    "sleep 5",
    "echo \"debug 2 $TIMEOUT $TIME_SPENT\"",
    "TIME_SPENT=`expr $TIME_SPENT + 5`",
    "echo \"debug 3 $TIMEOUT $TIME_SPENT\"",
    "echo \"WAITING $TIME_SPENT seconds\"",
    "if [ $TIME_SPENT -ge $TIMEOUT ]; then",
    "echo \"ERROR: TIMEOUT EXCEEDED\"",
    "exit 100;",
    "fi;",
    "done;",
  "echo \"debug 4 finish\"",
  "docker stop ipsec-vpn-server",
  "docker rm ipsec-vpn-server",
  "docker run --name ipsec-vpn-server --restart=always -v ikev2-vpn-data:/etc/ipsec.d -v /lib/modules:/lib/modules:ro -p 500:500/udp -p 4500:4500/udp -d --privileged hwdsl2/ipsec-vpn-server",
  "sleep 15",
  "docker logs ipsec-vpn-server"]
}


resource "null_resource" "launch_docker" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_ip = aws_instance.web.public_ip
    script      = md5(join("-", local.docker_provision_script))
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host        = aws_instance.web.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.default_ssh_key //file("/home/knmalyshev/.ssh/id_rsa")

  }

  provisioner "remote-exec" {
    inline = local.docker_provision_script
  }
  //allow_missing_exit_status = true
}

/*resource "aws_vpc" "my_vpc" {
  cidr_block = "10.92.0.0/24"
  tags = {
    Name = "tf-example"
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_subnet" "my_subnet_private" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.92.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "private"
  }
}
*/

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

