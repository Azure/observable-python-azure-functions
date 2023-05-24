import os
import json
import datetime
import logging

import azure.functions as func
from opencensus.extension.azure.functions import OpenCensusExtension
from opencensus.trace import config_integration
from azure.cosmos import CosmosClient

OpenCensusExtension.configure()
config_integration.trace_integrations(['requests'])
config_integration.trace_integrations(['logging'])


def main(timer: func.TimerRequest, outputEventHubMessage: func.Out[str], context: func.Context) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if timer.past_due:
        logging.info('The timer is past due!')


    cosmos_connection_string = os.environ.get("ConnectionStrings:COSMOSDB_CONNECTION_STRING", None)
    if not cosmos_connection_string:
        raise ValueError("COSMOSDB_CONNECTION_STRING env variable not set")
    
    logging.info(f"Query Data Azure Function triggerred. Current tracecontext is: {context.trace_context.Traceparent}")
    with context.tracer.span("queryExternalCatalog"):
        logging.info('querying the external catalog')

        try:
            client = CosmosClient.from_connection_string(cosmos_connection_string)
            database = client.get_database_client("ContosoDatabase")
            container = database.get_container_client("onPremisesData")
            docs_list = list(container.read_all_items(max_item_count=10))
        except Exception as e:
            logging.exception(e)
            raise e


    with context.tracer.span("sendMessage"):
        logging.info('Building the events')

    try:
        with context.tracer.span("splitToMessages"):
            # extract the "data" field form each document
            logging.info('Splitting to events')
            for d in docs_list:
                for item in d['data']:
                        item.update({
                            "sample_part": d['sample_part']
                        })

            serialized_data_list = [json.dumps(d['data']) for d in docs_list]


        with context.tracer.span("setMessages"): 
            logging.info('Sending messages to Event Hub')
            for d in serialized_data_list:
                outputEventHubMessage.set(d)
    except Exception as e:
        logging.exception(e)
        raise e

    logging.info('Python timer trigger function ran at %s', utc_timestamp)