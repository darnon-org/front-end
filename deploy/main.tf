provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_security_group" "k8s-security-group" {
  name        = "md-k8s-security-group"
  description = "allow all internal traffic, ssh, http from anywhere"
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30002
    to_port     = 30002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 31601
    to_port     = 31601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    yor_trace = "d32a6297-1d53-4b26-8576-d4845d869c7d"
  }
}

resource "aws_instance" "ci-sockshop-k8s-master" {
  instance_type   = "${var.master_instance_type}"
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.k8s-security-group.name}"]
  tags {
    Name = "ci-sockshop-k8s-master"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    source      = "deploy/kubernetes/manifests"
    destination = "/tmp/"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "sudo echo \"deb http://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni"
    ]
  }
  tags = {
    yor_trace = "ac15a45a-8c8f-46c3-a2d1-135595d5ab2b"
  }
}

resource "aws_instance" "ci-sockshop-k8s-node" {
  instance_type   = "${var.node_instance_type}"
  count           = "${var.node_count}"
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.k8s-security-group.name}"]
  tags {
    Name = "ci-sockshop-k8s-node"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "sudo echo \"deb http://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni",
      "sudo sysctl -w vm.max_map_count=262144"
    ]
  }
  tags = {
    yor_trace = "972b7516-0d74-43c1-af61-8aadd4a73e19"
  }
}

resource "aws_elb" "ci-sockshop-k8s-elb" {
  depends_on         = ["aws_instance.ci-sockshop-k8s-node"]
  name               = "ci-sockshop-k8s-elb"
  instances          = ["${aws_instance.ci-sockshop-k8s-node.*.id}"]
  availability_zones = ["${data.aws_availability_zones.available.names}"]
  security_groups    = ["${aws_security_group.k8s-security-group.id}"]
  listener {
    lb_port           = 80
    instance_port     = 30001
    lb_protocol       = "http"
    instance_protocol = "http"
  }

  listener {
    lb_port           = 9411
    instance_port     = 30002
    lb_protocol       = "http"
    instance_protocol = "http"
  }

  tags = {
    yor_trace = "803bc9b3-4ffd-46f3-897b-6856c23da4e1"
  }
}

