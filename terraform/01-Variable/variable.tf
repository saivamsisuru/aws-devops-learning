resource "aws_security_group" "mysg" {
    name = "terraform-sg"
    description = "creating from terraform"
    ingress {
        from_port = 22
        To_port = 22
        Protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}