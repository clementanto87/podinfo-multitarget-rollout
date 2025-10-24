output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.http.id
}

output "invoke_url" {
  description = "API Gateway invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_apigatewayv2_api.http.execution_arn
}