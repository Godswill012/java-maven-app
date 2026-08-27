terraform {
  backend "s3" {
    bucket       = "josep-myapp-tf-state-2026"
    key          = "myapp/state.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
