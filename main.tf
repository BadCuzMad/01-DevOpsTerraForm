resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "another_key"
  //subnet_id                   = "subnet-08cc83fbae517191c"
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = ["sg-0e030a14de5ebaebb"]
  //associate_public_ip_address = "false" //false and change source below
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      associate_public_ip_address,
    ]
  }
  user_data = file("script.sh")
  tags = {
    Name = "RemoteTF"
  }
}



resource "aws_eip" "lb" {
  instance = aws_instance.web.id
  vpc      = true
}

data "aws_subnet" "selected" {
  filter {
    name   = "tag:Name"
    values = ["copied_subnet_knm"]
  }
}

locals {
  docker_provision_script = [
    "TIMEOUT=200",
    "TIME_SPENT=0",
    "cat /home/ubuntu/vpn.env",
    "until docker ps ; do",
    "sleep 5",
    "TIME_SPENT=`expr $TIME_SPENT + 5`",
    "echo \"WAITING $TIME_SPENT seconds\"",
    "if [ $TIME_SPENT -ge $TIMEOUT ]; then",
    "echo \"ERROR: TIMEOUT EXCEEDED\"",
    "exit 100;",
    "fi;",
    "done;",
    "docker stop ipsec-vpn-server",
    "docker rm ipsec-vpn-server",
    "docker run --name ipsec-vpn-server --env-file /home/ubuntu/vpn.env --restart=always -v ikev2-vpn-data:/etc/ipsec.d -v /lib/modules:/lib/modules:ro -p 500:500/udp -p 4500:4500/udp -d --privileged hwdsl2/ipsec-vpn-server",
    "sleep 15",
  "docker logs ipsec-vpn-server"]

  vpn_env = [
    "VPN_IPSEC_PSK=${var.ipsec_psk}",
    "VPN_USER=${var.vpn_user}",
    "VPN_PASSWORD=${var.vpn_password}"
  ]
}


resource "null_resource" "launch_docker" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = aws_instance.web.id
    instance_ip = aws_eip.lb.public_ip
    script      = md5(join("-", local.docker_provision_script))
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host        = aws_eip.lb.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.default_ssh_key //file("/home/knmalyshev/.ssh/id_rsa")

  }

  provisioner "file" {
    content     = join("\n", local.vpn_env)
    destination = "/home/ubuntu/vpn.env"
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

//static ip address vpn
//associate_public_ip_address - (Optional) Whether to associate a public IP address with an instance in a VPC.(False)
//create aws resource eip
//associate aws eip with instance
//