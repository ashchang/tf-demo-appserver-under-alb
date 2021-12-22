module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "simple-vpc"

  cidr = "10.10.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets  = ["10.10.101.0/24", "10.10.102.0/24"]

  enable_ipv6 = false

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Owner       = "Ash"
    Environment = "sand"
  }

  vpc_tags = {
    Name = "simple-vpc"
  }
}
