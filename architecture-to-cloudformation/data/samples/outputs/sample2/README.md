# Output [Sample2.jpg](/architecture-to-cloudformation/util/samples/sample2.jpg)

Let’s try an AWS Step Functions architecture diagram. 

![sample2.jpg](/architecture-to-cloudformation/data/samples/sample2.jpg)

The application generates the following step-by-step explanation and AWS CloudFormation template. 

![artifact-1.png](/architecture-to-cloudformation/data/samples/outputs/sample2/artifact-1.png)

> [!IMPORTANT]  
> The AWS CloudFormation template generated by the web application serves as a reference or starting point for development purposes. It should not be directly utilized in production environments without proper testing and validation. Developers are responsible for thoroughly evaluating and modifying the CloudFormation template to ensure compliance with established security best practices and guidelines before deploying it to production systems.

```
AWSTemplateFormatVersion: '2010-09-09'
Description: >
  This CloudFormation stack sets up a serverless data processing pipeline using AWS Step Functions and AWS Lambda.
  It executes a parallel state machine that invokes Lambda functions to summarize data and generate action items.
  The processed data is stored in a DynamoDB table.
  This template is not production ready and should only be used for inspiration.
Resources:

  # DynamoDB Table
  DynamoDBTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: DataProcessingTable
      AttributeDefinitions:
        - AttributeName: timestamp
          AttributeType: S
      KeySchema:
        - AttributeName: timestamp
          KeyType: HASH
      ProvisionedThroughput:
        ReadCapacityUnits: 5
        WriteCapacityUnits: 5

  # Lambda Function: SummarizeData
  SummarizeDataFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: SummarizeData
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt LambdaRole.Arn
      Code:
        ZipFile: |
          # Lambda function code to summarize data
          ...

  # Lambda Function: ActionItemData
  ActionItemDataFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: ActionItemData
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt LambdaRole.Arn
      Code:
        ZipFile: |
          # Lambda function code to generate action items
          ...

  # Lambda Function: CheckpointData
  CheckpointDataFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: CheckpointData
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt LambdaRole.Arn
      Code:
        ZipFile: |
          # Lambda function code to process and store data
          import boto3

          dynamodb = boto3.resource('dynamodb')
          table = dynamodb.Table('DataProcessingTable')

          def lambda_handler(event, context):
              # Process data from previous Lambda functions
              processed_data = {
                  'timestamp': '3',
                  # ... other data processing logic
              }

              # Store processed data in DynamoDB
              table.put_item(Item=processed_data)

  # Lambda Role
  LambdaRole:
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
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'dynamodb:PutItem'
                Resource: !GetAtt DynamoDBTable.Arn

  # Step Functions State Machine
  DataProcessingStateMachine:
    Type: AWS::StepFunctions::StateMachine
    Properties:
      StateMachineName: DataProcessingStateMachine
      DefinitionString:
        !Sub
          - |-
            {
              "StartAt": "Parallel",
              "States": {
                "Parallel": {
                  "Type": "Parallel",
                  "Branches": [
                    {
                      "StartAt": "SummarizeData",
                      "States": {
                        "SummarizeData": {
                          "Type": "Task",
                          "Resource": "${SummarizeDataFunctionArn}",
                          "End": true
                        }
                      }
                    },
                    {
                      "StartAt": "ActionItemData",
                      "States": {
                        "ActionItemData": {
                          "Type": "Task",
                          "Resource": "${ActionItemDataFunctionArn}",
                          "End": true
                        }
                      }
                    }
                  ],
                  "Next": "CheckpointData"
                },
                "CheckpointData": {
                  "Type": "Task",
                  "Resource": "${CheckpointDataFunctionArn}",
                  "End": true
                }
              }
            }
          - {
              SummarizeDataFunctionArn: !GetAtt SummarizeDataFunction.Arn,
              ActionItemDataFunctionArn: !GetAtt ActionItemDataFunction.Arn,
              CheckpointDataFunctionArn: !GetAtt CheckpointDataFunction.Arn
            }
      RoleArn: !GetAtt StateMachineRole.Arn

  # Step Functions Role
  StateMachineRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: states.amazonaws.com
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: InvokeLambdaPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'lambda:InvokeFunction'
                Resource:
                  - !GetAtt SummarizeDataFunction.Arn
                  - !GetAtt ActionItemDataFunction.Arn
                  - !GetAtt CheckpointDataFunction.Arn

Outputs:

  DynamoDBTableName:
    Description: Name of the DynamoDB table
    Value: !Ref DynamoDBTable

  StateMachineArn:
    Description: ARN of the Step Functions State Machine
    Value: !Ref DataProcessingStateMachine
```

We leave it to the reader to try the following update instructions. 

```
1. Change Lambda Python version to 3.12
2. Write separate Lambda roles for SummarizeDataFunction, ActionItemDataFunction, and CheckpointDataFunction
3. Create a Amazon S3 Bucket, ask for bucket name as parameter. Give access to SummarizeDataFunction and ActionItemDataFunction to write to the bucket  
4. Write boilerplate code for SummarizeDataFunction, ActionItemDataFunction, and CheckpointDataFunction
5. Change timestamp value in CheckpointDataFunction to refer to current timestamp
```

Following you can see the updated AWS CloudFormation template:

> [!IMPORTANT]  
> The AWS CloudFormation template generated by the web application serves as a reference or starting point for development purposes. It should not be directly utilized in production environments without proper testing and validation. Developers are responsible for thoroughly evaluating and modifying the CloudFormation template to ensure compliance with established security best practices and guidelines before deploying it to production systems.

```
AWSTemplateFormatVersion: '2010-09-09'
Description: >
  This CloudFormation stack sets up a serverless data processing pipeline using AWS Step Functions and AWS Lambda.
  It executes a parallel state machine that invokes Lambda functions to summarize data and generate action items.
  The processed data is stored in an S3 bucket and a DynamoDB table.
  This template is not production ready and should only be used for inspiration.
Parameters:

  BucketName:
    Type: String
    Description: Name of the S3 bucket for storing processed data

Resources:

  # DynamoDB Table
  DynamoDBTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: DataProcessingTable
      AttributeDefinitions:
        - AttributeName: timestamp
          AttributeType: S
      KeySchema:
        - AttributeName: timestamp
          KeyType: HASH
      ProvisionedThroughput:
        ReadCapacityUnits: 5
        WriteCapacityUnits: 5

  # S3 Bucket
  S3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName

  # Lambda Function: SummarizeData
  SummarizeDataFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: SummarizeData
      Runtime: python3.12
      Handler: index.lambda_handler
      Role: !GetAtt SummarizeDataFunctionRole.Arn
      Environment:
        Variables:
          S3_BUCKET_NAME: !Ref BucketName
      Code:
        ZipFile: |
          import boto3
          import json
          import os

          s3 = boto3.client('s3')
          bucket_name = os.environ['S3_BUCKET_NAME']

          def lambda_handler(event, context):
              # Summarize data logic
              summary = 'This is a sample summary'

              # Write summary to S3
              s3.put_object(
                  Bucket=bucket_name,
                  Key='summary.txt',
                  Body=summary
              )

              return {
                  'statusCode': 200,
                  'body': json.dumps('Data summarization completed successfully')
              }

  # Lambda Function: ActionItemData
  ActionItemDataFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: ActionItemData
      Runtime: python3.12
      Handler: index.lambda_handler
      Role: !GetAtt ActionItemDataFunctionRole.Arn
      Environment:
        Variables:
          S3_BUCKET_NAME: !Ref BucketName
      Code:
        ZipFile: |
          import boto3
          import json
          import os

          s3 = boto3.client('s3')
          bucket_name = os.environ['S3_BUCKET_NAME']

          def lambda_handler(event, context):
              # Generate action items logic
              action_items = 'This is a sample action item'

              # Write action items to S3
              s3.put_object(
                  Bucket=bucket_name,
                  Key='action_items.txt',
                  Body=action_items
              )

              return {
                  'statusCode': 200,
                  'body': json.dumps('Action items generation completed successfully')
              }

  # Lambda Function: CheckpointData
  CheckpointDataFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: CheckpointData
      Runtime: python3.12
      Handler: index.lambda_handler
      Role: !GetAtt CheckpointDataFunctionRole.Arn
      Code:
        ZipFile: |
          import boto3
          import time

          dynamodb = boto3.resource('dynamodb')
          table = dynamodb.Table('DataProcessingTable')

          def lambda_handler(event, context):
              # Process data from previous Lambda functions
              processed_data = {
                  'timestamp': str(int(time.time())),
                  # ... other data processing logic
              }

              # Store processed data in DynamoDB
              table.put_item(Item=processed_data)

              return {
                  'statusCode': 200,
                  'body': 'Data checkpoint completed successfully'
              }

  # Lambda Role: SummarizeData
  SummarizeDataFunctionRole:
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
        - PolicyName: S3WriteAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:PutObject'
                Resource: !Join ['', ['arn:aws:s3:::', !Ref BucketName, '/*']]

  # Lambda Role: ActionItemData
  ActionItemDataFunctionRole:
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
        - PolicyName: S3WriteAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:PutObject'
                Resource: !Join ['', ['arn:aws:s3:::', !Ref BucketName, '/*']]

  # Lambda Role: CheckpointData
  CheckpointDataFunctionRole:
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
        - PolicyName: DynamoDBAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'dynamodb:PutItem'
                Resource: !GetAtt DynamoDBTable.Arn

  # Step Functions State Machine
  DataProcessingStateMachine:
    Type: AWS::StepFunctions::StateMachine
    Properties:
      StateMachineName: DataProcessingStateMachine
      DefinitionString:
        !Sub
          - |-
            {
              "StartAt": "Parallel",
              "States": {
                "Parallel": {
                  "Type": "Parallel",
                  "Branches": [
                    {
                      "StartAt": "SummarizeData",
                      "States": {
                        "SummarizeData": {
                          "Type": "Task",
                          "Resource": "${SummarizeDataFunctionArn}",
                          "End": true
                        }
                      }
                    },
                    {
                      "StartAt": "ActionItemData",
                      "States": {
                        "ActionItemData": {
                          "Type": "Task",
                          "Resource": "${ActionItemDataFunctionArn}",
                          "End": true
                        }
                      }
                    }
                  ],
                  "Next": "CheckpointData"
                },
                "CheckpointData": {
                  "Type": "Task",
                  "Resource": "${CheckpointDataFunctionArn}",
                  "End": true
                }
              }
            }
          - {
              SummarizeDataFunctionArn: !GetAtt SummarizeDataFunction.Arn,
              ActionItemDataFunctionArn: !GetAtt ActionItemDataFunction.Arn,
              CheckpointDataFunctionArn: !GetAtt CheckpointDataFunction.Arn
            }
      RoleArn: !GetAtt StateMachineRole.Arn

  # Step Functions Role
  StateMachineRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: states.amazonaws.com
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: InvokeLambdaPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 'lambda:InvokeFunction'
                Resource:
                  - !GetAtt SummarizeDataFunction.Arn
                  - !GetAtt ActionItemDataFunction.Arn
                  - !GetAtt CheckpointDataFunction.Arn

Outputs:

  DynamoDBTableName:
    Description: Name of the DynamoDB table
    Value: !Ref DynamoDBTable

  S3BucketName:
    Description: Name of the S3 bucket
    Value: !Ref BucketName

  StateMachineArn:
    Description: ARN of the Step Functions State Machine
    Value: !Ref DataProcessingStateMachine
```