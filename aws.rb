require 'aws-sdk-core'

def configure_ruby_llm_aws(config)
  credential_chain = Aws::CredentialProviderChain.new.resolve
  credentials = credential_chain.credentials
  config.bedrock_api_key = credentials.access_key_id
  config.bedrock_secret_key = credentials.secret_access_key
  config.bedrock_region = ENV.fetch("AWS_REGION", "us-west-2")
  config.bedrock_session_token = credentials.session_token
end
