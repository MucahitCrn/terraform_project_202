output "websiteurl" {
    value = "http://${aws_alb.phonebook-LB.dns_name}"
}