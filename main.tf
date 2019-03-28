# API Role
resource "aws_iam_role" "HelloWorld_api_role" {
  name = "HelloWorld_api_role"
  assume_role_policy = "${file("policies/lambda-role.json")}"
}

# Lambda code
data "archive_file" "lambda" {
  type = "zip"
  source_dir = "./py"
  output_path = "lambda.zip"
}
# Lambda Function
resource "aws_lambda_function" "HelloWorld_function" {
  filename = "${data.archive_file.lambda.output_path}"
  function_name = "HelloWorld_function"
  role = "${aws_iam_role.HelloWorld_api_role.arn}"
  handler = "${var.handler}"
  runtime = "python2.7"
  source_code_hash = "${base64sha256(file("${data.archive_file.lambda.output_path}"))}"
  publish = true
}

# Lambda permission
resource "aws_lambda_permission" "allow_api_gateway" {
  function_name = "${aws_lambda_function.HelloWorld_function.arn}"
  statement_id = "AllowExecutionFromApiGateway"
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.HelloWorld_api.id}/*/*}"
}

# API Gateway resources
resource "aws_api_gateway_rest_api" "HelloWorld_api" {
  name        = "HelloWorld_api"
  description = "HelloWorld_api API Gateway"
  body        = "${data.template_file.HelloWorld_api_swagger.rendered}"
}

data "template_file" HelloWorld_api_swagger{
  template = "${file("swagger.yaml")}"
}

resource "aws_api_gateway_usage_plan" "HelloWorld_u_plan" {
  name = "HelloWorld_u_plan"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.HelloWorld_api.id}"
    stage  = "${aws_api_gateway_deployment.HelloWorld_deployment_prod.stage_name}"
  }
}
resource "aws_api_gateway_usage_plan_key" "HelloWorld_u_plan_key" {
  key_id        = "${aws_api_gateway_api_key.HelloWorld-api-prod-key.id}"
  key_type      = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.HelloWorld_u_plan.id}"
}

resource "aws_api_gateway_api_key" "HelloWorld-api-prod-key" {
  name = "HelloWorld-api-prod-key"
}

resource "aws_api_gateway_deployment" "HelloWorld_deployment_prod" {
 # depends_on = [
 #   "aws_api_gateway_method.HelloWorld_api_method",
 #   "aws_api_gateway_integration.HelloWorld_api_method-integration","aws_lambda_function.HelloWorld_function"
 # ]
  rest_api_id = "${aws_api_gateway_rest_api.HelloWorld_api.id}"
  stage_name = "api"
}

resource "aws_cloudfront_distribution" "HelloWorld_cloudfront" {
  depends_on = ["aws_lambda_function.HelloWorld_function"]
  enabled  = true
  #aliases  = ["${var.HelloWorld_domain}"]
  origin {
    origin_id   = "origin-api-${aws_api_gateway_deployment.HelloWorld_deployment_prod.rest_api_id }"
    domain_name = "${aws_api_gateway_deployment.HelloWorld_deployment_prod.rest_api_id}.execute-api.${var.region}.amazonaws.com"
    origin_path = "/api/messages"

    custom_origin_config {
      origin_protocol_policy = "https-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1","TLSv1.1","TLSv1.2"]
    }
     custom_header {
       name = "x-api-key"
       value = "${aws_api_gateway_api_key.HelloWorld-api-prod-key.value}"
     }
  }
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-api-${aws_api_gateway_deployment.HelloWorld_deployment_prod.rest_api_id }"
  
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    #viewer_protocol_policy = "redirect-to-https"
    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  ordered_cache_behavior {
    path_pattern     = "api*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-api-${aws_api_gateway_deployment.HelloWorld_deployment_prod.rest_api_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
    #acm_certificate_arn            = "${aws_acm_certificate_validation.short_url_domain_cert.certificate_arn}"
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.1_2016"
  }
}


output "Prod API Key" {
  value = "${aws_api_gateway_api_key.HelloWorld-api-prod-key.value}"
}

output "prod_url" {
  value = "https://${aws_api_gateway_deployment.HelloWorld_deployment_prod.rest_api_id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.HelloWorld_deployment_prod.stage_name}/messages"
}
