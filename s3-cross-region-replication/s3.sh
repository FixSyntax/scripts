#!/bin/bash

bucket_name=${1}
bucket_destination=${bucket_name}-cross-region-replication
role_destination=s3-replication-role-${bucket_name}
role_name=s3-replication-role-${bucket_name}
region_destination=eu-central-1

#versioning
aws s3api put-bucket-versioning \
    --bucket ${bucket_name} \
    --versioning-configuration Status=Enabled

#bucket de destino
aws s3api create-bucket \
    --bucket ${bucket_destination} \
    --region ${region_destination} \
    --create-bucket-configuration LocationConstraint=${region_destination}

#block public access
aws s3api put-public-access-block \
    --bucket my-bucket \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

#target versioning 
aws s3api put-bucket-versioning \
    --bucket ${bucket_destination} \
    --versioning-configuration Status=Enabled

#role create
aws iam create-role \
    --role-name ${role_destination} \
    --assume-role-policy-document file://s3-role.json 

contents="$(jq '.Statement[0,1].Resource[] = "arn:aws:s3:::'${bucket_name}/*'" | .Statement[2].Resource = "arn:aws:s3:::'${bucket_destination}/*'" ' s3-replication-policy.json)" && echo "${contents}" > s3-replication-policy.json

#create police
policy_arn="$(aws iam create-policy \
    --policy-name s3-replication-role-${bucket_name} \
    --policy-document file://s3-replication-policy.json | jq .Policy.Arn | sed -e 's/\"//g')"

#attach policy
aws iam attach-role-policy \
    --policy-arn ${policy_arn} \
    --role-name s3-replication-role-${bucket_name}

role="$(aws iam get-role --role-name ${role_name} --query 'Role.Arn')"
contents="$(jq '.Role = '${role}' | .Rules[].Destination.Bucket = "arn:aws:s3:::'${bucket_destination}'" '  replication.json)" && echo "${contents}" > replication.json

#origin replication
aws s3api put-bucket-replication \
    --replication-configuration file://replication.json \
    --bucket ${bucket_name}

#get bucket
aws s3api get-bucket-replication \
    --bucket ${bucket_name}




