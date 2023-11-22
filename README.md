# tf_module_app

```bash
aws kms create-grant \
--region us-east-1 \
--key-id arn:aws:kms:us-east-1:492681564023:key/e0d7eb6d-885f-412f-b2b6-3352d09b052a \
--grantee-principal "arn:aws:iam::492681564023:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling" \
--operations "Encrypt" "Decrypt" "ReEncryptFrom" "ReEncryptTo" "GenerateDataKey" "GenerateDataKeyWithoutPlaintext" "DescribeKey" "CreateGrant"
```
