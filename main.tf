data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  owners = ["979382823631"] # Bitnami
}

/*
data "aws_vpc" "default" {
  default = true
}
*/

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] # removing the private subnets as per the course notes causes an error in the module. it expects to find a route table for private subnets if nat gateway is set true
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  

  tags = {
    Terraform = "true" 
    Environment = "dev"
  }
}


resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  # vpc_security_group_ids = [aws_security_group.blog.id]
  vpc_security_group_ids = [module.blog_sg.security_group_id]

  tags = {
    Name = "Learning Terraform"
  }
}


module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "blog-alb"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = module.blog_sg.security_group_id

  target_groups = [
    {
      name_prefix      = "blog-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      targets = {
        my_target = {
          target_id = aws_instance.blog.id
          port = 80
        } 
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}


module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.2"
  name    = "blog_new"
  
  #vpc_id  = data.aws_vpc.default.id
  vpc_id  = module.vpc.public_subnets[0]
  
  ingress_rules       = [ "http-80-tcp", "https-443-tcp" ]
  ingress_cidr_blocks = [ "0.0.0.0/0" ]
  
  egress_rules       = [ "all-all" ]
  egress_cidr_blocks = [ "0.0.0.0/0" ]
}