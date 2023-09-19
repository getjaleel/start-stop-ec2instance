import boto3

START_RULE_NAME = 'start-every-day'
STOP_RULE_NAME = 'stop-every-day'


def lambda_handler(event, context):
    rule_name = event['ruleName']
    ec2 = boto3.resource('ec2')

    if rule_name == START_RULE_NAME:
        try:
            stopped_instances = ec2.instances.filter(Filters=[{'Name': 'instance-state-name', 'Values': ['stopped']}])
            for instance in stopped_instances:
                check_instance_start(instance)
        except Exception as e:
            print(e.args[-1])

    elif rule_name == STOP_RULE_NAME:
        try:
            running_instances = ec2.instances.filter(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
            for instance in running_instances:
                check_instance_stop(instance)
        except Exception as e:
            print(e.args[-1])

    else:
        print("Unknown rule name.")

def check_instance_start(instance):
    if instance.tags: 
        for tag in instance.tags:
            if tag['Key'].lower() == "shutdown" and tag['Value'].lower() == "true":
                print("Instance with ID \"{0}\" will be started.".format(instance.instance_id))
                instance.start()


def check_instance_stop(instance):
    if instance.tags: 
        for tag in instance.tags:
            if tag['Key'].lower() == "shutdown" and tag['Value'].lower() == "true":
                print("Instance with ID \"{0}\" will be stopped.".format(instance.instance_id))
                instance.stop()

