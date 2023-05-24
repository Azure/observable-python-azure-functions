import json
import logging

import azure.functions as func
from opencensus.extension.azure.functions import OpenCensusExtension
from opencensus.trace import config_integration
from datetime import datetime

config_integration.trace_integrations(['requests'])
config_integration.trace_integrations(['logging'])

def main(event: func.EventHubEvent, outputServiceBusMessage: func.Out[str], context: func.Context):
    logging.info(f"Python EventHub trigger processed event")
    with context.tracer.span("readEvent"):
        logging.info("in readEvent span")
        content = event.get_body().decode('utf-8')
        dict_content = json.loads(content)
        
    with context.tracer.span("processEvent"):
        logging.info("in processEvent span")
        try:
            logging.info("Processing the received event")
            dict_content.pop('user_id')
            date_to_process = dict_content['date']
            new_date = datetime.strptime(date_to_process, "%Y-%m-%d %H:%M:%S")
            dict_content['date'] = new_date.strftime("%Y-%m-%d")
            content = json.dumps(dict_content)
        except Exception as e:
            logging.exception(e)
            raise e 
        
    with context.tracer.span("sendMessages"):
        logging.info("in sendMessages span")
        logging.info("Publishing message to Service Bus Queue")
        outputServiceBusMessage.set(content)
    
