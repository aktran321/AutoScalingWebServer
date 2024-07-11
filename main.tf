module "autoscaling_web_server" {
  source = "./AutoScalingWebServer"
}

module "df"{
  source = "./Docker-Fargate"
}