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

resource "aws_eip" "eip" {
  instance = aws_instance.web.id
  vpc      = true
}

data "aws_subnet" "selected" {
  filter {
    name   = "tag:Name"
    values = ["delete-me-publicly"]
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
    instance_ip = aws_eip.eip.public_ip
    script      = md5(join("-", local.docker_provision_script))
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host        = aws_eip.eip.public_ip
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

resource "aws_ecs_cluster" "main" {
  name = "example-cluster"
}

resource "aws_ecs_task_definition" "hello_world" {
  family                   = "web-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  container_definitions    = <<DEFINITION
  [
  {
    "image": "public.ecr.aws/l2r0j2v4/hello-world",
    "cpu": 0,
    "memory": 2048,
    "name": "web-server",
    "portMappings": [
      {
        "name":"web-server-8000-tcp",
            "containerPort":8000,
            "hostPort":8000,
            "protocol":"tcp",
            "appProtocol":"http"
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_task_definition" "jenkins" {
  family                   = "jenkins"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  task_role_arn            = "arn:aws:iam::482720962971:role/ecsTaskExecutionRole"
  execution_role_arn       = "arn:aws:iam::482720962971:role/ecsTaskExecutionRole"
  volume {
    name = "jenkins-fs"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.jenkins_fs.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.test.id
        iam             = "ENABLED"
      }
    }
  }
  /**"command": [
            "echo '================================================'\n ls -al /var/jenkins_home\n echo '================================================'\n chown -R 1000:1000 /var/jenkins_home\n ls -al /var/jenkins_home \n sleep 600 \n"
    ],
    "entryPoint": [
            "sh",
            "-c"
    ],*/
  container_definitions = <<DEFINITION
  [
  {
    
    "image": "public.ecr.aws/l2r0j2v4/jenkins",
    "cpu": 0,
    "memory": 2048,
    "name": "jenkins",
    "mountPoints": [
                {
                    "containerPath": "/var/jenkins_home",
                    "readOnly": false,
                    "sourceVolume": "jenkins-fs"
                }
    ],
    "volumes": [
        {
            "name": "jenkins-fs",
            "efsVolumeConfiguration": {
                "fileSystemId": "${aws_efs_file_system.jenkins_fs.id}",
                "rootDirectory": "/",
                "transitEncryption": "ENABLED"
            }
        }
    ],            
    "portMappings": [
      {
        "name":"jenkins-8080-tcp",
            "containerPort":8080,
            "hostPort":8080,
            "protocol":"tcp",
            "appProtocol":"http"
      }
    ],
    "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/delete_me",
                    "awslogs-region": "us-east-2",
                    "awslogs-stream-prefix": "ecs"
                }
            }
  }
]
DEFINITION
}

resource "aws_ecs_service" "hello_world" {
  name            = "terraform-dummy-webserver"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.hello_world.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [data.aws_security_group.selected.id]
    subnets         = ["subnet-0bb70a8a551169bfb", "subnet-0e0fe6858a8cc2b48"] //get rid of hardcode
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hello_world.id
    container_name   = "web-server"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.hello_world]
}

resource "aws_ecs_service" "jen_serv" {
  name            = "terraform-jenkins"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.jenkins.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [data.aws_security_group.selected.id]
    subnets         = ["subnet-0bb70a8a551169bfb", "subnet-0e0fe6858a8cc2b48"] //get rid of hardcode
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jenkins.id
    container_name   = "jenkins"
    container_port   = 8080
  }


  depends_on = [aws_lb_listener.hello_world]
}

/*data "aws_lb_listener" "hello_world" {
  load_balancer_arn = "arn:aws:elasticloadbalancing:us-east-2:482720962971:loadbalancer/app/example-lb/4e23835ce2847919"
  port              = 80
}*/

resource "aws_lb_listener" "hello_world" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

resource "aws_lb_listener_rule" "hello-world" {
  listener_arn = aws_lb_listener.hello_world.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello_world.arn
  }

  condition {
    path_pattern {
      values = ["/secret"]
    }
  }

}

resource "aws_lb_listener_rule" "jenkins" {
  listener_arn = aws_lb_listener.hello_world.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

}


# data "aws_subnets" "public_subnet" {
#   filter {
#     name   = "tag:terTag"
#     values = ["t1"]
#   }
# }

# data "aws_subnets" "private_subnet" {
#   filter {
#     name   = "tag:Avail"
#     values = ["private"]
#   }
# }

data "aws_security_group" "selected" {
  id = "sg-00a6e6a23c551b4bb"
}

resource "aws_security_group_rule" "jenkins" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.selected.id
}

resource "aws_security_group_rule" "efs" {
  type              = "ingress"
  from_port         = 2999
  to_port           = 2999
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.selected.id
}

resource "aws_security_group_rule" "efs1" {
  security_group_id = data.aws_security_group.selected.id
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "efs2" {
  security_group_id = data.aws_security_group.selected.id
  type              = "egress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "efs3" {
  security_group_id = data.aws_security_group.selected.id
  type              = "egress"
  from_port         = 2999
  to_port           = 2999
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb" "test" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.selected.id]
  subnets            = ["subnet-099fdf1b99f7b24e7", "subnet-0b5d1f1f7d9c68acc"] //[data.aws_subnets.public_subnet.id] get rid of hardcode

  enable_deletion_protection = false
}
//subnet-0e0fe6858a8cc2b48
resource "aws_lb_target_group" "hello_world" {
  name        = "example-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_target_group" "jenkins" {
  name        = "example-jenkins"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  health_check {
    path                = "/login"
    unhealthy_threshold = 10
  }
}

data "aws_vpc" "default" {
  id = "vpc-04f3afa82a5a8f066"
}

//static ip address vpn
//associate_public_ip_address - (Optional) Whether to associate a public IP address with an instance in a VPC.(False)
//create aws resource eip
//associate aws eip with instance
//

/*resource "aws_efs_file_system_policy" "policy" {
  file_system_id = aws_efs_file_system.jenkins_fs.id
  policy         = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "Policy01",
    "Statement": [
        {
            "Sid": "Statement",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Resource": "${aws_efs_file_system.jenkins_fs.arn}",
            "Action": [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientRootAccess",
                "elasticfilesystem:ClientWrite"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
POLICY
}*/

resource "aws_efs_file_system" "jenkins_fs" {
  creation_token = "jenkins_fs"
  tags = {
    Name = "jenkins-fs"
  }
}

resource "aws_efs_access_point" "test" {
  file_system_id = aws_efs_file_system.jenkins_fs.id

  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/"
    creation_info {
      owner_gid   = 1000 # jenkins
      owner_uid   = 1000 # jenkins
      permissions = "755"
    }
  }
}

resource "aws_efs_mount_target" "mount-target-1" {
  file_system_id  = aws_efs_file_system.jenkins_fs.id
  subnet_id       = "subnet-0bb70a8a551169bfb"
  security_groups = [data.aws_security_group.selected.id]
}

resource "aws_efs_mount_target" "mount-target-2" {
  file_system_id  = aws_efs_file_system.jenkins_fs.id
  subnet_id       = "subnet-0e0fe6858a8cc2b48"
  security_groups = [data.aws_security_group.selected.id]
}
//subnet-099fdf1b99f7b24e7
//subnet-0b5d1f1f7d9c68acc
//загнать сабнеты в переменную и проитерировать
/*create: 
load balancer => aws_lb 
target group => aws_lb_target_group
ecs task-definition
ecs service 
esc cluster
security group => vpc
*/

/*Сделать эквивалент экшнам в дженкинсе *проверять скриптом установку терраф* 
научить дженкинс использовать фаргейт контейнер в качестве воркера для этого плагина
*агенты/воркеры дженкинс* 
ВАЖНО: добавить в аксес лист разрешение портов дженкинса
ВАЖНО: агент для подключения внутренний адрес дженкинса*/

/*
1.Запустить простой дженкинсфайл  V
2.Перевесить действие на воркер и найти логи воркера
3.Переписать гитхаб экшны
*/