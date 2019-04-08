
    AWS_SESSION_START=$NOW
    AWS_SESSION_ACCESS_KEY_ID=$(echo "$SESSION" | jq -r .Credentials.AccessKeyId)
    AWS_SESSION_SECRET_ACCESS_KEY=$(echo "$SESSION" | jq -r .Credentials.SecretAccessKey)
    AWS_SESSION_SESSION_TOKEN=$(echo "$SESSION" | jq -r .Credentials.SessionToken)
    AWS_SESSION_SECURITY_TOKEN=$AWS_SESSION_SESSION_TOKEN

    AWS_ACCOUNT_ROLE=User

~ echo "MFA CODE:"; read MFA;
export SESSION_DATA=$(aws sts assume-role --role-arn arn:aws:iam::410444354559:role/User --role-session-name 'mysession'  --serial-number arn:aws:iam::071231839057:mfa/noah.gibbs@appfolio.com --duration-seconds 28800 --token-code $MFA)
AWS_SESSION_START=$NOW
AWS_SESSION_ACCESS_KEY_ID=$(echo "$SESSION_DATA" | jq -r .Credentials.AccessKeyId)
AWS_SESSION_SECRET_ACCESS_KEY=$(echo "$SESSION_DATA" | jq -r .Credentials.SecretAccessKey)
AWS_SESSION_SESSION_TOKEN=$(echo "$SESSION_DATA" | jq -r .Credentials.SessionToken)
AWS_SESSION_SECURITY_TOKEN=$AWS_SESSION_SESSION_TOKEN
AWS_ACCOUNT_ROLE=User

export AWS_SESSION_START=$AWS_SESSION_START
export AWS_ACCESS_KEY_ID=$AWS_SESSION_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SESSION_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN=$AWS_SESSION_SESSION_TOKEN
export AWS_SECURITY_TOKEN=$AWS_SESSION_SECURITY_TOKEN
export AWS_ACCOUNT_ROLE=User

{
  "Credentials": {
    "AccessKeyId": "ASIARJJP47A7FVZBM7XH",
    "SecretAccessKey": "XZDxMgLwfQWlGvaCjegawO0NN1lMWpgr8zg6zoRb",
    "SessionToken": "FQoGZXIvYXdzEA4aDL7lfpljx7u3ji3QNiLtAUjGHIdfOojjCxn7IIV1RSF5P+ZXRz6rMKVisW5dt67jjwqD+S20n1alvkskzPQVZ+uZyQmHG8YZWGYFMD1FJl4CktK5HmtSCnUrmsFf2txxQR1YjPdNB3Iv2Timwl8Uc6egGg16yfFkX9XxCAxzd4Nms5Htt/iZrVwdgaYVcrUf+TKqo7VXlWXkkp0HHxj8sPqSkSNmOCJrqCoIxP1hm3as8mhkaefcBHCjpYRMPEg4Yp1i9a7iyLZnu9FvMTjmgLZwQ/YDmhYTt+vQKdSRMZN8PNJO7Mq7EZr5WprHZbs+HqQ88LKu7FDlSLVsmyiPtqDkBQ==",
    "Expiration": "2019-03-12T21:48:15Z"
  },
  "AssumedRoleUser": {
    "AssumedRoleId": "AROAJWHM5J6EHYLFESO5S:mysession",
    "Arn": "arn:aws:sts::088684165182:assumed-role/User/mysession"
  }
}
