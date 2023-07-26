terraform {
  backend "s3" {
    bucket = "preprod-apps-982291412478"
    key    = "preprod-apps.tfstate"
    region = "ap-southeast-1"
  }
}
