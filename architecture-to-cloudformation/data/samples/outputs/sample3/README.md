# Output [Sample3.jpg](/architecture-to-cloudformation/util/samples/sample3.jpg)

Let’s give the application a more complicated AWS architecture diagram. 

![sample3.jpg](/architecture-to-cloudformation/data/samples/sample3.jpg)

First, let's analyze the step-by-step explanation. Anthropic Claude 3 Sonnet does an excellent job of explaining the data flow of the architecture diagram. 

![artifact-1.png](/architecture-to-cloudformation/data/samples/outputs/sample3/artifact-1.png)
 
The generated AWS CloudFormation code can be seen below.

> [!IMPORTANT]  
> The AWS CloudFormation template generated by the web application serves as a reference or starting point for development purposes. It should not be directly utilized in production environments without proper testing and validation. Developers are responsible for thoroughly evaluating and modifying the CloudFormation template to ensure compliance with established security best practices and guidelines before deploying it to production systems.

```
AWSTemplateFormatVersion: '2010-09-09'
Description: >
  This CloudFormation stack sets up a serverless data processing pipeline triggered by a scheduled event.
  It retrieves data from an S3 bucket, processes it using Lambda functions, stores the processed data in a DynamoDB table,
  and sends an email notification when the data processing is complete.
  This template is not production ready and should only be used for inspiration.
Parameters:
  S3BucketName:
    Type: String
    Description: Name of the S3 bucket containing the input data

  EmailAddress:
    Type: String
    Description: Email address to receive notifications

Resources:

  # EventBridge Schedule
  EventBridgeSchedule:
    Type: AWS::Events::Rule
    Properties:
      ScheduleExpression: 'cron(0 3 ? * MON-FRI *)'
      State: ENABLED
      Targets:
        - Arn: !GetAtt PreprocessingLambda.Arn
          Id: PreprocessingLambdaTarget

  # Lambda Function A (Preprocessing)
  PreprocessingLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: PreprocessingFunction
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt PreprocessingLambdaRole.Arn
      Code:
        ZipFile: |
          # Lambda function code to retrieve data from S3 and preprocess
          # ...

  PreprocessingLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: S3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                Resource: !Join ['', ['arn:aws:s3:::', !Ref S3BucketName, '/*']]

  # S3 Bucket B
  ProcessedDataBucket:
    Type: AWS::S3::Bucket

  # Lambda Function B (Processing)
  ProcessingLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: ProcessingFunction
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt ProcessingLambdaRole.Arn
      Code:
        ZipFile: |
          # Lambda function code to process data and store in DynamoDB
          # ...

  ProcessingLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: S3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                Resource: !Join ['', ['arn:aws:s3:::', !Ref ProcessedDataBucket, '/*']]
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'dynamodb:PutItem'
                Resource: !GetAtt DynamoDBTable.Arn

  # DynamoDB Table
  DynamoDBTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: ProcessedDataTable
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      ProvisionedThroughput:
        ReadCapacityUnits: 5
        WriteCapacityUnits: 5
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES

  # DynamoDB Stream
  DynamoDBStream:
    Type: AWS::Lambda::EventSourceMapping
    Properties:
      EventSourceArn: !GetAtt DynamoDBTable.StreamArn
      FunctionName: !GetAtt NotificationLambda.Arn
      StartingPosition: LATEST
      BatchSize: 1

  # Lambda Function (Notification)
  NotificationLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: NotificationFunction
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt NotificationLambdaRole.Arn
      Code:
        ZipFile: |
          # Lambda function code to send email notification
          # ...

  NotificationLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: SNSPublishPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'sns:Publish'
                Resource: !Ref SNSTopic

  # SNS Topic
  SNSTopic:
    Type: AWS::SNS::Topic
    Properties:
      Subscription:
        - Endpoint: !Ref EmailAddress
          Protocol: email

Outputs:

  ProcessedDataBucketName:
    Description: Name of the S3 bucket containing processed data
    Value: !Ref ProcessedDataBucket

  DynamoDBTableName:
    Description: Name of the DynamoDB table storing processed data
    Value: !Ref DynamoDBTable
```

After analyzing the above template we can make the following observations. First, the application does not generate Python code for PreprocessingLambda (Lambda A) and ProcessingLambda (Lambda B). Second, the application creates NotificationLambda, which is not present in the provided architecture diagram, to send SNS notifications. Finally, AWS Lambda functions are using Python 3.9, but we want to use Python 3.12. We can make all these changes using the following update instructions:

```
Add Python code to PreprocessingLambda, ProcessingLambda and NotificationLambda. Change Python 3.9 to 3.12
```
Following you can see the updated AWS Lambda code:

> [!IMPORTANT]  
> The AWS CloudFormation template generated by the web application serves as a reference or starting point for development purposes. It should not be directly utilized in production environments without proper testing and validation. Developers are responsible for thoroughly evaluating and modifying the CloudFormation template to ensure compliance with established security best practices and guidelines before deploying it to production systems.

```
  # Lambda Function A (Preprocessing)
  PreprocessingLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: PreprocessingFunction
      Runtime: python3.12
      Handler: index.lambda_handler
      Role: !GetAtt PreprocessingLambdaRole.Arn
      Environment:
        Variables:
          DATA_BUCKET: !Ref DataBucket
      Code:
        ZipFile: |
          import boto3
          import os

          s3 = boto3.client('s3')

          def lambda_handler(event, context):
              # Retrieve data from S3 bucket
              s3_bucket = os.environ['DATA_BUCKET']
              s3_key = 'data.txt'

              s3_response = s3.get_object(Bucket=s3_bucket, Key=s3_key)
              data = s3_response['Body'].read().decode('utf-8')

              # Preprocess data
              preprocessed_data = preprocess(data)

              # Upload preprocessed data to S3 bucket
              s3.put_object(Bucket=s3_bucket, Key='preprocessed_data.txt', Body=preprocessed_data)

              return {
                  'statusCode': 200,
                  'body': 'Data preprocessing completed successfully'
              }

          def preprocess(data):
              # Preprocessing logic goes here
              return data

  # Lambda Function B (Processing)
  ProcessingLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: ProcessingFunction
      Runtime: python3.12
      Handler: index.lambda_handler
      Role: !GetAtt ProcessingLambdaRole.Arn
      Environment:
        Variables:
          DATA_BUCKET: !Ref DataBucket
      Code:
        ZipFile: |
          import boto3
          import os

          s3 = boto3.client('s3')
          dynamodb = boto3.resource('dynamodb')

          def lambda_handler(event, context):
              # Retrieve preprocessed data from S3 bucket
              s3_bucket = os.environ['DATA_BUCKET']
              s3_key = 'preprocessed_data.txt'

              s3_response = s3.get_object(Bucket=s3_bucket, Key=s3_key)
              preprocessed_data = s3_response['Body'].read().decode('utf-8')

              # Process data
              processed_data = process(preprocessed_data)

              # Store processed data in DynamoDB
              table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
              table.put_item(Item=processed_data)

              return {
                  'statusCode': 200,
                  'body': 'Data processing completed successfully'
              }

          def process(preprocessed_data):
              # Processing logic goes here
              return {'id': '1', 'data': preprocessed_data}
  
  # Lambda Function (Notification)
  NotificationLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: NotificationFunction
      Runtime: python3.12
      Handler: index.lambda_handler
      Role: !GetAtt NotificationLambdaRole.Arn
      Environment:
        Variables:
          NOTIFICATION_TOPIC: !Ref NotificationTopic
      Code:
        ZipFile: |
          import boto3
          import os

          sns = boto3.client('sns')

          def lambda_handler(event, context):
              topic_arn = os.environ['NOTIFICATION_TOPIC']

              for record in event['Records']:
                  if record['eventName'] == 'INSERT':
                      new_item = record['dynamodb']['NewImage']
                      message = f"New item inserted: {new_item}"
                  elif record['eventName'] == 'MODIFY':
                      new_item = record['dynamodb']['NewImage']
                      old_item = record['dynamodb']['OldImage']
                      message = f"Item modified: {new_item}"

                  sns.publish(TopicArn=topic_arn, Message=message, Subject='Data Change Notification')

              return {
                  'statusCode': 200,
                  'body': 'Notification sent successfully'
              }
```

