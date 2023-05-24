import os
import json
import logging
import azure.functions as func
from opencensus.trace import config_integration
from azure.data.tables import TableServiceClient


config_integration.trace_integrations(['requests'])
config_integration.trace_integrations(['logging'])

def main(msg: func.ServiceBusMessage, context: func.Context):
    logging.info(f"Python ServiceBus queue trigger processed message {msg.message_id}")

    storage_account_connection_string = os.environ.get("AzureWebJobsStorage", None)
    if not storage_account_connection_string:
        raise ValueError("AzureWebJobsStorage env variable not set")
    
    with context.tracer.span("readMessage"):
        logging.info("in readMessage span")
        try:
            entity_to_upsert = json.loads(msg.get_body().decode('utf-8'))

            entity_unique_identifier = {
                "PartitionKey": entity_to_upsert['business_id'],
                "RowKey": f"sample_part_{entity_to_upsert['sample_part']}"
            }
            entity_to_upsert.pop('sample_part')
            entity_to_upsert.pop('business_id')
            entity_to_upsert.update(entity_unique_identifier)

            table_service_client = TableServiceClient.from_connection_string(conn_str=storage_account_connection_string)
            table_client = table_service_client.get_table_client(table_name="ingesteddata")

            entity = table_client.upsert_entity(entity=entity_to_upsert)
            logging.info(entity)
        except Exception as e:
            logging.exception(e)
            raise e