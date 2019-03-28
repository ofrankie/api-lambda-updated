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
  description = "API Gateway for ##workspace_name## version of de-secure-api-gateway"
  body        = "${data.template_file.HelloWorld_api_swagger.rendered}"
}

data "template_file" HelloWorld_api_swagger{
  template = "${file("swagger.yaml")}"
}

resource "aws_api_gateway_usage_plan" "HelloWorld_u_plan" {
  name = "HelloWorld_u_plan"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.aws_api_gateway_rest_api.HelloWorld_api.id}"
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



output "Prod API Key" {
  value = "${aws_api_gateway_api_key.HelloWorld-api-prod-key.value}"
}

output "prod_url" {
  value = "https://${aws_api_gateway_deployment.HelloWorld_deployment_prod.rest_api_id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.HelloWorld_deployment_prod.stage_name}/messages"
}
