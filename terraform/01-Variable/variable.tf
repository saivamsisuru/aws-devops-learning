resource "aws_security_group" "mysg" {
    name = "terraform-sg"
    description = "creating from terraform"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}