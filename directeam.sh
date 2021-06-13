# set aws credentials
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=



# create red nginx instance
RED_RUN_RESULT=$(aws ec2 run-instances --image-id ami-0d5eff06f840b45e9 --count 1 --instance-type t2.micro --key-name MyKeyPair --security-group-ids sg-0f5f5e4c73ae9048f --subnet-id subnet-d13805df --user-data file://userdata-red.txt) ; echo $RED_RUN_RESULT
RED_ID=$(echo $RED_RUN_RESULT | grep -o "\w*i-\w*" | grep '^i\-') ; echo $RED_ID


# create blue nginx instance
BLUE_RUN_RESULT=$(aws ec2 run-instances --image-id ami-0d5eff06f840b45e9 --count 1 --instance-type t2.micro --key-name MyKeyPair --security-group-ids sg-0f5f5e4c73ae9048f --subnet-id subnet-d13805df --user-data file://userdata-blue.txt) ; echo $BLUE_RUN_RESULT
BLUE_ID=$(echo $BLUE_RUN_RESULT | grep -o "\w*i-\w*" | grep '^i\-') ; echo $BLUE_ID


# create alb
ALB_RESULT=$(aws elbv2 create-load-balancer --name my-load-balancer  \
--subnets subnet-d13805df subnet-566e2a09 --security-groups sg-0f5f5e4c73ae9048f)

ALB_ARN=$(echo $ALB_RESULT | awk '{print $6}') ; echo $ALB_ARN


# wait for instances to be in a running state
sleep 30


# create listener for the alb woth a default rule of fixed response
LISTENER_RESULT=$(aws elbv2 create-listener --load-balancer-arn $ALB_ARN \
--protocol HTTP --port 80  \
--default-actions file://actions-fixed-response.json)

LISTENER_ARN=$(echo $LISTENER_RESULT | awk '{print $2}') ; echo $LISTENER_ARN


# create red instance target group
RED_TARGET_RESULT=$(aws elbv2 create-target-group --name red-target --protocol HTTP --port 80 \
--vpc-id vpc-29d54254)

RED_TARGET_ARN=$(echo $RED_TARGET_RESULT | awk '{print $12}') ; echo $RED_TARGET_ARN


# wait for instances to be in a running state
sleep 30


# register red instance target group
aws elbv2 register-targets --target-group-arn $RED_TARGET_ARN  \
--targets Id=$RED_ID


# create blue instance target group
BLUE_TARGET_RESULT=$(aws elbv2 create-target-group --name blue-target --protocol HTTP --port 80 \
--vpc-id vpc-29d54254)

BLUE_TARGET_ARN=$(echo $BLUE_TARGET_RESULT | awk '{print $12}') ; echo $BLUE_TARGET_ARN


# register blue instance target group
aws elbv2 register-targets --target-group-arn $BLUE_TARGET_ARN  \
--targets Id=$BLUE_ID



# create listener-rule for path /blue -> blue instance
aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 11 \
--conditions Field=path-pattern,Values='/blue*' \
--actions Type=forward,TargetGroupArn=$BLUE_TARGET_ARN

# create listener-rule for path /red -> red instance
aws elbv2 create-rule --listener-arn $LISTENER_ARN --priority 9 \
--conditions Field=path-pattern,Values='/red*' \
--actions Type=forward,TargetGroupArn=$RED_TARGET_ARN 




