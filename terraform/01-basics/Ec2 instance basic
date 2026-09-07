provider "aws" {
  region = "ap-south-1"
}
resource "aws_instance" "my_instance" {
  tags = {
    Name        = "practice1-terraform"
    environment = "Dev"
  }
  ami           = "ami-090d68841c2a28756"
  instance_type = "t3.micro"
}
