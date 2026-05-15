# ==========================================
# AWS Cognito User Pool
# ==========================================
resource "aws_cognito_user_pool" "main" {
  name = "cloud-design-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "cloud-design-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = ["https://api.cloud-design.local/oauth2/idpresponse"]
  logout_urls   = ["https://api.cloud-design.local/"]

  supported_identity_providers = ["COGNITO"]
}

resource "random_integer" "cognito_domain" {
  min = 100000
  max = 999999
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "cloud-design-auth-domain-${random_integer.cognito_domain.result}"
  user_pool_id = aws_cognito_user_pool.main.id
}
