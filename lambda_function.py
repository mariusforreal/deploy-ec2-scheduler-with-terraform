import boto3
import datetime
import re
import logging
from datetime import datetime, timezone
import pytz

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize boto3 EC2 client
ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    """
    Lambda function to manage EC2 instances based on KeepOn tag values.
    Starts instances at their scheduled start time and stops them at their scheduled stop time.
    Tag format: Mo+Tu+We+Th+Fr:08-19 (days of week + start hour - end hour in 24hr format)
    """
    logger.info("Starting EC2 scheduler function")
   
    # Get current time in EST
    est = pytz.timezone('US/Eastern')
    now = datetime.now(timezone.utc).astimezone(est)
    current_day = now.strftime("%a")[:2]  # Get first two letters of day (Mo, Tu, We, Th, Fr, Sa, Su)
    current_hour = now.hour
   
    logger.info(f"Current day: {current_day}, Current hour: {current_hour}")
   
    # Map of full day names to abbreviations
    day_abbreviations = {
        "Mo": "Monday",
        "Tu": "Tuesday",
        "We": "Wednesday",
        "Th": "Thursday",
        "Fr": "Friday",
        "Sa": "Saturday",
        "Su": "Sunday"
    }
   
    # Get all instances with the KeepOn tag
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag-key',
                'Values': ['KeepOn']
            }
        ]
    )
   
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            instance_state = instance['State']['Name']
           
            # Find the KeepOn tag
            keep_on_tag_value = None
            for tag in instance['Tags']:
                if tag['Key'] == 'KeepOn':
                    keep_on_tag_value = tag['Value']
                    break
           
            if not keep_on_tag_value:
                continue
               
            logger.info(f"Processing instance {instance_id} with KeepOn value: {keep_on_tag_value}")
           
            # Parse the tag value (e.g., "Mo+Tu+We+Th+Fr:08-19")
            try:
                # Split into days and hours parts
                days_part, hours_part = keep_on_tag_value.split(':')
               
                # Parse days
                days = days_part.split('+')
               
                # Parse hours
                start_hour, end_hour = map(int, hours_part.split('-'))
               
                logger.info(f"Parsed schedule - Days: {days}, Hours: {start_hour}-{end_hour}")
               
                # Check if current day is in the schedule
                if current_day in days:
                    logger.info(f"Today ({current_day}) is in the schedule for instance {instance_id}")
                   
                    # If current hour is start_hour, start the instance if it's stopped
                    if current_hour == start_hour and instance_state == 'stopped':
                        logger.info(f"Starting instance {instance_id} as per schedule")
                        ec2.start_instances(InstanceIds=[instance_id])
                       
                    # If current hour is end_hour, stop the instance if it's running
                    elif current_hour == end_hour and instance_state == 'running':
                        logger.info(f"Stopping instance {instance_id} as per schedule")
                        ec2.stop_instances(InstanceIds=[instance_id])
                else:
                    logger.info(f"Today ({current_day}) is not in the schedule for instance {instance_id}")
           
            except Exception as e:
                logger.error(f"Error processing tag for instance {instance_id}: {str(e)}")
                continue
   
    logger.info("EC2 scheduler function completed")
    return {
        'statusCode': 200,
        'body': 'EC2 scheduler function executed successfully'
    }